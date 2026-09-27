#include "help_window.h"

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

    const int available_width = preferred_monitor_rect.right - preferred_monitor_rect.left;
    const int available_height = preferred_monitor_rect.bottom - preferred_monitor_rect.top;
    const int width = std::min(kWindowWidth, std::max(560, available_width - 100));
    const int height = std::min(kWindowHeight, std::max(500, available_height - 100));
    const int x = preferred_monitor_rect.left + std::max(20, (available_width - width) / 2);
    const int y = preferred_monitor_rect.top + std::max(20, (available_height - height) / 2);

    hwnd_ = CreateWindowExW(WS_EX_APPWINDOW | WS_EX_CONTROLPARENT,
                            kHelpClass,
                            L"Visual Help / Ask Visual",
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
        if (ask_button_) {
            EnableWindow(ask_button_, TRUE);
            SetWindowTextW(ask_button_, L"&Ask");
        }
        if (answer) show_answer(answer->result.title, answer->result.answer, answer->result.status);
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
    font_ = CreateFontW(-19, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
                        OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                        DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
    heading_font_ = CreateFontW(-22, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
                                OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                                DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");

    intro_ = make_control(hwnd_, L"STATIC",
        L"Ask in your own words. Visual answers known questions locally and only uses an online assistant when a configured endpoint is needed.",
        SS_LEFT | SS_NOPREFIX, -1);
    question_edit_ = make_control(hwnd_, L"EDIT", L"",
        WS_TABSTOP | WS_BORDER | ES_AUTOHSCROLL, kIdQuestion);
    ask_button_ = make_control(hwnd_, L"BUTTON", L"&Ask", BS_DEFPUSHBUTTON | WS_TABSTOP, kIdAsk);

    make_control(hwnd_, L"BUTTON", L"Screen Roles", BS_PUSHBUTTON | WS_TABSTOP, kIdScreenRoles);
    make_control(hwnd_, L"BUTTON", L"Tracking", BS_PUSHBUTTON | WS_TABSTOP, kIdTracking);
    make_control(hwnd_, L"BUTTON", L"View Locator", BS_PUSHBUTTON | WS_TABSTOP, kIdViewLocator);
    make_control(hwnd_, L"BUTTON", L"1x View / Return", BS_PUSHBUTTON | WS_TABSTOP, kIdOneX);
    make_control(hwnd_, L"BUTTON", L"Freeze / Hooked Areas", BS_PUSHBUTTON | WS_TABSTOP, kIdFreeze);
    make_control(hwnd_, L"BUTTON", L"Shortcuts", BS_PUSHBUTTON | WS_TABSTOP, kIdShortcuts);
    make_control(hwnd_, L"BUTTON", L"Colour & Contrast", BS_PUSHBUTTON | WS_TABSTOP, kIdColour);
    make_control(hwnd_, L"BUTTON", L"Settings", BS_PUSHBUTTON | WS_TABSTOP, kIdSettings);

    answer_title_ = make_control(hwnd_, L"STATIC", L"Common Visual help", SS_LEFT, -1);
    answer_edit_ = CreateWindowExW(WS_EX_CLIENTEDGE, L"STATIC",
        L"Choose a topic above, or type a question.\r\n\r\nExamples: Where is Freeze View? What does the View Locator show? Why isn't Visual following my text cursor?",
        WS_CHILD | WS_VISIBLE | SS_LEFT | SS_NOPREFIX,
        0, 0, 10, 10, hwnd_, nullptr, instance_, nullptr);
    status_ = make_control(hwnd_, L"STATIC",
        visual::assistant::remote_configured() ? L"Local help + configured online fallback" : L"Local Visual help - online fallback not configured",
        SS_LEFT | SS_NOPREFIX, -1);
    make_control(hwnd_, L"BUTTON", L"&Close", BS_PUSHBUTTON | WS_TABSTOP, kIdClose);

    set_font_recursive(hwnd_);
    if (answer_title_ && heading_font_) SendMessageW(answer_title_, WM_SETFONT, reinterpret_cast<WPARAM>(heading_font_), TRUE);
}

void HelpWindow::layout_controls(int client_width, int client_height) {
    if (!question_edit_) return;
    const int margin = 24;
    const int content_width = std::max(500, client_width - margin * 2);
    int y = 20;

    SetWindowPos(intro_, nullptr, margin, y, content_width, 48, SWP_NOZORDER);
    y += 58;
    const int ask_width = 110;
    SetWindowPos(question_edit_, nullptr, margin, y, content_width - ask_width - 12, 36, SWP_NOZORDER);
    SetWindowPos(ask_button_, nullptr, margin + content_width - ask_width, y, ask_width, 36, SWP_NOZORDER);
    y += 52;

    const int gap = 8;
    const int button_width = (content_width - gap * 3) / 4;
    const int ids_row1[] = {kIdScreenRoles, kIdTracking, kIdViewLocator, kIdOneX};
    const int ids_row2[] = {kIdFreeze, kIdShortcuts, kIdColour, kIdSettings};
    for (int i = 0; i < 4; ++i) {
        SetWindowPos(GetDlgItem(hwnd_, ids_row1[i]), nullptr, margin + i * (button_width + gap), y, button_width, 34, SWP_NOZORDER);
    }
    y += 42;
    for (int i = 0; i < 4; ++i) {
        SetWindowPos(GetDlgItem(hwnd_, ids_row2[i]), nullptr, margin + i * (button_width + gap), y, button_width, 34, SWP_NOZORDER);
    }
    y += 54;

    SetWindowPos(answer_title_, nullptr, margin, y, content_width, 34, SWP_NOZORDER);
    y += 36;
    const int footer_height = 56;
    const int answer_height = std::max(150, client_height - y - footer_height - margin);
    SetWindowPos(answer_edit_, nullptr, margin, y, content_width, answer_height, SWP_NOZORDER);
    y += answer_height + 10;
    SetWindowPos(status_, nullptr, margin, y + 6, content_width - 130, 28, SWP_NOZORDER);
    SetWindowPos(GetDlgItem(hwnd_, kIdClose), nullptr, margin + content_width - 115, y, 115, 36, SWP_NOZORDER);
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
        show_answer(L"Ask Visual", L"Type a short question, or choose one of the common topics.", L"Local Visual help");
        return;
    }

    std::string context = context_provider_ ? context_provider_() : std::string("{}");
    busy_ = true;
    EnableWindow(ask_button_, FALSE);
    SetWindowTextW(ask_button_, L"Working...");
    SetWindowTextW(status_, L"Looking for the smallest useful answer...");

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
    show_answer(answer.title, answer.body, L"Local Visual help");
}

void HelpWindow::show_answer(const std::wstring& title, const std::wstring& body, const std::wstring& status) {
    if (answer_title_) SetWindowTextW(answer_title_, title.c_str());
    if (answer_edit_) SetWindowTextW(answer_edit_, body.c_str());
    if (status_) SetWindowTextW(status_, status.c_str());
}

} // namespace visual::ui
