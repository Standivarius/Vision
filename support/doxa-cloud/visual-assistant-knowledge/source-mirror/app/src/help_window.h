#pragma once

#include "core/help_catalog.h"

#include <windows.h>

#include <functional>
#include <string>

namespace visual::ui {

class HelpWindow {
public:
    using ContextProvider = std::function<std::string()>;

    HelpWindow() = default;
    HelpWindow(const HelpWindow&) = delete;
    HelpWindow& operator=(const HelpWindow&) = delete;
    ~HelpWindow();

    bool create(HINSTANCE instance,
                HWND owner,
                const RECT& preferred_monitor_rect,
                ContextProvider context_provider);
    void show();
    void hide() noexcept;
    void destroy() noexcept;

    [[nodiscard]] HWND hwnd() const noexcept { return hwnd_; }

private:
    static LRESULT CALLBACK window_proc(HWND hwnd, UINT message, WPARAM w_param, LPARAM l_param);
    LRESULT handle_message(UINT message, WPARAM w_param, LPARAM l_param);
    void create_controls();
    void layout_controls(int client_width, int client_height);
    void set_font_recursive(HWND root);
    void ask();
    void show_topic(visual::core::HelpTopic topic);
    void show_answer(const std::wstring& title, const std::wstring& body, const std::wstring& status);

    HINSTANCE instance_{};
    HWND owner_{};
    HWND hwnd_{};
    HFONT font_{};
    HFONT heading_font_{};
    ContextProvider context_provider_{};
    bool busy_{};

    HWND intro_{};
    HWND question_edit_{};
    HWND ask_button_{};
    HWND answer_title_{};
    HWND answer_edit_{};
    HWND status_{};
};

} // namespace visual::ui
