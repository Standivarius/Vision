#include <windows.h>

#include <filesystem>
#include <fstream>
#include <string>

namespace fs = std::filesystem;

static HWND g_single{};
static HWND g_multi{};
static HWND g_button{};
static HWND g_check{};
static std::ofstream g_log;
static LARGE_INTEGER g_freq{};
static LARGE_INTEGER g_start{};
static int g_phase = 0;

static long long qpc_now() {
    LARGE_INTEGER v{};
    QueryPerformanceCounter(&v);
    return v.QuadPart;
}

static void log_event(const char* name) {
    const auto qpc = qpc_now();
    const double ms = 1000.0 * static_cast<double>(qpc - g_start.QuadPart) / static_cast<double>(g_freq.QuadPart);
    g_log << "{\"event\":\"" << name << "\",\"qpc\":" << qpc << ",\"elapsed_ms\":" << ms << "}\n";
    g_log.flush();
}

static void ensure_foreground(HWND hwnd) {
    const HWND fg = GetForegroundWindow();
    const DWORD current_tid = GetCurrentThreadId();
    const DWORD fg_tid = fg ? GetWindowThreadProcessId(fg, nullptr) : 0;
    bool attached = false;
    if (fg_tid && fg_tid != current_tid) {
        attached = AttachThreadInput(current_tid, fg_tid, TRUE) != FALSE;
    }
    ShowWindow(hwnd, SW_RESTORE);
    BringWindowToTop(hwnd);
    SetForegroundWindow(hwnd);
    SetActiveWindow(hwnd);
    if (attached) AttachThreadInput(current_tid, fg_tid, FALSE);
}

static void set_edit_caret(HWND owner, HWND edit, int index) {
    ensure_foreground(owner);
    SetFocus(edit);
    SendMessageW(edit, EM_SETSEL, static_cast<WPARAM>(index), static_cast<LPARAM>(index));
    SendMessageW(edit, EM_SCROLLCARET, 0, 0);
}

static void run_phase(HWND hwnd) {
    ++g_phase;
    switch (g_phase) {
    case 1:
        set_edit_caret(hwnd, g_single, 0);
        log_event("single_start");
        break;
    case 2:
        set_edit_caret(hwnd, g_single, 8);
        log_event("single_middle");
        break;
    case 3:
        set_edit_caret(hwnd, g_single, 21);
        log_event("single_end");
        break;
    case 4:
        ensure_foreground(hwnd);
        SetFocus(g_button);
        log_event("button_focus");
        break;
    case 5:
        set_edit_caret(hwnd, g_multi, 0);
        log_event("multi_start");
        break;
    case 6:
        set_edit_caret(hwnd, g_multi, 18);
        log_event("multi_line1_end");
        break;
    case 7:
        set_edit_caret(hwnd, g_multi, 36);
        log_event("multi_line2");
        break;
    case 8:
        set_edit_caret(hwnd, g_multi, 63);
        log_event("multi_line3");
        break;
    case 9:
        ensure_foreground(hwnd);
        SetFocus(g_check);
        log_event("checkbox_focus");
        break;
    case 10:
        set_edit_caret(hwnd, g_single, 4);
        log_event("single_return");
        break;
    default:
        log_event("complete");
        KillTimer(hwnd, 1);
        PostMessageW(hwnd, WM_CLOSE, 0, 0);
        break;
    }
}

static LRESULT CALLBACK wndproc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    switch (msg) {
    case WM_CREATE: {
        HFONT font = reinterpret_cast<HFONT>(GetStockObject(DEFAULT_GUI_FONT));
        g_single = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"Visual caret baseline text",
            WS_CHILD | WS_VISIBLE | WS_TABSTOP | ES_AUTOHSCROLL,
            24, 28, 560, 32, hwnd, reinterpret_cast<HMENU>(101), GetModuleHandleW(nullptr), nullptr);
        g_multi = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT",
            L"First line of text\r\nSecond line of text\r\nThird line for caret movement",
            WS_CHILD | WS_VISIBLE | WS_TABSTOP | ES_MULTILINE | ES_AUTOVSCROLL | WS_VSCROLL,
            24, 84, 560, 160, hwnd, reinterpret_cast<HMENU>(102), GetModuleHandleW(nullptr), nullptr);
        g_button = CreateWindowW(L"BUTTON", L"Focusable button",
            WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
            24, 266, 170, 34, hwnd, reinterpret_cast<HMENU>(103), GetModuleHandleW(nullptr), nullptr);
        g_check = CreateWindowW(L"BUTTON", L"Focusable checkbox",
            WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_AUTOCHECKBOX,
            220, 270, 190, 28, hwnd, reinterpret_cast<HMENU>(104), GetModuleHandleW(nullptr), nullptr);
        for (HWND child : {g_single, g_multi, g_button, g_check}) SendMessageW(child, WM_SETFONT, reinterpret_cast<WPARAM>(font), TRUE);
        SetTimer(hwnd, 1, 900, nullptr);
        return 0;
    }
    case WM_TIMER:
        if (wp == 1) run_phase(hwnd);
        return 0;
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    default:
        return DefWindowProcW(hwnd, msg, wp, lp);
    }
}

int WINAPI wWinMain(HINSTANCE hinst, HINSTANCE, PWSTR cmdline, int) {
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    QueryPerformanceFrequency(&g_freq);
    QueryPerformanceCounter(&g_start);

    fs::path log_path = L"scenario_events.jsonl";
    if (cmdline && *cmdline) log_path = cmdline;
    g_log.open(log_path, std::ios::binary);

    WNDCLASSW wc{};
    wc.lpfnWndProc = wndproc;
    wc.hInstance = hinst;
    wc.lpszClassName = L"VisualSpike3Stimulus";
    wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    wc.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
    if (!RegisterClassW(&wc)) return 2;

    HWND hwnd = CreateWindowExW(0, wc.lpszClassName, L"Visual Spike 3 Focus/Caret Stimulus",
        WS_OVERLAPPEDWINDOW | WS_VISIBLE,
        CW_USEDEFAULT, CW_USEDEFAULT, 640, 370,
        nullptr, nullptr, hinst, nullptr);
    if (!hwnd) return 3;

    ShowWindow(hwnd, SW_SHOW);
    UpdateWindow(hwnd);
    ensure_foreground(hwnd);

    MSG msg{};
    while (GetMessageW(&msg, nullptr, 0, 0) > 0) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }
    return 0;
}
