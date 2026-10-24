#pragma once

#include <algorithm>
#include <cmath>
#include <optional>

namespace visual::coordinates {

struct ScreenPoint {
    long x{};
    long y{};
};

struct MonitorRect {
    long left{};
    long top{};
    long right{};
    long bottom{};

    [[nodiscard]] long width() const noexcept { return right - left; }
    [[nodiscard]] long height() const noexcept { return bottom - top; }
    [[nodiscard]] bool valid() const noexcept { return width() > 0 && height() > 0; }

    // Win32 monitor rectangles use half-open bounds: [left,right) x [top,bottom).
    [[nodiscard]] bool contains(ScreenPoint p) const noexcept {
        return valid() && p.x >= left && p.x < right && p.y >= top && p.y < bottom;
    }
};

struct MonitorLocalPoint {
    long x{};
    long y{};
};

struct NormalizedPoint {
    double x{};
    double y{};
};

[[nodiscard]] inline std::optional<MonitorLocalPoint> to_monitor_local(
    ScreenPoint screen,
    const MonitorRect& monitor) noexcept {
    if (!monitor.contains(screen)) return std::nullopt;
    return MonitorLocalPoint{screen.x - monitor.left, screen.y - monitor.top};
}

[[nodiscard]] inline std::optional<NormalizedPoint> to_normalized(
    ScreenPoint screen,
    const MonitorRect& monitor) noexcept {
    const auto local = to_monitor_local(screen, monitor);
    if (!local) return std::nullopt;

    const long w = monitor.width();
    const long h = monitor.height();
    const double nx = w > 1 ? static_cast<double>(local->x) / static_cast<double>(w - 1) : 0.0;
    const double ny = h > 1 ? static_cast<double>(local->y) / static_cast<double>(h - 1) : 0.0;
    return NormalizedPoint{nx, ny};
}

[[nodiscard]] inline std::optional<ScreenPoint> from_normalized(
    NormalizedPoint normalized,
    const MonitorRect& monitor) noexcept {
    if (!monitor.valid()) return std::nullopt;
    if (!std::isfinite(normalized.x) || !std::isfinite(normalized.y)) return std::nullopt;
    if (normalized.x < 0.0 || normalized.x > 1.0 || normalized.y < 0.0 || normalized.y > 1.0) return std::nullopt;

    const long w = monitor.width();
    const long h = monitor.height();
    const long local_x = w > 1 ? static_cast<long>(std::llround(normalized.x * static_cast<double>(w - 1))) : 0;
    const long local_y = h > 1 ? static_cast<long>(std::llround(normalized.y * static_cast<double>(h - 1))) : 0;
    return ScreenPoint{monitor.left + local_x, monitor.top + local_y};
}

} // namespace visual::coordinates
