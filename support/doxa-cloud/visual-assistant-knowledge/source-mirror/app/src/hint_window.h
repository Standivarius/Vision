#pragma once

#include <windows.h>

#include <string>

namespace visual::ui {

class HintWindow {
public:
    HintWindow() = default;
    HintWindow(const HintWindow&) = delete;
    HintWindow& operator=(const HintWindow&) = delete;
    ~HintWindow();

    bool create(HINSTANCE instance, const RECT& preferred_monitor_rect);
    void show(const std::wstring& title, const std::wstring& message, UINT duration_ms = 6500);
    void hide() noexcept;
    void destroy() noexcept;

    [[nodiscard]] HWND hwnd() const noexcept { return hwnd_; }

private:
    static LRESULT CALLBACK window_proc(HWND hwnd, UINT message, WPARAM w_param, LPARAM l_param);
    LRESULT handle_message(UINT message, WPARAM w_param, LPARAM l_param);
    void paint();

    HINSTANCE instance_{};
    HWND hwnd_{};
    RECT monitor_rect_{};
    HFONT title_font_{};
    HFONT body_font_{};
    std::wstring title_;
    std::wstring message_;
};

} // namespace visual::ui
