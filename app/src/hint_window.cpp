#include "hint_window.h"

#include <algorithm>

namespace visual::ui {
namespace {

constexpr wchar_t kHintClass[] = L"VisualContextHintWindow";
constexpr UINT_PTR kHideTimer = 1;
constexpr int kWidth = 560;
constexpr int kHeight = 126;
constexpr int kMargin = 28;

} // namespace

HintWindow::~HintWindow() {
    destroy();
}

bool HintWindow::create(HINSTANCE instance, const RECT& preferred_monitor_rect) {
    destroy();
    instance_ = instance;
    monitor_rect_ = preferred_monitor_rect;

    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(wc);
    wc.hInstance = instance;
    wc.lpfnWndProc = &HintWindow::window_proc;
    wc.lpszClassName = kHintClass;
    wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    wc.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_INFOBK + 1);
    if (!RegisterClassExW(&wc) && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) return false;

    const int monitor_width = monitor_rect_.right - monitor_rect_.left;
    const int monitor_height = monitor_rect_.bottom - monitor_rect_.top;
    const int width = std::min(kWidth, std::max(360, monitor_width - kMargin * 2));
    const int height = std::min(kHeight, std::max(96, monitor_height / 7));
    const int x = monitor_rect_.right - width - kMargin;
    const int y = monitor_rect_.bottom - height - kMargin;

    hwnd_ = CreateWindowExW(
        WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
        kHintClass,
        L"Visual hint",
        WS_POPUP | WS_BORDER,
        x, y, width, height,
        nullptr, nullptr, instance, this);
    if (!hwnd_) return false;

    title_font_ = CreateFontW(-22, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
                              OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                              DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
    body_font_ = CreateFontW(-18, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
                             OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                             DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
    return true;
}

void HintWindow::show(const std::wstring& title, const std::wstring& message, UINT duration_ms) {
    if (!hwnd_) return;
    title_ = title;
    message_ = message;
    const std::wstring accessible_text = title_ + L". " + message_;
    SetWindowTextW(hwnd_, accessible_text.c_str());
    KillTimer(hwnd_, kHideTimer);
    InvalidateRect(hwnd_, nullptr, TRUE);
    ShowWindow(hwnd_, SW_SHOWNOACTIVATE);
    NotifyWinEvent(EVENT_SYSTEM_ALERT, hwnd_, OBJID_WINDOW, CHILDID_SELF);
    SetWindowPos(hwnd_, HWND_TOPMOST, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_SHOWWINDOW);
    SetTimer(hwnd_, kHideTimer, std::max<UINT>(1500, duration_ms), nullptr);
}

void HintWindow::hide() noexcept {
    if (!hwnd_) return;
    KillTimer(hwnd_, kHideTimer);
    ShowWindow(hwnd_, SW_HIDE);
}

void HintWindow::destroy() noexcept {
    hide();
    if (hwnd_) DestroyWindow(hwnd_);
    hwnd_ = nullptr;
    if (title_font_) DeleteObject(title_font_);
    if (body_font_) DeleteObject(body_font_);
    title_font_ = nullptr;
    body_font_ = nullptr;
}

LRESULT CALLBACK HintWindow::window_proc(HWND hwnd, UINT message, WPARAM w_param, LPARAM l_param) {
    HintWindow* self = reinterpret_cast<HintWindow*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    if (message == WM_NCCREATE) {
        const auto* create = reinterpret_cast<const CREATESTRUCTW*>(l_param);
        self = static_cast<HintWindow*>(create->lpCreateParams);
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
        if (self) self->hwnd_ = hwnd;
    }
    return self ? self->handle_message(message, w_param, l_param)
                : DefWindowProcW(hwnd, message, w_param, l_param);
}

LRESULT HintWindow::handle_message(UINT message, WPARAM w_param, LPARAM l_param) {
    switch (message) {
    case WM_TIMER:
        if (w_param == kHideTimer) {
            hide();
            return 0;
        }
        break;
    case WM_PAINT:
        paint();
        return 0;
    case WM_MOUSEACTIVATE:
        return MA_NOACTIVATE;
    case WM_NCHITTEST:
        return HTTRANSPARENT;
    case WM_ERASEBKGND:
        return 1;
    case WM_DESTROY:
        hwnd_ = nullptr;
        return 0;
    default:
        break;
    }
    return DefWindowProcW(hwnd_, message, w_param, l_param);
}

void HintWindow::paint() {
    PAINTSTRUCT ps{};
    HDC dc = BeginPaint(hwnd_, &ps);
    if (!dc) return;

    RECT client{};
    GetClientRect(hwnd_, &client);
    HBRUSH background = CreateSolidBrush(RGB(255, 251, 225));
    FillRect(dc, &client, background);
    DeleteObject(background);

    SetBkMode(dc, TRANSPARENT);
    SetTextColor(dc, RGB(25, 32, 44));
    RECT title_rect{18, 12, client.right - 18, 42};
    if (title_font_) SelectObject(dc, title_font_);
    DrawTextW(dc, title_.c_str(), -1, &title_rect, DT_LEFT | DT_SINGLELINE | DT_END_ELLIPSIS);

    RECT body_rect{18, 44, client.right - 18, client.bottom - 12};
    if (body_font_) SelectObject(dc, body_font_);
    DrawTextW(dc, message_.c_str(), -1, &body_rect, DT_LEFT | DT_WORDBREAK | DT_NOPREFIX);

    EndPaint(hwnd_, &ps);
}

} // namespace visual::ui
