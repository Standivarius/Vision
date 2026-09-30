#pragma once

#ifndef NOMINMAX
#define NOMINMAX
#endif

#include "core/poi_evidence.h"
#include "tracking/uia_evidence_provider.h"
#include "tracking/win32_evidence_provider.h"

#include <cstdint>
#include <vector>

namespace visual::tracking {

struct EvidenceSnapshot {
    std::vector<core::PoiCandidate> candidates{};
    std::uint64_t sampled_qpc{};
    std::uint64_t pointer_movement_qpc{};
    std::uint64_t uia_sampled_qpc{};
    bool uia_current_caret_present{};
    bool uia_current_focus_present{};
};

class EvidenceSampler {
public:
    [[nodiscard]] EvidenceSnapshot sample(
        const core::ScreenRect& source,
        std::uint64_t now_qpc) noexcept {

        EvidenceSnapshot snapshot{};
        snapshot.sampled_qpc = now_qpc;
        snapshot.candidates = win32_.sample(source, now_qpc);
        snapshot.pointer_movement_qpc = win32_.last_pointer_movement_qpc();

        const auto uia = uia_.diagnostic_snapshot();
        snapshot.uia_sampled_qpc = uia.sampled_qpc;
        snapshot.uia_current_caret_present = uia.current_caret_present;
        snapshot.uia_current_focus_present = uia.current_focus_present;

        for (const auto& candidate : uia.candidates) {
            if (intersects_source(candidate.screen_rect, source)) {
                snapshot.candidates.push_back(candidate);
            }
        }
        return snapshot;
    }

private:
    [[nodiscard]] static bool intersects_source(
        const core::ScreenRect& rect,
        const core::ScreenRect& source) noexcept {

        return rect.valid() && source.valid()
            && rect.right > source.left && rect.left < source.right
            && rect.bottom > source.top && rect.top < source.bottom;
    }

    Win32EvidenceProvider win32_{};
    UiaEvidenceProvider uia_{};
};

} // namespace visual::tracking
