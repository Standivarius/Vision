#include "coordinate_model.h"

#include <iostream>
#include <string>
#include <vector>

using namespace visual::coordinates;

struct TestFailure {
    std::string name;
    std::string message;
};

static void require(bool condition, const std::string& name, const std::string& message, std::vector<TestFailure>& failures) {
    if (!condition) failures.push_back({name, message});
}

static void test_right_monitor(std::vector<TestFailure>& failures) {
    const std::string name = "right_monitor";
    const MonitorRect rect{1920, 0, 3840, 1080};
    require(rect.contains({1920, 0}), name, "left/top edge should be inside", failures);
    require(rect.contains({3839, 1079}), name, "right/bottom inclusive pixel should be inside", failures);
    require(!rect.contains({3840, 1079}), name, "right edge is half-open", failures);

    const auto local = to_monitor_local({2880, 540}, rect);
    require(local.has_value(), name, "center local conversion missing", failures);
    if (local) {
        require(local->x == 960 && local->y == 540, name, "unexpected center local coordinates", failures);
    }
}

static void test_negative_monitor(std::vector<TestFailure>& failures) {
    const std::string name = "negative_monitor";
    const MonitorRect rect{-2560, -240, 0, 1200};
    const ScreenPoint p{-1280, 480};
    require(rect.contains(p), name, "negative screen point should resolve inside monitor", failures);

    const auto local = to_monitor_local(p, rect);
    require(local.has_value(), name, "negative-layout local conversion missing", failures);
    if (local) {
        require(local->x == 1280 && local->y == 720, name, "negative-layout local coordinates wrong", failures);
    }

    const auto normalized = to_normalized(p, rect);
    require(normalized.has_value(), name, "negative-layout normalized conversion missing", failures);
    if (normalized) {
        require(normalized->x > 0.49 && normalized->x < 0.51, name, "negative-layout normalized x should be near center", failures);
        require(normalized->y > 0.49 && normalized->y < 0.51, name, "negative-layout normalized y should be near center", failures);
    }
}

static void test_vertical_monitor(std::vector<TestFailure>& failures) {
    const std::string name = "vertical_monitor";
    const MonitorRect rect{320, -1440, 2240, 0};
    require(rect.contains({320, -1440}), name, "top-left should be inside", failures);
    require(rect.contains({2239, -1}), name, "bottom-right pixel should be inside", failures);
    require(!rect.contains({320, 0}), name, "bottom edge is half-open", failures);
}

static void test_round_trip(std::vector<TestFailure>& failures) {
    const std::string name = "round_trip";
    const MonitorRect rect{-1920, 1080, 0, 2160};
    const std::vector<ScreenPoint> points{
        {-1920, 1080},
        {-1919, 1081},
        {-960, 1620},
        {-1, 2159}
    };

    for (const auto p : points) {
        const auto norm = to_normalized(p, rect);
        require(norm.has_value(), name, "expected normalized point", failures);
        if (!norm) continue;
        const auto back = from_normalized(*norm, rect);
        require(back.has_value(), name, "expected round-trip screen point", failures);
        if (!back) continue;
        require(back->x == p.x && back->y == p.y, name, "round-trip changed integer screen point", failures);
    }
}

static void test_invalid_inputs(std::vector<TestFailure>& failures) {
    const std::string name = "invalid_inputs";
    const MonitorRect bad{100, 100, 100, 200};
    require(!bad.valid(), name, "zero-width rect must be invalid", failures);
    require(!to_monitor_local({100, 100}, bad).has_value(), name, "invalid rect should not convert local coordinates", failures);
    require(!from_normalized({0.5, 0.5}, bad).has_value(), name, "invalid rect should not convert normalized coordinates", failures);

    const MonitorRect good{0, 0, 1920, 1080};
    require(!from_normalized({-0.1, 0.5}, good).has_value(), name, "negative normalized x should be rejected", failures);
    require(!from_normalized({1.1, 0.5}, good).has_value(), name, "normalized x > 1 should be rejected", failures);
}

int main() {
    std::vector<TestFailure> failures;
    test_right_monitor(failures);
    test_negative_monitor(failures);
    test_vertical_monitor(failures);
    test_round_trip(failures);
    test_invalid_inputs(failures);

    if (!failures.empty()) {
        std::cerr << "coordinate_model_tests FAILED: " << failures.size() << " failure(s)\n";
        for (const auto& f : failures) std::cerr << "  " << f.name << ": " << f.message << "\n";
        return 1;
    }

    std::cout << "coordinate_model_tests PASSED\n";
    return 0;
}
