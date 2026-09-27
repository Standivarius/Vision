#pragma once

#include "settings_model.h"

#include <algorithm>
#include <cwctype>
#include <sstream>
#include <string>
#include <string_view>

namespace visual::core {

enum class HelpTopic {
    ScreenRoles,
    ViewLocator,
    Tracking,
    OneXReturn,
    FreezeView,
    ColourContrast,
    Shortcuts,
    SettingsPersistence,
    Reference,
    ZoomLevel,
};

struct HelpAnswer {
    bool matched{};
    std::wstring title;
    std::wstring body;
};

[[nodiscard]] inline std::wstring normalize_help_query(std::wstring_view input) {
    std::wstring normalized;
    normalized.reserve(input.size());
    bool previous_space = true;
    for (wchar_t ch : input) {
        const wchar_t lower = static_cast<wchar_t>(std::towlower(ch));
        const bool word_char = std::iswalnum(lower) || lower == L'+' || lower == L'x';
        if (word_char) {
            normalized.push_back(lower);
            previous_space = false;
        } else if (!previous_space) {
            normalized.push_back(L' ');
            previous_space = true;
        }
    }
    while (!normalized.empty() && normalized.back() == L' ') normalized.pop_back();
    return normalized;
}

[[nodiscard]] inline bool help_contains(const std::wstring& normalized, std::wstring_view term) {
    return normalized.find(term) != std::wstring::npos;
}

[[nodiscard]] inline HelpAnswer help_answer(HelpTopic topic) {
    switch (topic) {
    case HelpTopic::ScreenRoles:
        return {true, L"Screen Roles",
            L"Context keeps the full 1x workspace visible. Detail shows the area you are working in enlarged. "
            L"Reference is an optional normal Windows screen that Visual leaves unchanged. Screen-role changes are saved and apply the next time Visual starts."};
    case HelpTopic::ViewLocator:
        return {true, L"View Locator",
            L"The View Locator is the frame on the Context screen. It shows exactly which area is currently enlarged on Detail. "
            L"You can show or hide it in Visual Settings."};
    case HelpTopic::Tracking:
        return {true, L"Tracking",
            L"Tracking keeps Detail with the part of the workspace you are using. Follow Pointer responds to deliberate mouse movement. "
            L"Follow Text Cursor follows where you type or edit text. Follow Keyboard Focus follows controls while you navigate with the keyboard."};
    case HelpTopic::OneXReturn:
        return {true, L"1x View / Return",
            L"Use Ctrl+Alt+0 to switch temporarily to a full 1x view. Use the same command again to return to your previous zoom level and exact magnified position."};
    case HelpTopic::FreezeView:
        return {true, L"Freeze View / Hooked Areas",
            L"Visual does not currently implement ZoomText Freeze View or SuperNova Hooked Areas. If your goal is simply to keep separate information visible, "
            L"an optional Reference screen may help, but it is not the same as a frozen magnified region."};
    case HelpTopic::ColourContrast:
        return {true, L"Colour & Contrast",
            L"Visual can leave colours unchanged, increase contrast in the Detail image, invert colours, or show Detail in grayscale. "
            L"Increase Contrast changes only Visual's Detail image; it does not switch the Windows High Contrast theme."};
    case HelpTopic::Shortcuts:
        return {true, L"Keyboard Shortcuts",
            L"Ctrl+Alt+1, 2, 3 or 4 selects that zoom level. Ctrl+Alt+0 toggles 1x View / Return. Ctrl+Alt+T toggles tracking. "
            L"Ctrl+Alt+S opens Visual Settings. Ctrl+Alt+H opens Help / Ask Visual. Ctrl+Alt+Q exits Visual."};
    case HelpTopic::SettingsPersistence:
        return {true, L"Settings",
            L"Visual saves your zoom, tracking, highlights, View Locator, colour/contrast mode and screen-role choices in your local Visual settings. "
            L"Most settings apply immediately; screen-role changes apply the next time Visual starts."};
    case HelpTopic::Reference:
        return {true, L"Reference Screen",
            L"Reference is an optional screen that Visual leaves available for normal Windows content. Visual remembers the assignment but does not currently move or pin windows there for you."};
    case HelpTopic::ZoomLevel:
        return {true, L"Zoom Level",
            L"Visual supports 1x, 1.5x, 2x, 3x and 4x zoom. Choose a level in Visual Settings, or use Ctrl+Alt+1 through Ctrl+Alt+4 for the whole-number levels."};
    default:
        return {};
    }
}

[[nodiscard]] inline HelpAnswer help_answer_for_query(std::wstring_view query) {
    const auto q = normalize_help_query(query);
    if (q.empty()) return {};

    if (help_contains(q, L"freeze") || help_contains(q, L"hooked") ||
        (help_contains(q, L"keep") && help_contains(q, L"still"))) {
        return help_answer(HelpTopic::FreezeView);
    }
    if (help_contains(q, L"view locator") || help_contains(q, L"detail view rectangle") ||
        (help_contains(q, L"rectangle") && (help_contains(q, L"detail") || help_contains(q, L"context"))) ||
        (help_contains(q, L"frame") && help_contains(q, L"context"))) {
        return help_answer(HelpTopic::ViewLocator);
    }
    if (help_contains(q, L"context") || help_contains(q, L"detail") ||
        help_contains(q, L"screen role") || help_contains(q, L"which screen")) {
        return help_answer(HelpTopic::ScreenRoles);
    }
    if (help_contains(q, L"tracking") || help_contains(q, L"follow activity") ||
        help_contains(q, L"follow pointer") || help_contains(q, L"follow mouse") ||
        help_contains(q, L"caret") || help_contains(q, L"text cursor") ||
        help_contains(q, L"keyboard focus")) {
        return help_answer(HelpTopic::Tracking);
    }
    if (help_contains(q, L"1x") || help_contains(q, L"x1") ||
        help_contains(q, L"normal view") || help_contains(q, L"return") ||
        help_contains(q, L"previous zoom")) {
        return help_answer(HelpTopic::OneXReturn);
    }
    if (help_contains(q, L"contrast") || help_contains(q, L"invert") ||
        help_contains(q, L"colour") || help_contains(q, L"color") || help_contains(q, L"grayscale")) {
        return help_answer(HelpTopic::ColourContrast);
    }
    if (help_contains(q, L"shortcut") || help_contains(q, L"hotkey") || help_contains(q, L"keyboard command")) {
        return help_answer(HelpTopic::Shortcuts);
    }
    if (help_contains(q, L"reference")) return help_answer(HelpTopic::Reference);
    if (help_contains(q, L"setting") || help_contains(q, L"save") || help_contains(q, L"persist") ||
        help_contains(q, L"profile") || help_contains(q, L"config")) {
        return help_answer(HelpTopic::SettingsPersistence);
    }
    if (help_contains(q, L"zoom") || help_contains(q, L"magnification")) return help_answer(HelpTopic::ZoomLevel);

    return {};
}

[[nodiscard]] inline std::string build_assistant_context_json(
    const VisualSettings& settings,
    int monitor_count,
    bool single_monitor) {
    const char* visual_mode = "normal";
    switch (settings.visual_mode) {
    case VisualMode::HighContrast: visual_mode = "increase_contrast"; break;
    case VisualMode::Inverted: visual_mode = "inverted_colours"; break;
    case VisualMode::Grayscale: visual_mode = "grayscale"; break;
    default: break;
    }

    std::ostringstream out;
    out.setf(std::ios::fixed);
    out.precision(1);
    out << "{\"schema_version\":\"1\""
        << ",\"zoom\":" << sanitize_zoom(settings.zoom)
        << ",\"tracking_enabled\":" << (settings.tracking_enabled ? "true" : "false")
        << ",\"follow_pointer\":" << (settings.follow_pointer ? "true" : "false")
        << ",\"follow_text_cursor\":" << (settings.follow_caret ? "true" : "false")
        << ",\"follow_keyboard_focus\":" << (settings.follow_focus ? "true" : "false")
        << ",\"pointer_locator\":" << (settings.show_pointer_locator ? "true" : "false")
        << ",\"text_cursor_highlight\":" << (settings.show_caret_locator ? "true" : "false")
        << ",\"focus_highlight\":" << (settings.show_focus_locator ? "true" : "false")
        << ",\"view_locator\":" << (settings.show_context_indicator ? "true" : "false")
        << ",\"visual_mode\":\"" << visual_mode << "\""
        << ",\"monitor_count\":" << std::max(0, monitor_count)
        << ",\"single_monitor\":" << (single_monitor ? "true" : "false")
        << ",\"context_assigned\":" << (!settings.context_monitor_device.empty() ? "true" : "false")
        << ",\"detail_assigned\":" << (!settings.detail_monitor_device.empty() ? "true" : "false")
        << ",\"reference_assigned\":" << (!settings.reference_monitor_device.empty() ? "true" : "false")
        << "}";
    return out.str();
}

} // namespace visual::core
