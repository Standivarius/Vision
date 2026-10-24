#pragma once

#include <windows.h>

#include <algorithm>

namespace visual::ui::dpi_support {

constexpr UINT kDefaultDpi = 96;

inline int scale(int value, UINT dpi) noexcept {
    return MulDiv(value, static_cast<int>(dpi ? dpi : kDefaultDpi), static_cast<int>(kDefaultDpi));
}

inline UINT for_rect(const RECT& rect) noexcept {
    UINT dpi_x = kDefaultDpi;
    UINT dpi_y = kDefaultDpi;
    const HMONITOR monitor = MonitorFromRect(&rect, MONITOR_DEFAULTTONEAREST);
    if (!monitor) return dpi_x;

    if (HMODULE shcore = LoadLibraryW(L"shcore.dll")) {
        using GetDpiForMonitorFn = HRESULT(WINAPI*)(HMONITOR, int, UINT*, UINT*);
        if (auto get_dpi = reinterpret_cast<GetDpiForMonitorFn>(GetProcAddress(shcore, "GetDpiForMonitor"))) {
            if (FAILED(get_dpi(monitor, 0, &dpi_x, &dpi_y))) {
                dpi_x = kDefaultDpi;
            }
        }
        FreeLibrary(shcore);
    }
    return dpi_x ? dpi_x : kDefaultDpi;
}

inline HFONT create_message_font(UINT dpi, LONG weight = FW_NORMAL, int height_percent = 100) noexcept {
    NONCLIENTMETRICSW metrics{};
    metrics.cbSize = sizeof(metrics);

    using SystemParametersInfoForDpiFn = BOOL(WINAPI*)(UINT, UINT, PVOID, UINT, UINT);
    auto spi_for_dpi = reinterpret_cast<SystemParametersInfoForDpiFn>(
        GetProcAddress(GetModuleHandleW(L"user32.dll"), "SystemParametersInfoForDpi"));

    if (spi_for_dpi &&
        spi_for_dpi(SPI_GETNONCLIENTMETRICS, sizeof(metrics), &metrics, 0, dpi ? dpi : kDefaultDpi)) {
        LOGFONTW font = metrics.lfMessageFont;
        font.lfWeight = weight;
        font.lfHeight = MulDiv(font.lfHeight, height_percent, 100);
        if (HFONT result = CreateFontIndirectW(&font)) return result;
    }

    return CreateFontW(
        -scale(MulDiv(19, height_percent, 100), dpi),
        0, 0, 0, weight, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
        OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
        DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
}

} // namespace visual::ui::dpi_support
