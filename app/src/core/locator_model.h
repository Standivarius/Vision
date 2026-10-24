#pragma once

#include "poi_evidence.h"
#include "settings_model.h"

#include <algorithm>
#include <vector>

namespace visual::core {

struct LocatorTarget {
    bool visible{};
    PoiKind kind{PoiKind::Focus};
    double left{};
    double top{};
    double right{};
    double bottom{};
};

[[nodiscard]] inline LocatorTarget make_locator_target(
    const PoiCandidate& poi,
    const ScreenRect& viewport) noexcept {

    LocatorTarget target{};
    target.kind = poi.kind;
    if (!poi.usable() || !viewport.valid()) return target;

    const auto& r = poi.screen_rect;
    const bool intersects = r.right > viewport.left && r.left < viewport.right
        && r.bottom > viewport.top && r.top < viewport.bottom;
    if (!intersects) return target;

    target.left = std::clamp((r.left - viewport.left) / viewport.width(), 0.0, 1.0);
    target.top = std::clamp((r.top - viewport.top) / viewport.height(), 0.0, 1.0);
    target.right = std::clamp((r.right - viewport.left) / viewport.width(), 0.0, 1.0);
    target.bottom = std::clamp((r.bottom - viewport.top) / viewport.height(), 0.0, 1.0);
    target.visible = target.right >= target.left && target.bottom >= target.top;
    return target;
}


[[nodiscard]] inline LocatorTarget select_locator_target(
    const std::vector<PoiCandidate>& evidence,
    const ScreenRect& viewport,
    const VisualSettings& settings,
    std::uint64_t now_qpc,
    std::uint64_t qpc_frequency,
    const PoiSelectionPolicy& freshness_policy = {}) noexcept {

    const PoiCandidate* best = nullptr;
    for (const auto& candidate : evidence) {
        if (!is_fresh(candidate, now_qpc, qpc_frequency, freshness_policy)
            || !should_show_locator(candidate.kind, settings)) continue;
        const auto target = make_locator_target(candidate, viewport);
        if (!target.visible) continue;
        if (!best || candidate.timestamp_qpc > best->timestamp_qpc
            || (candidate.timestamp_qpc == best->timestamp_qpc
                && static_cast<int>(candidate.confidence) > static_cast<int>(best->confidence))) {
            best = &candidate;
        }
    }
    return best ? make_locator_target(*best, viewport) : LocatorTarget{};
}

} // namespace visual::core
