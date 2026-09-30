#include <windows.h>
#include <ole2.h>
#include <UIAutomation.h>

#include <algorithm>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

namespace fs = std::filesystem;

template <typename T>
static void release_if(T*& p) {
    if (p) {
        p->Release();
        p = nullptr;
    }
}

static std::string utf8(const std::wstring& s) {
    if (s.empty()) return {};
    const int n = WideCharToMultiByte(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), nullptr, 0, nullptr, nullptr);
    std::string out(static_cast<size_t>(n), '\0');
    WideCharToMultiByte(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), out.data(), n, nullptr, nullptr);
    return out;
}

static std::string utf8_bstr(BSTR s) {
    if (!s) return {};
    return utf8(std::wstring(s, SysStringLen(s)));
}

static std::string json_escape(const std::string& s) {
    std::ostringstream os;
    for (unsigned char c : s) {
        switch (c) {
        case '\\': os << "\\\\"; break;
        case '"': os << "\\\""; break;
        case '\n': os << "\\n"; break;
        case '\r': os << "\\r"; break;
        case '\t': os << "\\t"; break;
        default:
            if (c < 0x20) {
                os << "\\u" << std::hex << std::setw(4) << std::setfill('0') << static_cast<int>(c) << std::dec;
            } else {
                os << static_cast<char>(c);
            }
        }
    }
    return os.str();
}

static std::string hwnd_hex(HWND hwnd) {
    std::ostringstream os;
    os << "0x" << std::hex << reinterpret_cast<uintptr_t>(hwnd);
    return os.str();
}

struct Args {
    fs::path out_dir{L"run"};
    int duration_ms{12000};
    int sample_ms{25};
};

static Args parse_args(int argc, wchar_t** argv) {
    Args a;
    for (int i = 1; i < argc; ++i) {
        const std::wstring v = argv[i];
        if (v == L"--out" && i + 1 < argc) a.out_dir = argv[++i];
        else if (v == L"--duration-ms" && i + 1 < argc) a.duration_ms = std::max(500, _wtoi(argv[++i]));
        else if (v == L"--sample-ms" && i + 1 < argc) a.sample_ms = std::clamp(_wtoi(argv[++i]), 5, 1000);
        else if (v == L"--help" || v == L"-h") {
            std::wcout << L"visual_spike3_probe [--out DIR] [--duration-ms N] [--sample-ms N]\n";
            std::exit(0);
        }
    }
    return a;
}

struct RectD {
    double left{};
    double top{};
    double width{};
    double height{};
};

static std::vector<RectD> read_uia_rectangles(SAFEARRAY* sa) {
    std::vector<RectD> out;
    if (!sa || SafeArrayGetDim(sa) != 1) return out;
    LONG lb = 0, ub = -1;
    if (FAILED(SafeArrayGetLBound(sa, 1, &lb)) || FAILED(SafeArrayGetUBound(sa, 1, &ub))) return out;
    const LONG count = ub >= lb ? (ub - lb + 1) : 0;
    if (count <= 0 || (count % 4) != 0) return out;
    double* data = nullptr;
    if (FAILED(SafeArrayAccessData(sa, reinterpret_cast<void**>(&data))) || !data) return out;
    for (LONG i = 0; i < count; i += 4) out.push_back(RectD{data[i], data[i + 1], data[i + 2], data[i + 3]});
    SafeArrayUnaccessData(sa);
    return out;
}

static std::vector<RectD> get_range_rectangles(IUIAutomationTextRange* range) {
    if (!range) return {};
    SAFEARRAY* sa = nullptr;
    if (FAILED(range->GetBoundingRectangles(&sa))) return {};
    const auto rects = read_uia_rectangles(sa);
    if (sa) SafeArrayDestroy(sa);
    return rects;
}

static std::vector<RectD> get_character_context_rectangles(IUIAutomationTextRange* range) {
    if (!range) return {};
    IUIAutomationTextRange* expanded = nullptr;
    if (FAILED(range->Clone(&expanded)) || !expanded) return {};
    std::vector<RectD> rects;
    if (SUCCEEDED(expanded->ExpandToEnclosingUnit(TextUnit_Character))) rects = get_range_rectangles(expanded);
    expanded->Release();
    return rects;
}

static bool range_is_degenerate(IUIAutomationTextRange* range, bool& known) {
    known = false;
    if (!range) return false;
    int delta = 0;
    const HRESULT hr = range->CompareEndpoints(TextPatternRangeEndpoint_Start, range, TextPatternRangeEndpoint_End, &delta);
    if (FAILED(hr)) return false;
    known = true;
    return delta == 0;
}

static IUIAutomationTextRange* first_range(IUIAutomationTextRangeArray* ranges, int& count) {
    count = 0;
    if (!ranges) return nullptr;
    if (FAILED(ranges->get_Length(&count)) || count <= 0) return nullptr;
    IUIAutomationTextRange* range = nullptr;
    if (FAILED(ranges->GetElement(0, &range))) return nullptr;
    return range;
}

static std::wstring window_text(HWND hwnd) {
    if (!hwnd) return {};
    const int n = GetWindowTextLengthW(hwnd);
    std::wstring s(static_cast<size_t>(n + 1), L'\0');
    const int copied = GetWindowTextW(hwnd, s.data(), n + 1);
    s.resize(static_cast<size_t>(std::max(0, copied)));
    return s;
}

static std::wstring window_class(HWND hwnd) {
    if (!hwnd) return {};
    wchar_t buf[256]{};
    const int n = GetClassNameW(hwnd, buf, static_cast<int>(std::size(buf)));
    return n > 0 ? std::wstring(buf, static_cast<size_t>(n)) : std::wstring{};
}

static std::wstring process_image(DWORD pid) {
    HANDLE h = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (!h) return {};
    wchar_t buf[32768]{};
    DWORD n = static_cast<DWORD>(std::size(buf));
    std::wstring result;
    if (QueryFullProcessImageNameW(h, 0, buf, &n)) result.assign(buf, n);
    CloseHandle(h);
    return result;
}

static void write_rect_json(std::ostream& f, const RECT& r) {
    f << "{\"left\":" << r.left << ",\"top\":" << r.top << ",\"right\":" << r.right << ",\"bottom\":" << r.bottom << "}";
}

static void write_rectd_json(std::ostream& f, const RectD& r) {
    f << std::fixed << std::setprecision(3)
      << "{\"left\":" << r.left << ",\"top\":" << r.top
      << ",\"width\":" << r.width << ",\"height\":" << r.height << "}";
}

int wmain(int argc, wchar_t** argv) {
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    const Args args = parse_args(argc, argv);
    fs::create_directories(args.out_dir);

    const HRESULT co_hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    if (FAILED(co_hr) && co_hr != RPC_E_CHANGED_MODE) {
        std::cerr << "CoInitializeEx failed: 0x" << std::hex << static_cast<unsigned long>(co_hr) << "\n";
        return 2;
    }

    IUIAutomation* uia = nullptr;
    const HRESULT uia_hr = CoCreateInstance(CLSID_CUIAutomation, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&uia));
    if (FAILED(uia_hr) || !uia) {
        std::cerr << "CUIAutomation creation failed: 0x" << std::hex << static_cast<unsigned long>(uia_hr) << "\n";
        if (SUCCEEDED(co_hr)) CoUninitialize();
        return 3;
    }

    LARGE_INTEGER freq{}, start{};
    QueryPerformanceFrequency(&freq);
    QueryPerformanceCounter(&start);

    std::ofstream log(args.out_dir / "focus_caret_telemetry.jsonl", std::ios::binary);
    if (!log) {
        release_if(uia);
        if (SUCCEEDED(co_hr)) CoUninitialize();
        return 4;
    }

    const auto deadline = std::chrono::steady_clock::now() + std::chrono::milliseconds(args.duration_ms);
    uint64_t sample = 0;

    while (std::chrono::steady_clock::now() < deadline) {
        LARGE_INTEGER now{};
        QueryPerformanceCounter(&now);
        const double elapsed_ms = 1000.0 * static_cast<double>(now.QuadPart - start.QuadPart) / static_cast<double>(freq.QuadPart);

        HWND fg = GetForegroundWindow();
        DWORD fg_pid = 0;
        const DWORD fg_tid = fg ? GetWindowThreadProcessId(fg, &fg_pid) : 0;

        GUITHREADINFO gti{};
        gti.cbSize = sizeof(gti);
        const BOOL gti_ok = fg_tid ? GetGUIThreadInfo(fg_tid, &gti) : FALSE;

        bool win_caret_screen_valid = false;
        RECT win_caret_screen{};
        if (gti_ok && gti.hwndCaret) {
            POINT a{gti.rcCaret.left, gti.rcCaret.top};
            POINT b{gti.rcCaret.right, gti.rcCaret.bottom};
            if (ClientToScreen(gti.hwndCaret, &a) && ClientToScreen(gti.hwndCaret, &b)) {
                win_caret_screen = RECT{a.x, a.y, b.x, b.y};
                win_caret_screen_valid = true;
            }
        }

        IUIAutomationElement* focused = nullptr;
        const HRESULT focus_hr = uia->GetFocusedElement(&focused);
        int uia_pid = 0;
        CONTROLTYPEID control_type = 0;
        RECT uia_focus_rect{};
        bool uia_focus_rect_valid = false;
        BSTR name = nullptr;
        BSTR framework = nullptr;
        HRESULT rect_hr = E_FAIL;

        HRESULT text2_hr = E_FAIL;
        bool text2_present = false;
        HRESULT caret_hr = E_FAIL;
        BOOL caret_active = FALSE;
        bool caret_range_present = false;
        bool caret_degenerate_known = false;
        bool caret_degenerate = false;
        std::vector<RectD> caret_rects;
        std::vector<RectD> caret_char_rects;

        HRESULT text_hr = E_FAIL;
        bool text_present = false;
        HRESULT selection_hr = E_FAIL;
        int selection_count = 0;
        bool selection_range_present = false;
        bool selection_degenerate_known = false;
        bool selection_degenerate = false;
        std::vector<RectD> selection_rects;
        std::vector<RectD> selection_char_rects;

        if (SUCCEEDED(focus_hr) && focused) {
            focused->get_CurrentProcessId(&uia_pid);
            focused->get_CurrentControlType(&control_type);
            focused->get_CurrentName(&name);
            focused->get_CurrentFrameworkId(&framework);
            rect_hr = focused->get_CurrentBoundingRectangle(&uia_focus_rect);
            uia_focus_rect_valid = SUCCEEDED(rect_hr);

            IUIAutomationTextPattern2* text2 = nullptr;
            text2_hr = focused->GetCurrentPatternAs(UIA_TextPattern2Id, __uuidof(IUIAutomationTextPattern2), reinterpret_cast<void**>(&text2));
            text2_present = text2 != nullptr;
            if (text2) {
                IUIAutomationTextRange* caret_range = nullptr;
                caret_hr = text2->GetCaretRange(&caret_active, &caret_range);
                caret_range_present = caret_range != nullptr;
                if (caret_range) {
                    caret_rects = get_range_rectangles(caret_range);
                    caret_char_rects = get_character_context_rectangles(caret_range);
                    caret_degenerate = range_is_degenerate(caret_range, caret_degenerate_known);
                    caret_range->Release();
                }
                text2->Release();
            }

            IUIAutomationTextPattern* text = nullptr;
            text_hr = focused->GetCurrentPatternAs(UIA_TextPatternId, __uuidof(IUIAutomationTextPattern), reinterpret_cast<void**>(&text));
            text_present = text != nullptr;
            if (text) {
                IUIAutomationTextRangeArray* selections = nullptr;
                selection_hr = text->GetSelection(&selections);
                if (selections) {
                    IUIAutomationTextRange* selection = first_range(selections, selection_count);
                    selection_range_present = selection != nullptr;
                    if (selection) {
                        selection_rects = get_range_rectangles(selection);
                        selection_char_rects = get_character_context_rectangles(selection);
                        selection_degenerate = range_is_degenerate(selection, selection_degenerate_known);
                        selection->Release();
                    }
                    selections->Release();
                }
                text->Release();
            }
        }

        log << "{\"sample\":" << sample++
            << ",\"qpc\":" << now.QuadPart
            << ",\"elapsed_ms\":" << std::fixed << std::setprecision(3) << elapsed_ms
            << ",\"foreground\":{\"hwnd\":\"" << hwnd_hex(fg) << "\",\"pid\":" << fg_pid << ",\"tid\":" << fg_tid
            << ",\"class\":\"" << json_escape(utf8(window_class(fg))) << "\",\"title\":\"" << json_escape(utf8(window_text(fg)))
            << "\",\"image\":\"" << json_escape(utf8(process_image(fg_pid))) << "\"}"
            << ",\"win32\":{\"gui_ok\":" << (gti_ok ? "true" : "false")
            << ",\"focus_hwnd\":\"" << hwnd_hex(gti_ok ? gti.hwndFocus : nullptr) << "\""
            << ",\"caret_hwnd\":\"" << hwnd_hex(gti_ok ? gti.hwndCaret : nullptr) << "\""
            << ",\"caret_visible\":" << ((gti_ok && (gti.flags & GUI_CARETBLINKING)) ? "true" : "false")
            << ",\"caret_client_rect\":";
        if (gti_ok && gti.hwndCaret) write_rect_json(log, gti.rcCaret); else log << "null";
        log << ",\"caret_screen_rect\":";
        if (win_caret_screen_valid) write_rect_json(log, win_caret_screen); else log << "null";
        log << "}"
            << ",\"uia\":{\"focus_hr\":" << static_cast<long>(focus_hr)
            << ",\"focused\":" << (focused ? "true" : "false")
            << ",\"pid\":" << uia_pid
            << ",\"control_type\":" << control_type
            << ",\"name\":\"" << json_escape(utf8_bstr(name)) << "\""
            << ",\"framework\":\"" << json_escape(utf8_bstr(framework)) << "\""
            << ",\"focus_rect_hr\":" << static_cast<long>(rect_hr)
            << ",\"focus_rect\":";
        if (uia_focus_rect_valid) write_rect_json(log, uia_focus_rect); else log << "null";
        log << ",\"text2_hr\":" << static_cast<long>(text2_hr)
            << ",\"text2_present\":" << (text2_present ? "true" : "false")
            << ",\"caret_hr\":" << static_cast<long>(caret_hr)
            << ",\"caret_active\":" << (caret_active ? "true" : "false")
            << ",\"caret_range_present\":" << (caret_range_present ? "true" : "false")
            << ",\"caret_degenerate_known\":" << (caret_degenerate_known ? "true" : "false")
            << ",\"caret_degenerate\":" << (caret_degenerate ? "true" : "false")
            << ",\"caret_rect_count\":" << caret_rects.size()
            << ",\"caret_rect_first\":";
        if (!caret_rects.empty()) write_rectd_json(log, caret_rects.front()); else log << "null";
        log << ",\"caret_char_context_rect_count\":" << caret_char_rects.size()
            << ",\"caret_char_context_rect_first\":";
        if (!caret_char_rects.empty()) write_rectd_json(log, caret_char_rects.front()); else log << "null";
        log << ",\"text_hr\":" << static_cast<long>(text_hr)
            << ",\"text_present\":" << (text_present ? "true" : "false")
            << ",\"selection_hr\":" << static_cast<long>(selection_hr)
            << ",\"selection_count\":" << selection_count
            << ",\"selection_range_present\":" << (selection_range_present ? "true" : "false")
            << ",\"selection_degenerate_known\":" << (selection_degenerate_known ? "true" : "false")
            << ",\"selection_degenerate\":" << (selection_degenerate ? "true" : "false")
            << ",\"selection_rect_count\":" << selection_rects.size()
            << ",\"selection_rect_first\":";
        if (!selection_rects.empty()) write_rectd_json(log, selection_rects.front()); else log << "null";
        log << ",\"selection_char_context_rect_count\":" << selection_char_rects.size()
            << ",\"selection_char_context_rect_first\":";
        if (!selection_char_rects.empty()) write_rectd_json(log, selection_char_rects.front()); else log << "null";
        log << "}}\n";
        log.flush();

        if (name) SysFreeString(name);
        if (framework) SysFreeString(framework);
        release_if(focused);
        std::this_thread::sleep_for(std::chrono::milliseconds(args.sample_ms));
    }

    std::ofstream done(args.out_dir / "probe_completed.txt", std::ios::binary);
    done << "completed\n";
    release_if(uia);
    if (SUCCEEDED(co_hr)) CoUninitialize();
    return 0;
}
