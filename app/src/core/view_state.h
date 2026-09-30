#pragma once

#include "settings_model.h"
#include "viewport_policy.h"

#include <cstdint>
#include <string>

namespace visual::core {

struct ViewId {
    std::uint64_t value{};

    [[nodiscard]] constexpr bool valid() const noexcept { return value != 0; }
    friend constexpr bool operator==(ViewId, ViewId) noexcept = default;
};

inline constexpr ViewId kCurrentDetailViewId{1};

struct ViewBinding {
    std::wstring source_monitor_device{};
    std::wstring destination_monitor_device{};
};

struct ViewState {
    ViewId id{kCurrentDetailViewId};
    double zoom{2.0};
    bool tracking_enabled{true};
    bool follow_pointer{true};
    bool follow_caret{true};
    bool follow_focus{true};
    bool show_pointer_locator{true};
    bool show_caret_locator{true};
    bool show_focus_locator{true};
    VisualMode visual_mode{VisualMode::Normal};
    ViewBinding binding{};
    ScreenRect viewport{};
    bool have_saved_magnified_view{};
    double saved_magnified_zoom{};
    ScreenRect saved_magnified_viewport{};
};

[[nodiscard]] inline ViewState detail_view_from_legacy_settings(const VisualSettings& settings) {
    ViewState view{};
    view.id = kCurrentDetailViewId;
    view.zoom = sanitize_zoom(settings.zoom);
    view.tracking_enabled = settings.tracking_enabled;
    view.follow_pointer = settings.follow_pointer;
    view.follow_caret = settings.follow_caret;
    view.follow_focus = settings.follow_focus;
    view.show_pointer_locator = settings.show_pointer_locator;
    view.show_caret_locator = settings.show_caret_locator;
    view.show_focus_locator = settings.show_focus_locator;
    view.visual_mode = settings.visual_mode;
    view.binding.source_monitor_device = settings.context_monitor_device;
    view.binding.destination_monitor_device = settings.detail_monitor_device;
    return view;
}

[[nodiscard]] inline VisualSettings apply_detail_view_to_legacy_settings(
    const ViewState& view,
    VisualSettings settings) {

    settings.zoom = sanitize_zoom(view.zoom);
    settings.tracking_enabled = view.tracking_enabled;
    settings.follow_pointer = view.follow_pointer;
    settings.follow_caret = view.follow_caret;
    settings.follow_focus = view.follow_focus;
    settings.show_pointer_locator = view.show_pointer_locator;
    settings.show_caret_locator = view.show_caret_locator;
    settings.show_focus_locator = view.show_focus_locator;
    settings.visual_mode = view.visual_mode;
    settings.context_monitor_device = view.binding.source_monitor_device;
    settings.detail_monitor_device = view.binding.destination_monitor_device;
    return settings;
}

[[nodiscard]] inline bool view_state_valid(const ViewState& view) noexcept {
    return view.id.valid()
        && supported_zoom(view.zoom)
        && (view.saved_magnified_zoom == 0.0 || supported_zoom(view.saved_magnified_zoom));
}

} // namespace visual::core
