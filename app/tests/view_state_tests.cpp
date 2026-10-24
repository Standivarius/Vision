#include "core/view_state.h"

#include <iostream>
#include <string>
#include <vector>

using namespace visual::core;

struct Failure { std::string name; std::string message; };

static void require(bool ok, const std::string& name, const std::string& message, std::vector<Failure>& failures) {
    if (!ok) failures.push_back({name, message});
}

static void test_legacy_mapping(std::vector<Failure>& failures) {
    const std::string name = "legacy_mapping";
    VisualSettings settings{};
    settings.zoom = 3.0;
    settings.tracking_enabled = false;
    settings.follow_pointer = false;
    settings.follow_caret = true;
    settings.follow_focus = false;
    settings.show_pointer_locator = false;
    settings.show_caret_locator = true;
    settings.show_focus_locator = false;
    settings.visual_mode = VisualMode::Inverted;
    settings.context_monitor_device = L"\\\\.\\DISPLAY1";
    settings.detail_monitor_device = L"\\\\.\\DISPLAY2";
    settings.reference_monitor_device = L"\\\\.\\DISPLAY3";
    settings.show_context_indicator = false;
    settings.shade_context_indicator = false;

    const auto view = detail_view_from_legacy_settings(settings);
    require(view.id == kCurrentDetailViewId, name, "wrong current Detail ViewId", failures);
    require(view.zoom == 3.0, name, "zoom not mapped", failures);
    require(!view.tracking_enabled, name, "tracking not mapped", failures);
    require(!view.follow_pointer && view.follow_caret && !view.follow_focus, name, "follow policy not mapped", failures);
    require(!view.show_pointer_locator && view.show_caret_locator && !view.show_focus_locator, name, "locator policy not mapped", failures);
    require(view.visual_mode == VisualMode::Inverted, name, "visual mode not mapped", failures);
    require(view.binding.source_monitor_device == settings.context_monitor_device, name, "source binding not mapped", failures);
    require(view.binding.destination_monitor_device == settings.detail_monitor_device, name, "destination binding not mapped", failures);
    require(view_state_valid(view), name, "mapped view should be valid", failures);

    const auto roundtrip = apply_detail_view_to_legacy_settings(view, settings);
    require(roundtrip.zoom == settings.zoom, name, "roundtrip changed zoom", failures);
    require(roundtrip.context_monitor_device == settings.context_monitor_device, name, "roundtrip changed source role", failures);
    require(roundtrip.detail_monitor_device == settings.detail_monitor_device, name, "roundtrip changed destination role", failures);
    require(roundtrip.reference_monitor_device == settings.reference_monitor_device, name, "roundtrip changed reference role", failures);
    require(roundtrip.show_context_indicator == settings.show_context_indicator, name, "roundtrip changed workspace indicator setting", failures);
    require(roundtrip.shade_context_indicator == settings.shade_context_indicator, name, "roundtrip changed workspace shade setting", failures);
}

static void test_view_changes_preserve_workspace_settings(std::vector<Failure>& failures) {
    const std::string name = "preserve_workspace";
    VisualSettings legacy{};
    legacy.reference_monitor_device = L"REFERENCE";
    legacy.show_context_indicator = false;
    legacy.shade_context_indicator = true;

    auto view = detail_view_from_legacy_settings(legacy);
    view.zoom = 4.0;
    view.follow_pointer = false;
    view.binding.destination_monitor_device = L"DETAIL-NEW";

    const auto merged = apply_detail_view_to_legacy_settings(view, legacy);
    require(merged.zoom == 4.0, name, "view zoom was not applied", failures);
    require(!merged.follow_pointer, name, "view follow state was not applied", failures);
    require(merged.detail_monitor_device == L"DETAIL-NEW", name, "view destination was not applied", failures);
    require(merged.reference_monitor_device == L"REFERENCE", name, "workspace reference role was overwritten", failures);
    require(!merged.show_context_indicator && merged.shade_context_indicator, name, "workspace context presentation was overwritten", failures);
}

static void test_invalid_view_identity(std::vector<Failure>& failures) {
    const std::string name = "invalid_identity";
    ViewState view{};
    view.id = {};
    require(!view_state_valid(view), name, "zero ViewId should be invalid", failures);
}

int main() {
    std::vector<Failure> failures;
    test_legacy_mapping(failures);
    test_view_changes_preserve_workspace_settings(failures);
    test_invalid_view_identity(failures);

    if (!failures.empty()) {
        std::cerr << "view_state_tests FAILED: " << failures.size() << " failure(s)\n";
        for (const auto& f : failures) std::cerr << "  " << f.name << ": " << f.message << "\n";
        return 1;
    }

    std::cout << "view_state_tests PASSED\n";
    return 0;
}
