#pragma once

#include <algorithm>
#include <cmath>
#include <string_view>

namespace visual::viewport {

struct Rect {
    double left{};
    double top{};
    double right{};
    double bottom{};

    [[nodiscard]] double width() const noexcept { return right - left; }
    [[nodiscard]] double height() const noexcept { return bottom - top; }
    [[nodiscard]] bool valid() const noexcept {
        return std::isfinite(left) && std::isfinite(top) && std::isfinite(right) && std::isfinite(bottom)
            && right > left && bottom > top;
    }
    [[nodiscard]] double center_x() const noexcept { return (left + right) * 0.5; }
    [[nodiscard]] double center_y() const noexcept { return (top + bottom) * 0.5; }
};

enum class Action {
    Invalid,
    Hold,
    Pan,
    Jump,
};

enum class Reason {
    InvalidGeometry,
    TrackingDisabled,
    PoiAlreadyComfortable,
    PoiOutsideComfortArea,
};

struct Config {
    double margin_ratio_x{0.20};
    double margin_ratio_y{0.20};
    double jump_threshold_viewport_fraction{0.75};
};

struct Decision {
    Action action{Action::Invalid};
    Reason reason{Reason::InvalidGeometry};
    Rect target_viewport{};
    double requested_dx{};
    double requested_dy{};
    double applied_dx{};
    double applied_dy{};
};

[[nodiscard]] inline std::string_view action_name(Action a) noexcept {
    switch (a) {
    case Action::Invalid: return "invalid";
    case Action::Hold: return "hold";
    case Action::Pan: return "pan";
    case Action::Jump: return "jump";
    }
    return "invalid";
}

[[nodiscard]] inline Rect translate(Rect r, double dx, double dy) noexcept {
    return {r.left + dx, r.top + dy, r.right + dx, r.bottom + dy};
}

[[nodiscard]] inline bool contains(const Rect& outer, const Rect& inner) noexcept {
    return outer.valid() && inner.valid()
        && inner.left >= outer.left && inner.right <= outer.right
        && inner.top >= outer.top && inner.bottom <= outer.bottom;
}

[[nodiscard]] inline Rect inset(const Rect& r, double x, double y) noexcept {
    return {r.left + x, r.top + y, r.right - x, r.bottom - y};
}

[[nodiscard]] inline Rect clamp_viewport_to_source(Rect viewport, const Rect& source) noexcept {
    if (!viewport.valid() || !source.valid()) return {};
    const double vw = viewport.width();
    const double vh = viewport.height();
    if (vw > source.width() || vh > source.height()) return {};

    double left = viewport.left;
    double top = viewport.top;
    if (left < source.left) left = source.left;
    if (top < source.top) top = source.top;
    if (left + vw > source.right) left = source.right - vw;
    if (top + vh > source.bottom) top = source.bottom - vh;
    return {left, top, left + vw, top + vh};
}

[[nodiscard]] inline bool config_valid(const Config& c) noexcept {
    return std::isfinite(c.margin_ratio_x) && std::isfinite(c.margin_ratio_y)
        && std::isfinite(c.jump_threshold_viewport_fraction)
        && c.margin_ratio_x >= 0.0 && c.margin_ratio_x < 0.5
        && c.margin_ratio_y >= 0.0 && c.margin_ratio_y < 0.5
        && c.jump_threshold_viewport_fraction >= 0.0;
}

[[nodiscard]] inline Decision decide(
    const Rect& source,
    const Rect& current_viewport,
    const Rect& poi,
    bool tracking_enabled = true,
    const Config& config = {}) noexcept {

    Decision d{};
    d.target_viewport = current_viewport;

    if (!source.valid() || !current_viewport.valid() || !poi.valid() || !config_valid(config)
        || current_viewport.width() > source.width() || current_viewport.height() > source.height()) {
        d.action = Action::Invalid;
        d.reason = Reason::InvalidGeometry;
        return d;
    }

    const Rect current = clamp_viewport_to_source(current_viewport, source);
    if (!current.valid()) {
        d.action = Action::Invalid;
        d.reason = Reason::InvalidGeometry;
        return d;
    }
    d.target_viewport = current;

    if (!tracking_enabled) {
        d.action = Action::Hold;
        d.reason = Reason::TrackingDisabled;
        return d;
    }

    const double margin_x = current.width() * config.margin_ratio_x;
    const double margin_y = current.height() * config.margin_ratio_y;
    const Rect comfort = inset(current, margin_x, margin_y);
    if (!comfort.valid()) {
        d.action = Action::Invalid;
        d.reason = Reason::InvalidGeometry;
        return d;
    }

    if (contains(comfort, poi)) {
        d.action = Action::Hold;
        d.reason = Reason::PoiAlreadyComfortable;
        return d;
    }

    double dx = 0.0;
    double dy = 0.0;

    if (poi.width() > comfort.width()) {
        dx = poi.center_x() - current.center_x();
    } else if (poi.left < comfort.left) {
        dx = poi.left - comfort.left;
    } else if (poi.right > comfort.right) {
        dx = poi.right - comfort.right;
    }

    if (poi.height() > comfort.height()) {
        dy = poi.center_y() - current.center_y();
    } else if (poi.top < comfort.top) {
        dy = poi.top - comfort.top;
    } else if (poi.bottom > comfort.bottom) {
        dy = poi.bottom - comfort.bottom;
    }

    d.requested_dx = dx;
    d.requested_dy = dy;

    Rect requested = translate(current, dx, dy);
    const Rect clamped = clamp_viewport_to_source(requested, source);
    if (!clamped.valid()) {
        d.action = Action::Invalid;
        d.reason = Reason::InvalidGeometry;
        return d;
    }

    d.target_viewport = clamped;
    d.applied_dx = clamped.left - current.left;
    d.applied_dy = clamped.top - current.top;
    d.reason = Reason::PoiOutsideComfortArea;

    const double frac_x = current.width() > 0.0 ? std::abs(d.applied_dx) / current.width() : 0.0;
    const double frac_y = current.height() > 0.0 ? std::abs(d.applied_dy) / current.height() : 0.0;
    const double frac = std::max(frac_x, frac_y);
    d.action = frac >= config.jump_threshold_viewport_fraction ? Action::Jump : Action::Pan;
    return d;
}

} // namespace visual::viewport
