#include "help_window.h"

#include "ui_dpi.h"
#include "core/ui_strings.h"

#include "assistant_client.h"

#include <windowsx.h>

#include <algorithm>
#include <memory>
#include <thread>

namespace visual::ui {
namespace {

constexpr wchar_t kHelpClass[] = L"VisualHelpWindow";
constexpr UINT kAnswerReadyMessage = WM_APP + 20;
constexpr int kWindowWidth = 760;
constexpr int kWindowHeight = 620;

constexpr int kIdQuestion = 2001;
constexpr int kIdAsk = 2002;
constexpr int kIdClose = 2003;
constexpr int kIdScreenRoles = 2010;
constexpr int kIdTracking = 2011;
constexpr int kIdViewLocator = 2012;
constexpr int kIdOneX = 2013;
constexpr int kIdFreeze = 2014;
constexpr int kIdShortcuts = 2015;
constexpr int kIdColour = 2016;
constexpr int kIdSettings = 2017;

using visual::core::UiStringId;

const wchar_t* text(UiStringId id) noexcept {
    return visual::core::ui_string(id).data();
}

struct AsyncAnswer {
    visual::assistant::AnswerResult result;
};

HWND make_control(HWND parent, const wchar_t* klass, const wchar_t* text, DWORD style, int id) {
    return CreateWindowExW(0, klass, text, WS_CHILD | WS_VISIBLE | style,
                           0, 0, 10, 10, parent, reinterpret_cast<HMENU>(static_cast<INT_PTR>(id)),
                           GetModuleHandleW(nullptr), nullptr);
}

std::wstring window_text(HWND hwnd) {
    const int length = GetWindowTextLengthW(hwnd);
    if (length <= 0) return {};
    std::wstring text(static_cast<std::size_t>(length + 1), L'\0');
    GetWindowTextW(hwnd, text.data(), length + 1);
    text.resize(static_cast<std::size_t>(length));
    return text;
}

} // namespace

HelpWindow::~HelpWindow() {
    destroy();
}

bool HelpWindow::create(HINSTANCE instance,
                        HWND owner,
                        const RECT& preferred_monitor_rect,
                        ContextProvider context_provider) {
    destroy();
    instance_ = instance;
    owner_ = owner;
    context_provider_ = std::move(context_provider);

    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(wc);
    wc.hInstance = instance;
    wc.lpfnWndProc = &HelpWindow::window_proc;
    wc.lpszClassName = kHelpClass;
    wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    wc.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
    wc.hIcon = LoadIconW(nullptr, IDI_APPLICATION);
    if (!RegisterClassExW(&wc) && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) return false;

    current_dpi_ = dpi_support::for_rect(preferred_monitor_rect);
    const auto px = [this](int value) { return dpi_support::scale(value, current_dpi_); };
    const int available_width = preferred_monitor_rect.right - preferred_monitor_rect.left;
    const int available_height = preferred_monitor_rect.bottom - preferred_monitor_rect.top;
    const int width = std::min(px(kWindowWidth), std::max(px(560), available_width - px(100)));
    const int height = std::min(px(kWindowHeight), std::max(px(500), available_height - px(100)));
    const int x = preferred_monitor_rect.left + std::max(px(20), (available_width - width) / 2);
    const int y = preferred_monitor_rect.top + std::max(px(20), (available_height - height) / 2);

    hwnd_ = CreateWindowExW(WS_EX_APPWINDOW | WS_EX_CONTROLPARENT,
                            kHelpClass,
                            text(UiStringId::HelpTitle),
                            WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX | WS_CLIPCHILDREN,
                            x, y, width, height, owner, nullptr, instance, this);
    return hwnd_ != nullptr;
}

void HelpWindow::show() {
    if (!hwnd_) return;
    ShowWindow(hwnd_, SW_SHOWNORMAL);
    SetForegroundWindow(hwnd_);
    if (question_edit_) SetFocus(question_edit_);
}

void HelpWindow::hide() noexcept {
    if (hwnd_) ShowWindow(hwnd_, SW_HIDE);
}

void HelpWindow::destroy() noexcept {
    if (hwnd_) DestroyWindow(hwnd_);
    hwnd_ = nullptr;
    if (font_) DeleteObject(font_);
    if (heading_font_) DeleteObject(heading_font_);
    font_ = nullptr;
    heading_font_ = nullptr;
    context_provider_ = {};
    busy_ = false;
}

LRESULT CALLBACK HelpWindow::question_edit_proc(HWND hwnd, UINT message, WPARAM w_param, LPARAM l_param) {
    auto* self = reinterpret_cast<HelpWindow*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    if (message == WM_KEYDOWN && (GetKeyState(VK_CONTROL) & 0x8000) != 0 &&
        (w_param == L'A' || w_param == L'a')) {
        SendMessageW(hwnd, EM_SETSEL, 0, -1);
        return 0;
    }
    if (self && self->question_edit_original_proc_) {
        return CallWindowProcW(self->question_edit_original_proc_, hwnd, message, w_param, l_param);
    }
    return DefWindowProcW(hwnd, message, w_param, l_param);
}
LRESULT CALLBACK HelpWindow::window_proc(HWND hwnd, UINT message, WPARAM w_param, LPARAM l_param) {
    HelpWindow* self = reinterpret_cast<HelpWindow*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    if (message == WM_NCCREATE) {
        const auto* create = reinterpret_cast<const CREATESTRUCTW*>(l_param);
        self = static_cast<HelpWindow*>(create->lpCreateParams);
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
        if (self) self->hwnd_ = hwnd;
    }
    return self ? self->handle_message(message, w_param, l_param)
                : DefWindowProcW(hwnd, message, w_param, l_param);
}

LRESULT HelpWindow::handle_message(UINT message, WPARAM w_param, LPARAM l_param) {
    switch (message) {
    case WM_CREATE:
        create_controls();
        return 0;
    case WM_SIZE:
        layout_controls(LOWORD(l_param), HIWORD(l_param));
        return 0;
    case WM_DPICHANGED: {
        current_dpi_ = HIWORD(w_param) ? HIWORD(w_param) : dpi_support::kDefaultDpi;
        const auto* suggested = reinterpret_cast<const RECT*>(l_param);
        if (suggested) {
            SetWindowPos(hwnd_, nullptr, suggested->left, suggested->top,
                         suggested->right - suggested->left, suggested->bottom - suggested->top,
                         SWP_NOZORDER | SWP_NOACTIVATE);
        }
        refresh_fonts(current_dpi_);
        RECT client{};
        if (GetClientRect(hwnd_, &client)) {
            layout_controls(client.right - client.left, client.bottom - client.top);
        }
        return 0;
    }
    case WM_SETTINGCHANGE: {
        current_dpi_ = GetDpiForWindow(hwnd_);
        refresh_fonts(current_dpi_);
        RECT client{};
        if (GetClientRect(hwnd_, &client)) {
            layout_controls(client.right - client.left, client.bottom - client.top);
        }
        return 0;
    }
    case WM_COMMAND:
        switch (LOWORD(w_param)) {
        case kIdAsk: ask(); return 0;
        case kIdClose: hide(); return 0;
        case kIdScreenRoles: show_topic(visual::core::HelpTopic::ScreenRoles); return 0;
        case kIdTracking: show_topic(visual::core::HelpTopic::Tracking); return 0;
        case kIdViewLocator: show_topic(visual::core::HelpTopic::ViewLocator); return 0;
        case kIdOneX: show_topic(visual::core::HelpTopic::OneXReturn); return 0;
        case kIdFreeze: show_topic(visual::core::HelpTopic::FreezeView); return 0;
        case kIdShortcuts: show_topic(visual::core::HelpTopic::Shortcuts); return 0;
        case kIdColour: show_topic(visual::core::HelpTopic::ColourContrast); return 0;
        case kIdSettings: show_topic(visual::core::HelpTopic::SettingsPersistence); return 0;
        default: break;
        }
        break;
    case kAnswerReadyMessage: {
        std::unique_ptr<AsyncAnswer> answer(reinterpret_cast<AsyncAnswer*>(l_param));
        busy_ = false;
        if (question_edit_) EnableWindow(question_edit_, TRUE);
        if (ask_button_) {
            EnableWindow(ask_button_, TRUE);
            SetWindowTextW(ask_button_, text(UiStringId::HelpAsk));
        }
        if (answer) show_answer(answer->result.title, answer->result.answer, answer->result.status);
        if (question_edit_) SetFocus(question_edit_);
        return 0;
    }
    case WM_CLOSE:
        hide();
        return 0;
    case WM_DESTROY:
        hwnd_ = nullptr;
        return 0;
    default:
        break;
    }
    return DefWindowProcW(hwnd_, message, w_param, l_param);
}

void HelpWindow::create_controls() {
    intro_ = make_control(hwnd_, L"STATIC",
        text(UiStringId::HelpIntro),
        SS_LEFT | SS_NOPREFIX, -1);
    question_edit_ = make_control(hwnd_, L"EDIT", L"",
        WS_TABSTOP | WS_BORDER | ES_AUTOHSCROLL, kIdQuestion);
    SetWindowLongPtrW(question_edit_, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(this));
    question_edit_original_proc_ = reinterpret_cast<WNDPROC>(
        SetWindowLongPtrW(question_edit_, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(&HelpWindow::question_edit_proc)));
    ask_button_ = make_control(hwnd_, L"BUTTON", text(UiStringId::HelpAsk), BS_DEFPUSHBUTTON | WS_TABSTOP, kIdAsk);

    make_control(hwnd_, L"BUTTON", text(UiStringId::HelpScreenRoles), BS_PUSHBUTTON | WS_TABSTOP, kIdScreenRoles);
    make_control(hwnd_, L"BUTTON", text(UiStringId::HelpTracking), BS_PUSHBUTTON | WS_TABSTOP, kIdTracking);
    make_control(hwnd_, L"BUTTON", text(UiStringId::HelpViewLocator), BS_PUSHBUTTON | WS_TABSTOP, kIdViewLocator);
    make_control(hwnd_, L"BUTTON", text(UiStringId::HelpOneXReturn), BS_PUSHBUTTON | WS_TABSTOP, kIdOneX);
    make_control(hwnd_, L"BUTTON", text(UiStringId::HelpFreeze), BS_PUSHBUTTON | WS_TABSTOP, kIdFreeze);
    make_control(hwnd_, L"BUTTON", text(UiStringId::HelpShortcuts), BS_PUSHBUTTON | WS_TABSTOP, kIdShortcuts);
    make_control(hwnd_, L"BUTTON", text(UiStringId::HelpColourContrast), BS_PUSHBUTTON | WS_TABSTOP, kIdColour);
    make_control(hwnd_, L"BUTTON", text(UiStringId::HelpSettings), BS_PUSHBUTTON | WS_TABSTOP, kIdSettings);

    answer_title_ = make_control(hwnd_, L"STATIC", text(UiStringId::HelpCommonTitle), SS_LEFT, -1);
    answer_edit_ = CreateWindowExW(WS_EX_CLIENTEDGE, L"STATIC",
        L"Choose a topic above, or type a question.\r\n\r\nExamples: Where is Freeze View? What does the View Locator show? Why isn't Vision following my text cursor?",
        WS_CHILD | WS_VISIBLE | SS_LEFT | SS_NOPREFIX,
        0, 0, 10, 10, hwnd_, nullptr, instance_, nullptr);
    status_ = make_control(hwnd_, L"STATIC",
        visual::assistant::remote_configured() ? text(UiStringId::HelpStatusLocalOnline) : text(UiStringId::HelpStatusLocalOnly),
        SS_LEFT | SS_NOPREFIX, -1);
    make_control(hwnd_, L"BUTTON", text(UiStringId::HelpClose), BS_PUSHBUTTON | WS_TABSTOP, kIdClose);

    refresh_fonts(current_dpi_);
}

void HelpWindow::refresh_fonts(UINT dpi) {
    HFONT next_body = dpi_support::create_message_font(dpi);
    HFONT next_heading = dpi_support::create_message_font(dpi, FW_SEMIBOLD, 116);
    if (!next_body || !next_heading) {
        if (next_body) DeleteObject(next_body);
        if (next_heading) DeleteObject(next_heading);
        return;
    }

    HFONT old_body = font_;
    HFONT old_heading = heading_font_;
    font_ = next_body;
    heading_font_ = next_heading;
    set_font_recursive(hwnd_);
    if (answer_title_) SendMessageW(answer_title_, WM_SETFONT, reinterpret_cast<WPARAM>(heading_font_), TRUE);
    if (old_body) DeleteObject(old_body);
    if (old_heading) DeleteObject(old_heading);
}

void HelpWindow::layout_controls(int client_width, int client_height) {
    if (!question_edit_) return;
    const auto px = [this](int value) { return dpi_support::scale(value, current_dpi_); };
    const int margin = px(24);
    const int content_width = std::max(px(500), client_width - margin * 2);
    int y = px(20);

    SetWindowPos(intro_, nullptr, margin, y, content_width, px(48), SWP_NOZORDER);
    y += px(58);
    const int ask_width = px(110);
    SetWindowPos(question_edit_, nullptr, margin, y, content_width - ask_width - px(12), px(36), SWP_NOZORDER);
    SetWindowPos(ask_button_, nullptr, margin + content_width - ask_width, y, ask_width, px(36), SWP_NOZORDER);
    y += px(52);

    const int gap = px(8);
    const int button_width = (content_width - gap * 3) / 4;
    const int ids_row1[] = {kIdScreenRoles, kIdTracking, kIdViewLocator, kIdOneX};
    const int ids_row2[] = {kIdFreeze, kIdShortcuts, kIdColour, kIdSettings};
    for (int i = 0; i < 4; ++i) {
        SetWindowPos(GetDlgItem(hwnd_, ids_row1[i]), nullptr, margin + i * (button_width + gap), y, button_width, px(34), SWP_NOZORDER);
    }
    y += px(42);
    for (int i = 0; i < 4; ++i) {
        SetWindowPos(GetDlgItem(hwnd_, ids_row2[i]), nullptr, margin + i * (button_width + gap), y, button_width, px(34), SWP_NOZORDER);
    }
    y += px(54);

    SetWindowPos(answer_title_, nullptr, margin, y, content_width, px(34), SWP_NOZORDER);
    y += px(36);
    const int footer_height = px(56);
    const int answer_height = std::max(px(150), client_height - y - footer_height - margin);
    SetWindowPos(answer_edit_, nullptr, margin, y, content_width, answer_height, SWP_NOZORDER);
    y += answer_height + px(10);
    SetWindowPos(status_, nullptr, margin, y + px(6), content_width - px(130), px(28), SWP_NOZORDER);
    SetWindowPos(GetDlgItem(hwnd_, kIdClose), nullptr, margin + content_width - px(115), y, px(115), px(36), SWP_NOZORDER);
}

void HelpWindow::set_font_recursive(HWND root) {
    if (!font_) return;
    SendMessageW(root, WM_SETFONT, reinterpret_cast<WPARAM>(font_), TRUE);
    for (HWND child = GetWindow(root, GW_CHILD); child; child = GetWindow(child, GW_HWNDNEXT)) {
        SendMessageW(child, WM_SETFONT, reinterpret_cast<WPARAM>(font_), TRUE);
    }
}

void HelpWindow::ask() {
    if (busy_ || !question_edit_) return;
    wchar_t question_buffer[1024]{};
    SendMessageW(question_edit_, WM_GETTEXT, static_cast<WPARAM>(ARRAYSIZE(question_buffer)), reinterpret_cast<LPARAM>(question_buffer));
    const std::wstring question(question_buffer);
    if (question.empty()) {
        show_answer(text(UiStringId::HelpAskPromptTitle), text(UiStringId::HelpAskPromptBody), text(UiStringId::HelpStatusLocal));
        return;
    }

    std::string context = context_provider_ ? context_provider_() : std::string("{}");
    busy_ = true;
    EnableWindow(question_edit_, FALSE);
    EnableWindow(ask_button_, FALSE);
    SetWindowTextW(ask_button_, text(UiStringId::HelpWorking));
    SetWindowTextW(answer_title_, text(UiStringId::HelpWorking));
    SetWindowTextW(answer_edit_,
        text(UiStringId::HelpWorkingBody));
    SetWindowTextW(status_, text(UiStringId::HelpWorkingStatus));
    RedrawWindow(hwnd_, nullptr, nullptr, RDW_INVALIDATE | RDW_UPDATENOW | RDW_ALLCHILDREN);

    const HWND target = hwnd_;
    std::thread([target, question, context = std::move(context)]() mutable {
        auto answer = std::make_unique<AsyncAnswer>();
        answer->result = visual::assistant::answer_question(question, context);
        if (IsWindow(target)) {
            if (PostMessageW(target, kAnswerReadyMessage, 0, reinterpret_cast<LPARAM>(answer.get()))) {
                answer.release();
            }
        }
    }).detach();
}

void HelpWindow::show_topic(visual::core::HelpTopic topic) {
    const auto answer = visual::core::help_answer(topic);
    show_answer(answer.title, answer.body, text(UiStringId::HelpStatusLocal));
}

void HelpWindow::show_answer(const std::wstring& title, const std::wstring& body, const std::wstring& status) {
    if (answer_title_) SetWindowTextW(answer_title_, title.c_str());
    if (answer_edit_) SetWindowTextW(answer_edit_, body.c_str());
    if (status_) SetWindowTextW(status_, status.c_str());
}

} // namespace visual::ui
