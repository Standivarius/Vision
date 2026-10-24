#pragma once

#include <array>
#include <cstddef>
#include <string_view>

namespace visual::core {

enum class UiStringId : std::size_t {
    SettingsTitle,
    SettingsZoomLevel,
    SettingsZoom1x,
    SettingsZoom1_5x,
    SettingsZoom2x,
    SettingsZoom3x,
    SettingsZoom4x,
    SettingsTrackingGroup,
    SettingsEnableTracking,
    SettingsFollowPointer,
    SettingsFollowTextCursor,
    SettingsFollowKeyboardFocus,
    SettingsTrackingNote,
    SettingsHighlightsGroup,
    SettingsPointerLocator,
    SettingsTextCursorHighlight,
    SettingsFocusHighlight,
    SettingsContextGroup,
    SettingsShowViewLocator,
    SettingsShadeViewLocator,
    SettingsLocatorNote,
    SettingsColourContrast,
    SettingsAppearanceNormal,
    SettingsAppearanceContrast,
    SettingsAppearanceInverted,
    SettingsAppearanceGrayscale,
    SettingsScreenRolesGroup,
    SettingsContextLabel,
    SettingsDetailLabel,
    SettingsReferenceLabel,
    SettingsDisplayNote,
    SettingsDisplayNoteSingle,
    SettingsApply,
    SettingsDefaults,
    SettingsHelp,
    SettingsClose,
    SettingsReferenceNone,

    HelpTitle,
    HelpIntro,
    HelpAsk,
    HelpScreenRoles,
    HelpTracking,
    HelpViewLocator,
    HelpOneXReturn,
    HelpFreeze,
    HelpShortcuts,
    HelpColourContrast,
    HelpSettings,
    HelpCommonTitle,
    HelpDefaultBody,
    HelpStatusLocalOnline,
    HelpStatusLocalOnly,
    HelpClose,
    HelpAskPromptTitle,
    HelpAskPromptBody,
    HelpStatusLocal,
    HelpWorking,
    HelpWorkingBody,
    HelpWorkingStatus,

    Count
};

struct UiStringEntry {
    std::string_view key;
    std::wstring_view english;
};

inline constexpr std::array<UiStringEntry, static_cast<std::size_t>(UiStringId::Count)> kUiStrings{{
    {"settings.title", L"Vision Settings"},
    {"settings.zoom.label", L"Zoom Level"},
    {"settings.zoom.1x", L"1x - normal view"},
    {"settings.zoom.1_5x", L"1.5x"},
    {"settings.zoom.2x", L"2x"},
    {"settings.zoom.3x", L"3x"},
    {"settings.zoom.4x", L"4x"},
    {"settings.tracking.group", L"Tracking"},
    {"settings.tracking.enable", L"&Enable tracking"},
    {"settings.tracking.pointer", L"Follow &Pointer"},
    {"settings.tracking.text_cursor", L"Follow &Text Cursor"},
    {"settings.tracking.keyboard_focus", L"Follow Keyboard &Focus"},
    {"settings.tracking.note", L"Pointer follows deliberate mouse movement. Text Cursor follows typing. Keyboard Focus follows controls."},
    {"settings.highlights.group", L"Highlights"},
    {"settings.highlights.pointer", L"Pointer Locator"},
    {"settings.highlights.text_cursor", L"Text Cursor Highlight"},
    {"settings.highlights.focus", L"Focus Highlight"},
    {"settings.context.group", L"Context - 1x overview"},
    {"settings.context.show_locator", L"Show &View Locator"},
    {"settings.context.shade_locator", L"Lightly shade the View Locator area"},
    {"settings.context.note", L"The View Locator shows which area of Context is currently enlarged on Detail."},
    {"settings.appearance.label", L"Colour & Contrast"},
    {"settings.appearance.normal", L"Normal"},
    {"settings.appearance.contrast", L"Increase Contrast"},
    {"settings.appearance.inverted", L"Inverted colours"},
    {"settings.appearance.grayscale", L"Grayscale"},
    {"settings.screen_roles.group", L"Screen roles"},
    {"settings.screen_roles.context", L"Context - 1x overview"},
    {"settings.screen_roles.detail", L"Detail - magnified view"},
    {"settings.screen_roles.reference", L"Reference - optional"},
    {"settings.screen_roles.note", L"Screen-role changes are saved and take effect the next time Vision starts. The Reference screen is left unchanged for normal Windows use."},
    {"settings.screen_roles.single", L"Screen roles require at least two active screens. Vision is currently using its single-screen fallback."},
    {"settings.apply", L"&Apply"},
    {"settings.restore_defaults", L"Restore &defaults"},
    {"settings.help", L"&Help / Ask Vision"},
    {"settings.close", L"&Close"},
    {"settings.reference.none", L"None / leave unassigned"},

    {"help.title", L"Vision Help / Ask Vision"},
    {"help.intro", L"Ask in your own words. Vision answers known questions locally and only uses an online assistant when a configured endpoint is needed."},
    {"help.ask", L"&Ask"},
    {"help.topic.screen_roles", L"Screen Roles"},
    {"help.topic.tracking", L"Tracking"},
    {"help.topic.view_locator", L"View Locator"},
    {"help.topic.one_x_return", L"1x View / Return"},
    {"help.topic.freeze", L"Freeze / Hooked Areas"},
    {"help.topic.shortcuts", L"Shortcuts"},
    {"help.topic.colour_contrast", L"Colour & Contrast"},
    {"help.topic.settings", L"Settings"},
    {"help.common_title", L"Common Vision help"},
    {"help.default_body", L"Choose a topic above, or type a question.\r\n\r\nExamples: Where is Freeze View? What does the View Locator show? Why isn't Vision following my text cursor?"},
    {"help.status.local_online", L"Local help + configured online fallback"},
    {"help.status.local_only", L"Local Vision help - online fallback not configured"},
    {"help.close", L"&Close"},
    {"help.ask_prompt.title", L"Ask Vision"},
    {"help.ask_prompt.body", L"Type a short question, or choose one of the common topics."},
    {"help.status.local", L"Local Vision help"},
    {"help.working", L"Working..."},
    {"help.working.body", L"Ask Vision is checking Vision help and the online product knowledge.\r\n\r\nThis can take a few seconds."},
    {"help.working.status", L"Working - waiting for Ask Vision..."},
}};

[[nodiscard]] constexpr const UiStringEntry& ui_string_entry(UiStringId id) noexcept {
    return kUiStrings[static_cast<std::size_t>(id)];
}

[[nodiscard]] constexpr std::wstring_view ui_string(UiStringId id) noexcept {
    return ui_string_entry(id).english;
}

[[nodiscard]] constexpr std::string_view ui_string_key(UiStringId id) noexcept {
    return ui_string_entry(id).key;
}

} // namespace visual::core
