#pragma once
#include <cstdint>

namespace visual::core {

enum class TopologyReconcileState : std::uint8_t { Stable, Debouncing, RebuildReady };

class TopologyReconciler {
public:
    explicit TopologyReconciler(std::uint64_t debounce_ms = 500) noexcept : debounce_ms_(debounce_ms) {}

    void signal_change(std::uint64_t now_ms) noexcept {
        last_change_ms_ = now_ms;
        state_ = TopologyReconcileState::Debouncing;
    }

    [[nodiscard]] TopologyReconcileState poll(std::uint64_t now_ms) noexcept {
        if (state_ == TopologyReconcileState::Debouncing
            && now_ms >= last_change_ms_
            && now_ms - last_change_ms_ >= debounce_ms_) {
            state_ = TopologyReconcileState::RebuildReady;
        }
        return state_;
    }

    void rebuild_completed(std::uint64_t topology_generation) noexcept {
        active_generation_ = topology_generation == 0 ? 1 : topology_generation;
        state_ = TopologyReconcileState::Stable;
    }

    [[nodiscard]] bool accepts_generation(std::uint64_t generation) const noexcept {
        return state_ == TopologyReconcileState::Stable && generation == active_generation_;
    }
    [[nodiscard]] std::uint64_t active_generation() const noexcept { return active_generation_; }

private:
    std::uint64_t debounce_ms_{500};
    std::uint64_t last_change_ms_{};
    std::uint64_t active_generation_{1};
    TopologyReconcileState state_{TopologyReconcileState::Stable};
};

} // namespace visual::core
