#pragma once

#include "locator_model.h"
#include "settings_model.h"
#include "view_controller.h"

#include <algorithm>
#include <cstdint>
#include <vector>

namespace visual::core {

struct ViewStepInput {
    ScreenRect source{};
    VisualSettings settings{};
    std::vector<PoiCandidate> evidence{};
    std::uint64_t now_qpc{};
    std::uint64_t qpc_frequency{};
    std::uint64_t pointer_intent_barrier_qpc{};
};

struct ViewStepOutput {
    ViewUpdate view{};
    LocatorTarget locator{};
};

class ViewUpdateStep {
public:
    [[nodiscard]] ViewStepOutput update(const ViewStepInput& input) noexcept {
        auto routed = input.evidence;
        routed.erase(std::remove_if(routed.begin(), routed.end(), [&](const PoiCandidate& candidate) {
            return !should_follow(candidate.kind, input.settings);
        }), routed.end());

        ViewStepOutput output{};
        output.view = controller_.update(
            input.source,
            input.settings.zoom,
            input.settings.tracking_enabled,
            routed,
            input.now_qpc,
            input.qpc_frequency,
            input.pointer_intent_barrier_qpc);

        // Visibility is independent of follow eligibility: an in-viewport cue may
        // remain visible without granting that evidence authority to move the view.
        output.locator = select_locator_target(
            input.evidence, output.view.viewport, input.settings, input.now_qpc, input.qpc_frequency, poi_policy_);
        return output;
    }

    void set_viewport_config(const ViewportConfig& config) noexcept {
        controller_.set_viewport_config(config);
    }

    void set_poi_policy(const PoiSelectionPolicy& policy) noexcept {
        poi_policy_ = policy;
        controller_.set_poi_policy(policy);
    }

private:
    PoiSelectionPolicy poi_policy_{};
    ViewController controller_{};
};

} // namespace visual::core
