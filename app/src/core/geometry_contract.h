#pragma once

#include "poi_evidence.h"

#include <algorithm>
#include <cmath>

namespace visual::core {

struct DestinationSize {
    double width{};
    double height{};

    [[nodiscard]] bool valid() const noexcept {
        return std::isfinite(width) && std::isfinite(height) && width > 0.0 && height > 0.0;
    }
};

struct RenderGeometry {
    ScreenRect source_viewport{};
    ScreenRect destination_content{};
    double zoom{};
    bool letterboxed{};

    [[nodiscard]] bool valid() const noexcept {
        return source_viewport.valid() && destination_content.valid()
            && std::isfinite(zoom) && zoom > 0.0;
    }
};

[[nodiscard]] inline RenderGeometry compute_magnification_geometry(
    const ScreenRect& source,
    const DestinationSize& destination,
    double zoom,
    double center_x,
    double center_y) noexcept {

    RenderGeometry result{};
    if (!source.valid() || !destination.valid() || !std::isfinite(zoom) || zoom <= 0.0
        || !std::isfinite(center_x) || !std::isfinite(center_y)) {
        return result;
    }

    const double requested_width = destination.width / zoom;
    const double requested_height = destination.height / zoom;
    if (!(requested_width > 0.0) || !(requested_height > 0.0)) return result;

    const double fit = std::min({
        1.0,
        source.width() / requested_width,
        source.height() / requested_height,
    });
    if (!(fit > 0.0) || !std::isfinite(fit)) return result;

    const double viewport_width = requested_width * fit;
    const double viewport_height = requested_height * fit;

    double left = center_x - viewport_width * 0.5;
    double top = center_y - viewport_height * 0.5;
    left = std::clamp(left, source.left, source.right - viewport_width);
    top = std::clamp(top, source.top, source.bottom - viewport_height);

    result.source_viewport = {
        left,
        top,
        left + viewport_width,
        top + viewport_height,
    };

    const double content_width = viewport_width * zoom;
    const double content_height = viewport_height * zoom;
    const double content_left = (destination.width - content_width) * 0.5;
    const double content_top = (destination.height - content_height) * 0.5;
    result.destination_content = {
        content_left,
        content_top,
        content_left + content_width,
        content_top + content_height,
    };
    result.zoom = zoom;
    result.letterboxed = fit < 1.0 - 1e-9;
    return result;
}

[[nodiscard]] inline RenderGeometry compute_magnification_geometry(
    const ScreenRect& source,
    const DestinationSize& destination,
    double zoom) noexcept {
    return compute_magnification_geometry(
        source,
        destination,
        zoom,
        (source.left + source.right) * 0.5,
        (source.top + source.bottom) * 0.5);
}

struct OverviewGeometry {
    ScreenRect source_viewport{};
    ScreenRect destination_content{};
    double scale{};
    [[nodiscard]] bool valid() const noexcept {
        return source_viewport.valid() && destination_content.valid()
            && std::isfinite(scale) && scale > 0.0;
    }
};

[[nodiscard]] inline OverviewGeometry compute_overview_geometry(
    const ScreenRect& source,
    const DestinationSize& destination) noexcept {

    OverviewGeometry result{};
    if (!source.valid() || !destination.valid()) return result;

    const double scale = std::min(
        destination.width / source.width(),
        destination.height / source.height());
    if (!(scale > 0.0) || !std::isfinite(scale)) return result;

    const double content_width = source.width() * scale;
    const double content_height = source.height() * scale;
    const double left = (destination.width - content_width) * 0.5;
    const double top = (destination.height - content_height) * 0.5;

    result.source_viewport = source;
    result.destination_content = {left, top, left + content_width, top + content_height};
    result.scale = scale;
    return result;
}

} // namespace visual::core
