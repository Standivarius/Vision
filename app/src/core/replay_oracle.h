#pragma once

#include "locator_model.h"
#include "view_update_step.h"

#include <cstdint>
#include <optional>
#include <vector>

namespace visual::core {

struct ReplayFrameInput {
    ScreenRect source{};
    double zoom{1.0};
    bool tracking_enabled{true};
    bool locator_enabled{true};
    std::vector<PoiCandidate> candidates{};
    std::uint64_t now_qpc{};
    std::uint64_t qpc_frequency{};
};

struct ReplayFrameOutput {
    ViewUpdate view{};
    LocatorTarget locator{};
};

class ReplayOracle {
public:
    [[nodiscard]] ReplayFrameOutput step(const ReplayFrameInput& input) noexcept {
        VisualSettings settings{};
        settings.zoom = input.zoom;
        settings.tracking_enabled = input.tracking_enabled;
        settings.show_pointer_locator = input.locator_enabled;
        settings.show_caret_locator = input.locator_enabled;
        settings.show_focus_locator = input.locator_enabled;
        const auto stepped = step_.update({
            input.source,
            settings,
            input.candidates,
            input.now_qpc,
            input.qpc_frequency});
        return {stepped.view, stepped.locator};
    }

    void set_viewport_config(const ViewportConfig& config) noexcept {
        step_.set_viewport_config(config);
    }

    void set_poi_policy(const PoiSelectionPolicy& policy) noexcept {
        step_.set_poi_policy(policy);
    }

private:
    ViewUpdateStep step_{};
};

} // namespace visual::core
