#pragma once

#include "viewport_policy.h"

#include <algorithm>
#include <cstdint>
#include <string>
#include <vector>

namespace visual::core {

struct MonitorIdentityHints {
    std::wstring gdi_device_name{};
    std::wstring pnp_instance_id{};
    std::wstring monitor_device_path{};
    std::wstring manufacturer{};
    std::wstring product_code{};
    std::wstring serial{};
};

struct MonitorSnapshot {
    ScreenRect bounds{};
    bool primary{};
    std::uint32_t dpi_x{96};
    std::uint32_t dpi_y{96};
    std::uint32_t orientation{};
    MonitorIdentityHints identity{};
};

struct TopologySnapshot {
    std::uint64_t generation{1};
    std::vector<MonitorSnapshot> monitors{};
};

[[nodiscard]] inline bool same_runtime_topology(
    const TopologySnapshot& a,
    const TopologySnapshot& b) noexcept {
    if (a.monitors.size() != b.monitors.size()) return false;
    for (std::size_t i = 0; i < a.monitors.size(); ++i) {
        const auto& x = a.monitors[i];
        const auto& y = b.monitors[i];
        if (x.identity.gdi_device_name != y.identity.gdi_device_name
            || x.bounds.left != y.bounds.left || x.bounds.top != y.bounds.top
            || x.bounds.right != y.bounds.right || x.bounds.bottom != y.bounds.bottom
            || x.primary != y.primary || x.dpi_x != y.dpi_x || x.dpi_y != y.dpi_y
            || x.orientation != y.orientation) {
            return false;
        }
    }
    return true;
}

class MonitorRegistry {
public:
    [[nodiscard]] const TopologySnapshot& snapshot() const noexcept { return current_; }

    [[nodiscard]] bool update(std::vector<MonitorSnapshot> monitors) {
        std::sort(monitors.begin(), monitors.end(), [](const auto& a, const auto& b) {
            return a.identity.gdi_device_name < b.identity.gdi_device_name;
        });
        TopologySnapshot candidate{current_.generation, std::move(monitors)};
        if (same_runtime_topology(current_, candidate)) return false;
        candidate.generation = current_.generation + 1;
        current_ = std::move(candidate);
        return true;
    }

private:
    TopologySnapshot current_{};
};

} // namespace visual::core
