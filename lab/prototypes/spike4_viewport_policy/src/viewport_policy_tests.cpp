#include "viewport_policy.h"

#include <cmath>
#include <iostream>
#include <string>
#include <vector>

using namespace visual::viewport;

struct Failure { std::string name; std::string message; };

static void require(bool ok, const std::string& name, const std::string& message, std::vector<Failure>& failures) {
    if (!ok) failures.push_back({name, message});
}

static bool near(double a, double b, double eps = 1e-9) {
    return std::abs(a - b) <= eps;
}

static void test_hold_when_comfortable(std::vector<Failure>& failures) {
    const std::string name = "hold_when_comfortable";
    const Rect source{0, 0, 1920, 1080};
    const Rect view{400, 200, 1200, 800};
    const Rect poi{750, 470, 760, 490};
    const auto d = decide(source, view, poi);
    require(d.action == Action::Hold, name, "comfortable POI should hold", failures);
    require(near(d.target_viewport.left, view.left) && near(d.target_viewport.top, view.top), name, "hold should preserve exact viewport", failures);
}

static void test_minimum_pan_right(std::vector<Failure>& failures) {
    const std::string name = "minimum_pan_right";
    const Rect source{0, 0, 2000, 1000};
    const Rect view{0, 0, 1000, 500};
    const Rect poi{850, 200, 870, 220};
    Config cfg{};
    cfg.margin_ratio_x = 0.20;
    cfg.margin_ratio_y = 0.20;
    cfg.jump_threshold_viewport_fraction = 0.75;
    const auto d = decide(source, view, poi, true, cfg);
    // Comfort right = 800, so move right by exactly 70.
    require(d.action == Action::Pan, name, "small correction should pan", failures);
    require(near(d.requested_dx, 70.0), name, "unexpected requested dx", failures);
    require(near(d.applied_dx, 70.0), name, "unexpected applied dx", failures);
    require(near(d.target_viewport.left, 70.0), name, "unexpected target left", failures);
}

static void test_minimum_pan_left_and_up(std::vector<Failure>& failures) {
    const std::string name = "minimum_pan_left_and_up";
    const Rect source{-1000, -800, 2000, 1600};
    const Rect view{-200, -100, 800, 500};
    const Rect poi{-150, -80, -130, -60};
    Config cfg{};
    cfg.margin_ratio_x = 0.20;
    cfg.margin_ratio_y = 0.20;
    const auto d = decide(source, view, poi, true, cfg);
    // Comfort starts at x=0,y=20. POI left/top are -150/-80.
    require(d.action == Action::Pan, name, "small diagonal correction should pan", failures);
    require(near(d.requested_dx, -150.0), name, "wrong dx", failures);
    require(near(d.requested_dy, -100.0), name, "wrong dy", failures);
}

static void test_far_target_jumps(std::vector<Failure>& failures) {
    const std::string name = "far_target_jumps";
    const Rect source{0, 0, 4000, 2000};
    const Rect view{0, 0, 1000, 500};
    const Rect poi{3000, 800, 3020, 820};
    Config cfg{};
    cfg.jump_threshold_viewport_fraction = 0.75;
    const auto d = decide(source, view, poi, true, cfg);
    require(d.action == Action::Jump, name, "large displacement should jump", failures);
    require(d.applied_dx > 1000.0, name, "expected large horizontal displacement", failures);
}

static void test_edge_clamp(std::vector<Failure>& failures) {
    const std::string name = "edge_clamp";
    const Rect source{0, 0, 1920, 1080};
    const Rect view{920, 580, 1920, 1080};
    const Rect poi{1900, 1060, 1919, 1079};
    const auto d = decide(source, view, poi);
    require(d.action == Action::Pan, name, "edge target may request movement but should remain valid", failures);
    require(near(d.target_viewport.right, 1920.0), name, "viewport must stay clamped to source right edge", failures);
    require(near(d.target_viewport.bottom, 1080.0), name, "viewport must stay clamped to source bottom edge", failures);
    require(near(d.applied_dx, 0.0) && near(d.applied_dy, 0.0), name, "already edge-clamped viewport cannot move farther", failures);
}

static void test_oversized_poi_centers(std::vector<Failure>& failures) {
    const std::string name = "oversized_poi_centers";
    const Rect source{0, 0, 3000, 2000};
    const Rect view{500, 500, 1500, 1000};
    const Rect poi{1600, 520, 2500, 980};
    Config cfg{};
    cfg.margin_ratio_x = 0.20; // comfort width 600, POI width 900
    cfg.margin_ratio_y = 0.10;
    const auto d = decide(source, view, poi, true, cfg);
    require(d.action == Action::Jump || d.action == Action::Pan, name, "oversized POI must produce movement", failures);
    require(near(d.requested_dx, poi.center_x() - view.center_x()), name, "oversized POI should center horizontally", failures);
}

static void test_tracking_disabled(std::vector<Failure>& failures) {
    const std::string name = "tracking_disabled";
    const Rect source{0, 0, 3000, 2000};
    const Rect view{0, 0, 1000, 500};
    const Rect poi{2500, 1500, 2510, 1510};
    const auto d = decide(source, view, poi, false);
    require(d.action == Action::Hold, name, "manual override should hold", failures);
    require(d.reason == Reason::TrackingDisabled, name, "wrong hold reason", failures);
    require(near(d.target_viewport.left, 0.0) && near(d.target_viewport.top, 0.0), name, "manual override changed viewport", failures);
}

static void test_negative_coordinates(std::vector<Failure>& failures) {
    const std::string name = "negative_coordinates";
    const Rect source{-2560, -1440, 1920, 1080};
    const Rect view{-1800, -900, -800, -400};
    const Rect poi{-1950, -1000, -1940, -980};
    const auto d = decide(source, view, poi);
    require(d.action == Action::Pan, name, "negative-origin layout should pan normally", failures);
    require(d.target_viewport.left < view.left, name, "expected movement toward more-negative x", failures);
    require(d.target_viewport.top < view.top, name, "expected movement toward more-negative y", failures);
}

static void test_invalid_geometry(std::vector<Failure>& failures) {
    const std::string name = "invalid_geometry";
    const Rect source{0, 0, 1000, 500};
    const Rect too_big_view{0, 0, 1200, 600};
    const Rect poi{10, 10, 20, 20};
    require(decide(source, too_big_view, poi).action == Action::Invalid, name, "viewport larger than source should be invalid", failures);

    Config bad{};
    bad.margin_ratio_x = 0.5;
    require(decide(source, {0, 0, 500, 250}, poi, true, bad).action == Action::Invalid, name, "invalid margin should be rejected", failures);
}

static void test_repeated_input_no_drift(std::vector<Failure>& failures) {
    const std::string name = "repeated_input_no_drift";
    const Rect source{0, 0, 3000, 1600};
    Rect view{0, 0, 1000, 500};
    const Rect poi{850, 200, 870, 220};
    const auto first = decide(source, view, poi);
    require(first.action == Action::Pan, name, "first decision should pan", failures);
    view = first.target_viewport;
    const auto second = decide(source, view, poi);
    require(second.action == Action::Hold, name, "same POI after correction should hold", failures);
    require(near(second.target_viewport.left, first.target_viewport.left), name, "repeated decision drifted", failures);
}

int main() {
    std::vector<Failure> failures;
    test_hold_when_comfortable(failures);
    test_minimum_pan_right(failures);
    test_minimum_pan_left_and_up(failures);
    test_far_target_jumps(failures);
    test_edge_clamp(failures);
    test_oversized_poi_centers(failures);
    test_tracking_disabled(failures);
    test_negative_coordinates(failures);
    test_invalid_geometry(failures);
    test_repeated_input_no_drift(failures);

    if (!failures.empty()) {
        std::cerr << "viewport_policy_tests FAILED: " << failures.size() << " failure(s)\n";
        for (const auto& f : failures) std::cerr << "  " << f.name << ": " << f.message << "\n";
        return 1;
    }
    std::cout << "viewport_policy_tests PASSED\n";
    return 0;
}
