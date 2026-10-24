#include <windows.h>
#include <shellscalingapi.h>

#include "coordinate_model.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <optional>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

namespace fs = std::filesystem;

struct DisplayConfigInfo {
    std::wstring gdi_name;
    std::wstring friendly_name;
    std::wstring monitor_device_path;
    LUID adapter_id{};
    UINT32 source_id{};
    UINT32 target_id{};
    std::optional<DISPLAYCONFIG_SOURCE_MODE> source_mode;
};

struct DisplayInfo {
    HMONITOR handle{};
    std::wstring device_name;
    RECT monitor_rect{};
    RECT work_rect{};
    bool primary{};
    DEVMODEW devmode{};
    UINT window_dpi{96};
    UINT legacy_monitor_dpi_x{96};
    UINT legacy_monitor_dpi_y{96};
    DEVICE_SCALE_FACTOR legacy_scale_factor{SCALE_100_PERCENT};
    std::optional<DisplayConfigInfo> config;
};

struct Args {
    fs::path out_dir{L"run"};
    bool no_pointer_move{false};
    int observe_seconds{15};
    int sample_ms{16};
};

static std::string utf8(const std::wstring& s) {
    if (s.empty()) return {};
    const int n = WideCharToMultiByte(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), nullptr, 0, nullptr, nullptr);
    std::string out(static_cast<size_t>(n), '\0');
    WideCharToMultiByte(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), out.data(), n, nullptr, nullptr);
    return out;
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

static Args parse_args(int argc, wchar_t** argv) {
    Args args;
    for (int i = 1; i < argc; ++i) {
        const std::wstring a = argv[i];
        if (a == L"--out" && i + 1 < argc) args.out_dir = argv[++i];
        else if (a == L"--no-pointer-move") args.no_pointer_move = true;
        else if (a == L"--observe-seconds" && i + 1 < argc) args.observe_seconds = std::max(1, _wtoi(argv[++i]));
        else if (a == L"--sample-ms" && i + 1 < argc) args.sample_ms = std::clamp(_wtoi(argv[++i]), 1, 1000);
        else if (a == L"--help" || a == L"-h") {
            std::wcout << L"visual_spike2_coordinate_truth [--out DIR] [--no-pointer-move] [--observe-seconds N] [--sample-ms N]\n";
            std::exit(0);
        }
    }
    return args;
}

static BOOL CALLBACK enum_monitor_proc(HMONITOR hmon, HDC, LPRECT, LPARAM param) {
    auto* out = reinterpret_cast<std::vector<DisplayInfo>*>(param);
    MONITORINFOEXW mi{};
    mi.cbSize = sizeof(mi);
    if (!GetMonitorInfoW(hmon, &mi)) return TRUE;

    DisplayInfo d{};
    d.handle = hmon;
    d.device_name = mi.szDevice;
    d.monitor_rect = mi.rcMonitor;
    d.work_rect = mi.rcWork;
    d.primary = (mi.dwFlags & MONITORINFOF_PRIMARY) != 0;
    d.devmode.dmSize = sizeof(d.devmode);
    EnumDisplaySettingsExW(d.device_name.c_str(), ENUM_CURRENT_SETTINGS, &d.devmode, 0);

    // Kept only as comparison evidence. Microsoft documents GetDpiForMonitor as
    // a legacy API that should not be the canonical DPI source for a PM-aware caller.
    UINT dx = 96, dy = 96;
    if (SUCCEEDED(GetDpiForMonitor(hmon, MDT_EFFECTIVE_DPI, &dx, &dy))) {
        d.legacy_monitor_dpi_x = dx;
        d.legacy_monitor_dpi_y = dy;
    }
    DEVICE_SCALE_FACTOR sf = SCALE_100_PERCENT;
    if (SUCCEEDED(GetScaleFactorForMonitor(hmon, &sf))) d.legacy_scale_factor = sf;

    out->push_back(d);
    return TRUE;
}

static LRESULT CALLBACK dpi_probe_wndproc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    return DefWindowProcW(hwnd, msg, wp, lp);
}

static void measure_window_dpi(std::vector<DisplayInfo>& displays) {
    constexpr wchar_t kClassName[] = L"VisualSpike2DpiProbeWindow";
    WNDCLASSW wc{};
    wc.lpfnWndProc = dpi_probe_wndproc;
    wc.hInstance = GetModuleHandleW(nullptr);
    wc.lpszClassName = kClassName;
    if (!RegisterClassW(&wc) && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) return;

    for (auto& d : displays) {
        const int x = d.monitor_rect.left + (d.monitor_rect.right - d.monitor_rect.left) / 2;
        const int y = d.monitor_rect.top + (d.monitor_rect.bottom - d.monitor_rect.top) / 2;
        HWND hwnd = CreateWindowExW(
            WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
            kClassName,
            L"",
            WS_POPUP,
            x,
            y,
            1,
            1,
            nullptr,
            nullptr,
            wc.hInstance,
            nullptr);
        if (hwnd) {
            const UINT dpi = GetDpiForWindow(hwnd);
            if (dpi != 0) d.window_dpi = dpi;
            DestroyWindow(hwnd);
        }
    }
}

static std::vector<DisplayConfigInfo> query_display_config() {
    UINT32 path_count = 0, mode_count = 0;
    LONG rc = GetDisplayConfigBufferSizes(QDC_ONLY_ACTIVE_PATHS, &path_count, &mode_count);
    if (rc != ERROR_SUCCESS) return {};

    std::vector<DISPLAYCONFIG_PATH_INFO> paths(path_count);
    std::vector<DISPLAYCONFIG_MODE_INFO> modes(mode_count);
    rc = QueryDisplayConfig(QDC_ONLY_ACTIVE_PATHS, &path_count, paths.data(), &mode_count, modes.data(), nullptr);
    if (rc != ERROR_SUCCESS) return {};
    paths.resize(path_count);
    modes.resize(mode_count);

    std::vector<DisplayConfigInfo> result;
    for (const auto& path : paths) {
        DISPLAYCONFIG_SOURCE_DEVICE_NAME src{};
        src.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_SOURCE_NAME;
        src.header.size = sizeof(src);
        src.header.adapterId = path.sourceInfo.adapterId;
        src.header.id = path.sourceInfo.id;
        if (DisplayConfigGetDeviceInfo(&src.header) != ERROR_SUCCESS) continue;

        DISPLAYCONFIG_TARGET_DEVICE_NAME tgt{};
        tgt.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME;
        tgt.header.size = sizeof(tgt);
        tgt.header.adapterId = path.targetInfo.adapterId;
        tgt.header.id = path.targetInfo.id;
        DisplayConfigGetDeviceInfo(&tgt.header);

        DisplayConfigInfo info{};
        info.gdi_name = src.viewGdiDeviceName;
        info.friendly_name = tgt.monitorFriendlyDeviceName;
        info.monitor_device_path = tgt.monitorDevicePath;
        info.adapter_id = path.sourceInfo.adapterId;
        info.source_id = path.sourceInfo.id;
        info.target_id = path.targetInfo.id;

        if (path.sourceInfo.modeInfoIdx != DISPLAYCONFIG_PATH_MODE_IDX_INVALID && path.sourceInfo.modeInfoIdx < modes.size()) {
            const auto& mode = modes[path.sourceInfo.modeInfoIdx];
            if (mode.infoType == DISPLAYCONFIG_MODE_INFO_TYPE_SOURCE) info.source_mode = mode.sourceMode;
        }
        result.push_back(info);
    }
    return result;
}

static void attach_display_config(std::vector<DisplayInfo>& displays, const std::vector<DisplayConfigInfo>& config) {
    for (auto& d : displays) {
        auto it = std::find_if(config.begin(), config.end(), [&](const auto& c) { return c.gdi_name == d.device_name; });
        if (it != config.end()) d.config = *it;
    }
}

static int find_monitor_index(const std::vector<DisplayInfo>& displays, HMONITOR hmon) {
    for (size_t i = 0; i < displays.size(); ++i) if (displays[i].handle == hmon) return static_cast<int>(i);
    return -1;
}

static std::string awareness_name(DPI_AWARENESS awareness) {
    switch (awareness) {
    case DPI_AWARENESS_UNAWARE: return "unaware";
    case DPI_AWARENESS_SYSTEM_AWARE: return "system_aware";
    case DPI_AWARENESS_PER_MONITOR_AWARE: return "per_monitor_aware";
    default: return "invalid";
    }
}

static void write_displays_json(const fs::path& path, const std::vector<DisplayInfo>& displays) {
    std::ofstream f(path, std::ios::binary);
    const auto ctx = GetThreadDpiAwarenessContext();
    const auto awareness = GetAwarenessFromDpiAwarenessContext(ctx);
    const bool pmv2 = AreDpiAwarenessContextsEqual(ctx, DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2) != FALSE;

    f << "{\n";
    f << "  \"thread_dpi_awareness\": \"" << awareness_name(awareness) << "\",\n";
    f << "  \"thread_is_per_monitor_v2\": " << (pmv2 ? "true" : "false") << ",\n";
    f << "  \"api_notes\": {\n";
    f << "    \"canonical_geometry\": \"PMv2 GetMonitorInfo / EnumDisplaySettingsEx / QueryDisplayConfig comparison\",\n";
    f << "    \"canonical_monitor_dpi\": \"GetDpiForWindow on a hidden PMv2 top-level window created on each monitor\",\n";
    f << "    \"legacy_comparison_only\": \"GetDpiForMonitor and GetScaleFactorForMonitor are recorded for comparison, not treated as coordinate truth\"\n";
    f << "  },\n";
    f << "  \"virtual_screen\": {\"x\": " << GetSystemMetrics(SM_XVIRTUALSCREEN)
      << ", \"y\": " << GetSystemMetrics(SM_YVIRTUALSCREEN)
      << ", \"width\": " << GetSystemMetrics(SM_CXVIRTUALSCREEN)
      << ", \"height\": " << GetSystemMetrics(SM_CYVIRTUALSCREEN) << "},\n";
    f << "  \"display_count\": " << displays.size() << ",\n";
    f << "  \"displays\": [\n";
    for (size_t i = 0; i < displays.size(); ++i) {
        const auto& d = displays[i];
        f << "    {\n";
        f << "      \"index\": " << i << ",\n";
        f << "      \"device_name\": \"" << json_escape(utf8(d.device_name)) << "\",\n";
        f << "      \"primary\": " << (d.primary ? "true" : "false") << ",\n";
        f << "      \"monitor_rect\": {\"left\": " << d.monitor_rect.left << ", \"top\": " << d.monitor_rect.top
          << ", \"right\": " << d.monitor_rect.right << ", \"bottom\": " << d.monitor_rect.bottom << "},\n";
        f << "      \"work_rect\": {\"left\": " << d.work_rect.left << ", \"top\": " << d.work_rect.top
          << ", \"right\": " << d.work_rect.right << ", \"bottom\": " << d.work_rect.bottom << "},\n";
        f << "      \"enum_display_settings\": {\"position_x\": " << d.devmode.dmPosition.x
          << ", \"position_y\": " << d.devmode.dmPosition.y
          << ", \"width\": " << d.devmode.dmPelsWidth << ", \"height\": " << d.devmode.dmPelsHeight
          << ", \"refresh_hz\": " << d.devmode.dmDisplayFrequency << "},\n";
        f << "      \"window_dpi\": " << d.window_dpi << ",\n";
        f << "      \"legacy_get_dpi_for_monitor_effective\": {\"x\": " << d.legacy_monitor_dpi_x << ", \"y\": " << d.legacy_monitor_dpi_y << "},\n";
        f << "      \"legacy_get_scale_factor_for_monitor_percent\": " << static_cast<int>(d.legacy_scale_factor);
        if (d.config) {
            f << ",\n      \"display_config\": {\n";
            f << "        \"friendly_name\": \"" << json_escape(utf8(d.config->friendly_name)) << "\",\n";
            f << "        \"monitor_device_path\": \"" << json_escape(utf8(d.config->monitor_device_path)) << "\",\n";
            f << "        \"source_id\": " << d.config->source_id << ", \"target_id\": " << d.config->target_id;
            if (d.config->source_mode) {
                const auto& sm = *d.config->source_mode;
                f << ",\n        \"source_mode\": {\"width\": " << sm.width << ", \"height\": " << sm.height
                  << ", \"position_x\": " << sm.position.x << ", \"position_y\": " << sm.position.y << "}\n";
            } else {
                f << "\n";
            }
            f << "      }\n";
        } else {
            f << "\n";
        }
        f << "    }" << (i + 1 < displays.size() ? "," : "") << "\n";
    }
    f << "  ]\n}\n";
}

struct TelemetryWriter {
    std::ofstream f;
    LARGE_INTEGER freq{};
    LARGE_INTEGER start{};
    std::vector<DisplayInfo>* displays{};
    uint64_t sample_id{};
    int last_monitor{-2};

    TelemetryWriter(const fs::path& path, std::vector<DisplayInfo>* d) : f(path, std::ios::binary), displays(d) {
        QueryPerformanceFrequency(&freq);
        QueryPerformanceCounter(&start);
        f << "sample,qpc,elapsed_ms,phase,expected_x,expected_y,screen_x,screen_y,delta_x,delta_y,monitor_index,device_name,mon_left,mon_top,mon_right,mon_bottom,local_x,local_y,norm_x,norm_y,window_dpi,legacy_monitor_dpi_x,legacy_monitor_dpi_y,legacy_scale_percent,monitor_transition\n";
    }

    void sample(const std::string& phase, std::optional<POINT> expected = std::nullopt) {
        POINT p{};
        if (!GetCursorPos(&p)) return;
        const HMONITOR hmon = MonitorFromPoint(p, MONITOR_DEFAULTTONEAREST);
        const int idx = find_monitor_index(*displays, hmon);
        LARGE_INTEGER now{};
        QueryPerformanceCounter(&now);
        const double elapsed_ms = 1000.0 * static_cast<double>(now.QuadPart - start.QuadPart) / static_cast<double>(freq.QuadPart);

        LONG l = 0, t = 0, r = 0, b = 0;
        LONG lx = 0, ly = 0;
        double nx = 0.0, ny = 0.0;
        UINT window_dpi = 0, legacy_dpi_x = 0, legacy_dpi_y = 0;
        int scale = 0;
        std::string dev;
        if (idx >= 0) {
            const auto& d = displays->at(static_cast<size_t>(idx));
            l = d.monitor_rect.left; t = d.monitor_rect.top; r = d.monitor_rect.right; b = d.monitor_rect.bottom;

            const visual::coordinates::MonitorRect rect{l, t, r, b};
            const visual::coordinates::ScreenPoint screen{p.x, p.y};
            const auto local = visual::coordinates::to_monitor_local(screen, rect);
            const auto normalized = visual::coordinates::to_normalized(screen, rect);
            if (local) {
                lx = local->x;
                ly = local->y;
            }
            if (normalized) {
                nx = normalized->x;
                ny = normalized->y;
            }

            window_dpi = d.window_dpi;
            legacy_dpi_x = d.legacy_monitor_dpi_x;
            legacy_dpi_y = d.legacy_monitor_dpi_y;
            scale = static_cast<int>(d.legacy_scale_factor);
            dev = utf8(d.device_name);
        }
        const bool transition = idx != last_monitor;
        last_monitor = idx;

        f << sample_id++ << ',' << now.QuadPart << ',' << std::fixed << std::setprecision(3) << elapsed_ms << ',' << phase << ',';
        if (expected) f << expected->x << ',' << expected->y << ',';
        else f << ",,";
        f << p.x << ',' << p.y << ',';
        if (expected) f << (p.x - expected->x) << ',' << (p.y - expected->y) << ',';
        else f << ",,";
        f << idx << ',' << dev << ',' << l << ',' << t << ',' << r << ',' << b << ',' << lx << ',' << ly << ',';
        f << std::setprecision(8) << nx << ',' << ny << ',' << window_dpi << ',' << legacy_dpi_x << ',' << legacy_dpi_y << ',' << scale << ',' << (transition ? 1 : 0) << '\n';
        f.flush();
    }
};

static POINT center_of(const DisplayInfo& d) {
    return POINT{d.monitor_rect.left + (d.monitor_rect.right - d.monitor_rect.left) / 2,
                 d.monitor_rect.top + (d.monitor_rect.bottom - d.monitor_rect.top) / 2};
}

static void move_and_sample(TelemetryWriter& tw, const std::string& phase, POINT target, int settle_ms = 250) {
    SetCursorPos(target.x, target.y);
    constexpr int step_ms = 16;
    for (int elapsed = 0; elapsed < settle_ms; elapsed += step_ms) {
        std::this_thread::sleep_for(std::chrono::milliseconds(step_ms));
        tw.sample(phase, target);
    }
}

static void interpolate_move(TelemetryWriter& tw, const std::string& phase, POINT a, POINT b, int duration_ms) {
    constexpr int step_ms = 16;
    const int steps = std::max(1, duration_ms / step_ms);
    for (int i = 0; i <= steps; ++i) {
        const double u = static_cast<double>(i) / static_cast<double>(steps);
        POINT target{
            static_cast<LONG>(std::lround(a.x + (b.x - a.x) * u)),
            static_cast<LONG>(std::lround(a.y + (b.y - a.y) * u))
        };
        SetCursorPos(target.x, target.y);
        std::this_thread::sleep_for(std::chrono::milliseconds(step_ms));
        tw.sample(phase, target);
    }
}

static void run_scenario(std::vector<DisplayInfo>& displays, TelemetryWriter& tw) {
    std::cout << "WARNING: Spike 2 will intentionally control the real Windows pointer while the deterministic scenario is active.\n";
    std::cout << "Press Ctrl+C to abort. Starting in 2 seconds...\n";
    std::this_thread::sleep_for(std::chrono::seconds(2));

    for (size_t i = 0; i < displays.size(); ++i) {
        move_and_sample(tw, "center_m" + std::to_string(i), center_of(displays[i]), 350);
    }

    for (size_t i = 0; i < displays.size(); ++i) {
        const auto& r = displays[i].monitor_rect;
        constexpr LONG inset = 2;
        std::vector<POINT> corners{
            {r.left + inset, r.top + inset},
            {r.right - 1 - inset, r.top + inset},
            {r.right - 1 - inset, r.bottom - 1 - inset},
            {r.left + inset, r.bottom - 1 - inset}
        };
        for (size_t c = 0; c < corners.size(); ++c) {
            move_and_sample(tw, "corner_m" + std::to_string(i) + "_" + std::to_string(c), corners[c], 180);
        }
    }

    auto sorted = displays;
    std::sort(sorted.begin(), sorted.end(), [](const DisplayInfo& a, const DisplayInfo& b) {
        if (a.monitor_rect.left != b.monitor_rect.left) return a.monitor_rect.left < b.monitor_rect.left;
        return a.monitor_rect.top < b.monitor_rect.top;
    });
    if (sorted.size() >= 2) {
        for (size_t i = 0; i + 1 < sorted.size(); ++i) {
            const POINT a = center_of(sorted[i]);
            const POINT b = center_of(sorted[i + 1]);
            interpolate_move(tw, "slow_sweep", a, b, 2500);
            interpolate_move(tw, "slow_sweep_return", b, a, 2500);
            interpolate_move(tw, "fast_sweep", a, b, 350);
            interpolate_move(tw, "fast_sweep_return", b, a, 350);
        }
    }

    for (size_t i = 0; i < displays.size(); ++i) {
        move_and_sample(tw, "final_center_m" + std::to_string(i), center_of(displays[i]), 250);
    }
}

static void run_observation(TelemetryWriter& tw, int seconds, int sample_ms) {
    std::cout << "Observation-only mode: move the pointer manually. No pointer control will occur.\n";
    const auto end = std::chrono::steady_clock::now() + std::chrono::seconds(seconds);
    while (std::chrono::steady_clock::now() < end) {
        tw.sample("observe");
        std::this_thread::sleep_for(std::chrono::milliseconds(sample_ms));
    }
}

int wmain(int argc, wchar_t** argv) {
    const Args args = parse_args(argc, argv);
    fs::create_directories(args.out_dir);

    // The embedded manifest is authoritative. This programmatic call is retained as
    // a defensive check for direct/older build paths; ACCESS_DENIED means awareness
    // was already established by the manifest, which is expected.
    if (!SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)) {
        const DWORD err = GetLastError();
        if (err != ERROR_ACCESS_DENIED) {
            std::cerr << "SetProcessDpiAwarenessContext(PMv2) failed: " << err << "\n";
            return 2;
        }
    }

    std::vector<DisplayInfo> displays;
    EnumDisplayMonitors(nullptr, nullptr, enum_monitor_proc, reinterpret_cast<LPARAM>(&displays));
    if (displays.empty()) {
        std::cerr << "No active displays found.\n";
        return 3;
    }

    measure_window_dpi(displays);
    const auto config = query_display_config();
    attach_display_config(displays, config);
    write_displays_json(args.out_dir / "displays.json", displays);

    const auto ctx = GetThreadDpiAwarenessContext();
    const bool pmv2 = AreDpiAwarenessContextsEqual(ctx, DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2) != FALSE;

    std::cout << "Spike 2 pointer/coordinate truth\n";
    std::cout << "PMv2: " << (pmv2 ? "yes" : "no") << "\n";
    std::cout << "Displays: " << displays.size() << "\n";
    for (size_t i = 0; i < displays.size(); ++i) {
        const auto& d = displays[i];
        std::cout << "  [" << i << "] " << utf8(d.device_name)
                  << " primary=" << (d.primary ? 1 : 0)
                  << " rect=(" << d.monitor_rect.left << ',' << d.monitor_rect.top << ")-(" << d.monitor_rect.right << ',' << d.monitor_rect.bottom << ')'
                  << " mode=" << d.devmode.dmPelsWidth << 'x' << d.devmode.dmPelsHeight << '@' << d.devmode.dmDisplayFrequency
                  << " window_dpi=" << d.window_dpi
                  << " legacy_dpi=" << d.legacy_monitor_dpi_x
                  << " legacy_scale=" << static_cast<int>(d.legacy_scale_factor) << "%\n";
    }

    TelemetryWriter telemetry(args.out_dir / "pointer_telemetry.csv", &displays);
    if (args.no_pointer_move) run_observation(telemetry, args.observe_seconds, args.sample_ms);
    else run_scenario(displays, telemetry);

    std::ofstream done(args.out_dir / "completed.txt", std::ios::binary);
    done << "completed\n";
    std::cout << "Completed. Output: " << args.out_dir.string() << "\n";
    return 0;
}
