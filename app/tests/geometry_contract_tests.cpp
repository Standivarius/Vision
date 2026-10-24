#include "core/geometry_contract.h"

#include <cmath>
#include <iostream>
#include <string>
#include <vector>

using namespace visual::core;

struct Failure { std::string name; std::string message; };

static void require(bool ok, const std::string& name, const std::string& message, std::vector<Failure>& failures) {
    if (!ok) failures.push_back({name, message});
}

static bool near(double a, double b, double eps = 1e-9) {
    return std::abs(a - b) <= eps;
}

static void require_geometry(
    const RenderGeometry& g,
    const std::string& name,
    double viewport_w,
    double viewport_h,
    double content_w,
    double content_h,
    bool letterboxed,
    std::vector<Failure>& failures) {

    require(g.valid(), name, "geometry invalid", failures);
    if (!g.valid()) return;
    require(near(g.source_viewport.width(), viewport_w), name, "unexpected viewport width", failures);
    require(near(g.source_viewport.height(), viewport_h), name, "unexpected viewport height", failures);
    require(near(g.destination_content.width(), content_w), name, "unexpected content width", failures);
    require(near(g.destination_content.height(), content_h), name, "unexpected content height", failures);
    require(g.letterboxed == letterboxed, name, "unexpected letterbox state", failures);
    require(near(g.destination_content.width() / g.source_viewport.width(), g.zoom),
        name, "horizontal scale does not equal zoom", failures);
    require(near(g.destination_content.height() / g.source_viewport.height(), g.zoom),
        name, "vertical scale does not equal zoom", failures);
}

static void test_matched_1920x1080(std::vector<Failure>& failures) {
    const ScreenRect source{0, 0, 1920, 1080};
    const DestinationSize destination{1920, 1080};

    require_geometry(compute_magnification_geometry(source, destination, 1.0),
        "matched_1x", 1920, 1080, 1920, 1080, false, failures);
    require_geometry(compute_magnification_geometry(source, destination, 2.0),
        "matched_2x", 960, 540, 1920, 1080, false, failures);
    require_geometry(compute_magnification_geometry(source, destination, 4.0),
        "matched_4x", 480, 270, 1920, 1080, false, failures);
}

static void test_larger_source_smaller_destination(std::vector<Failure>& failures) {
    const ScreenRect source{0, 0, 1920, 1080};
    const DestinationSize destination{1280, 720};
    require_geometry(compute_magnification_geometry(source, destination, 1.0),
        "large_to_small_1x", 1280, 720, 1280, 720, false, failures);
}

static void test_smaller_source_larger_destination(std::vector<Failure>& failures) {
    const ScreenRect source{0, 0, 1280, 720};
    const DestinationSize destination{1920, 1080};
    const auto g = compute_magnification_geometry(source, destination, 1.0);
    require_geometry(g, "small_to_large_1x", 1280, 720, 1280, 720, true, failures);
    require(near(g.destination_content.left, 320.0), "small_to_large_1x", "wrong horizontal letterbox", failures);
    require(near(g.destination_content.top, 180.0), "small_to_large_1x", "wrong vertical letterbox", failures);
}

static void test_portrait_destination(std::vector<Failure>& failures) {
    const ScreenRect source{0, 0, 1920, 1080};
    const DestinationSize portrait{1080, 1920};

    const auto one = compute_magnification_geometry(source, portrait, 1.0);
    require_geometry(one, "portrait_1x", 607.5, 1080, 607.5, 1080, true, failures);

    const auto two = compute_magnification_geometry(source, portrait, 2.0);
    require_geometry(two, "portrait_2x", 540, 960, 1080, 1920, false, failures);
}

static void test_partial_destination(std::vector<Failure>& failures) {
    const ScreenRect source{0, 0, 1920, 1080};
    require_geometry(compute_magnification_geometry(source, {800, 600}, 2.0),
        "partial_destination", 400, 300, 800, 600, false, failures);
}

static void test_negative_origin_and_edge_clamp(std::vector<Failure>& failures) {
    const ScreenRect source{-1920, 0, 0, 1080};
    const DestinationSize destination{1280, 720};

    const auto left_top = compute_magnification_geometry(source, destination, 2.0, -1919, 1);
    require(left_top.valid(), "negative_origin_left", "geometry invalid", failures);
    require(near(left_top.source_viewport.left, -1920.0), "negative_origin_left", "left edge was not clamped", failures);
    require(near(left_top.source_viewport.top, 0.0), "negative_origin_left", "top edge was not clamped", failures);

    const auto right_bottom = compute_magnification_geometry(source, destination, 2.0, -1, 1079);
    require(right_bottom.valid(), "negative_origin_right", "geometry invalid", failures);
    require(near(right_bottom.source_viewport.right, 0.0), "negative_origin_right", "right edge was not clamped", failures);
    require(near(right_bottom.source_viewport.bottom, 1080.0), "negative_origin_right", "bottom edge was not clamped", failures);
}

static void test_physical_geometry_is_dpi_agnostic(std::vector<Failure>& failures) {
    const ScreenRect source{0, 0, 1920, 1080};
    const DestinationSize physical_destination{1920, 1080};

    // DPI scaling is intentionally absent from this contract. If the physical source
    // and destination pixels are unchanged, the render geometry must also be unchanged.
    const auto a = compute_magnification_geometry(source, physical_destination, 2.0);
    const auto b = compute_magnification_geometry(source, physical_destination, 2.0);
    require(near(a.source_viewport.width(), b.source_viewport.width())
        && near(a.source_viewport.height(), b.source_viewport.height()),
        "dpi_agnostic", "identical physical geometry produced different result", failures);
}

static void test_source_resize_reclamps(std::vector<Failure>& failures) {
    const DestinationSize destination{1280, 720};
    const ScreenRect original{0, 0, 1920, 1080};
    const ScreenRect resized{0, 0, 1366, 768};

    const auto before = compute_magnification_geometry(original, destination, 2.0, 1800, 1000);
    const auto after = compute_magnification_geometry(resized, destination, 2.0, 1800, 1000);

    require(before.valid() && after.valid(), "source_resize", "geometry invalid", failures);
    require(after.source_viewport.right <= resized.right + 1e-9, "source_resize", "resized viewport exceeds source right", failures);
    require(after.source_viewport.bottom <= resized.bottom + 1e-9, "source_resize", "resized viewport exceeds source bottom", failures);
}

static void test_overview_is_not_one_x(std::vector<Failure>& failures) {
    const ScreenRect source{0, 0, 2560, 1440};
    const DestinationSize destination{1280, 720};

    const auto one = compute_magnification_geometry(source, destination, 1.0);
    const auto overview = compute_overview_geometry(source, destination);

    require(one.valid() && overview.valid(), "overview_distinct", "geometry invalid", failures);
    require(near(one.source_viewport.width(), 1280.0), "overview_distinct", "1x should preserve pixel scale", failures);
    require(near(overview.source_viewport.width(), 2560.0), "overview_distinct", "overview should show full source", failures);
    require(!near(one.source_viewport.width(), overview.source_viewport.width()), "overview_distinct",
        "overview was conflated with 1x", failures);
}

int main() {
    std::vector<Failure> failures;
    test_matched_1920x1080(failures);
    test_larger_source_smaller_destination(failures);
    test_smaller_source_larger_destination(failures);
    test_portrait_destination(failures);
    test_partial_destination(failures);
    test_negative_origin_and_edge_clamp(failures);
    test_physical_geometry_is_dpi_agnostic(failures);
    test_source_resize_reclamps(failures);
    test_overview_is_not_one_x(failures);

    if (!failures.empty()) {
        std::cerr << "geometry_contract_tests FAILED: " << failures.size() << " failure(s)\n";
        for (const auto& f : failures) std::cerr << "  " << f.name << ": " << f.message << "\n";
        return 1;
    }

    std::cout << "geometry_contract_tests PASSED\n";
    return 0;
}
