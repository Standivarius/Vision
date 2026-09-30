#include "core/replay_oracle.h"

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

static bool same_rect(const ScreenRect& a, const ScreenRect& b, double eps = 1e-9) {
    return near(a.left, b.left, eps) && near(a.top, b.top, eps)
        && near(a.right, b.right, eps) && near(a.bottom, b.bottom, eps);
}

static PoiCandidate candidate(
    PoiKind kind,
    PoiSource source,
    ScreenRect rect,
    std::uint64_t qpc,
    std::uint32_t process_id = 1234,
    std::uint64_t identity = 1) {

    PoiCandidate c{};
    c.kind = kind;
    c.source = source;
    c.confidence = PoiConfidence::High;
    c.screen_rect = rect;
    c.timestamp_qpc = qpc;
    c.process_id = process_id;
    c.identity = identity;
    return c;
}

static std::vector<ReplayFrameInput> acceptance_seed_fixture() {
    // Seeded from:
    // lab/benchmarks/integrated_app/runs/2026-09-30_16-57-00__mouse_viewport_smoke/
    // visual_app_telemetry.csv
    //
    // Observed at 2x:
    // selected pointer rect = (640,360)-(641,361)
    // resulting viewport    = (160.5,90.5)-(1120.5,630.5)
    // Later, after pointer evidence aged out, the viewport held in place.
    constexpr std::uint64_t freq = 1000;
    const ScreenRect source{0, 0, 1920, 1080};
    const auto pointer = candidate(
        PoiKind::Pointer,
        PoiSource::Pointer,
        {640, 360, 641, 361},
        1000,
        0,
        0);

    const auto old_caret = candidate(
        PoiKind::Caret,
        PoiSource::UiaTextPattern2Caret,
        {800, 420, 804, 440},
        900,
        10,
        20);

    return {
        ReplayFrameInput{source, 2.0, true, true, {old_caret, pointer}, 1068, freq},
        ReplayFrameInput{source, 2.0, true, true, {old_caret, pointer}, 1238, freq},
    };
}

static void test_acceptance_seed(std::vector<Failure>& failures) {
    const std::string name = "acceptance_seed";
    ReplayOracle oracle;
    const auto frames = acceptance_seed_fixture();

    const auto first = oracle.step(frames[0]);
    require(first.view.selected_poi.has_value(), name, "seed frame should select pointer", failures);
    if (first.view.selected_poi) {
        require(first.view.selected_poi->source == PoiSource::Pointer, name, "pointer should win seed frame", failures);
    }
    const ScreenRect observed{160.5, 90.5, 1120.5, 630.5};
    require(same_rect(first.view.viewport, observed), name, "seed viewport differs from observed telemetry", failures);
    require(first.locator.visible, name, "seed locator should be visible", failures);

    const auto stale = oracle.step(frames[1]);
    require(!stale.view.selected_poi.has_value(), name, "pre-pointer caret must not reclaim after pointer ages out", failures);
    require(same_rect(stale.view.viewport, observed), name, "stale evidence should hold observed viewport", failures);
    require(!stale.locator.visible, name, "stale locator should expire even when visibility is independent of movement selection", failures);
}

static void test_deterministic_replay(std::vector<Failure>& failures) {
    const std::string name = "deterministic_replay";
    const auto frames = acceptance_seed_fixture();

    ReplayOracle a;
    ReplayOracle b;
    for (const auto& frame : frames) {
        const auto x = a.step(frame);
        const auto y = b.step(frame);
        require(x.view.action == y.view.action, name, "action differs across identical replay", failures);
        require(x.view.restored_previous_view == y.view.restored_previous_view, name, "restore flag differs", failures);
        require(same_rect(x.view.viewport, y.view.viewport), name, "viewport differs across identical replay", failures);
        require(x.locator.visible == y.locator.visible, name, "locator visibility differs", failures);
    }
}

static void test_perturbation_fails_golden_output(std::vector<Failure>& failures) {
    const std::string name = "perturbation_changes_output";
    auto frames = acceptance_seed_fixture();
    ReplayOracle baseline;
    const auto expected = baseline.step(frames[0]);

    frames[0].candidates.back().screen_rect = {1000, 360, 1001, 361};
    ReplayOracle perturbed;
    const auto changed = perturbed.step(frames[0]);

    require(!same_rect(expected.view.viewport, changed.view.viewport), name,
        "moving the selected pointer should change the initial viewport", failures);
}

static void test_locator_can_remain_visible_when_follow_is_off(std::vector<Failure>& failures) {
    const std::string name = "locator_without_follow";
    ReplayOracle oracle;
    const ScreenRect source{0, 0, 1920, 1080};
    const auto caret = candidate(
        PoiKind::Caret,
        PoiSource::UiaTextPattern2Caret,
        {960, 540, 964, 560},
        1000);

    const auto initial = oracle.step({source, 2.0, true, true, {caret}, 1010, 1000});
    const auto no_follow = oracle.step({source, 2.0, false, true, {caret}, 1020, 1000});

    require(no_follow.view.action == ViewportAction::Hold, name, "follow-off frame should hold", failures);
    require(same_rect(initial.view.viewport, no_follow.view.viewport), name, "follow-off changed viewport", failures);
    require(no_follow.locator.visible, name, "locator should remain independently visible", failures);
}

static void test_exact_temporary_normal_return(std::vector<Failure>& failures) {
    const std::string name = "exact_temporary_normal_return";
    ReplayOracle oracle;
    const ScreenRect source{0, 0, 1920, 1080};

    const auto first_target = candidate(
        PoiKind::Caret,
        PoiSource::UiaTextPattern2Caret,
        {1400, 700, 1404, 720},
        1000);
    const auto moved_target = candidate(
        PoiKind::Caret,
        PoiSource::UiaTextPattern2Caret,
        {1500, 760, 1504, 780},
        1020);

    (void)oracle.step({source, 2.0, true, true, {first_target}, 1010, 1000});
    const auto magnified = oracle.step({source, 2.0, true, true, {moved_target}, 1030, 1000});
    (void)oracle.step({source, 1.0, true, true, {moved_target}, 1050, 1000});
    const auto restored = oracle.step({source, 2.0, true, true, {moved_target}, 1070, 1000});

    require(restored.view.restored_previous_view, name, "return should identify exact restoration", failures);
    require(same_rect(magnified.view.viewport, restored.view.viewport), name, "return did not restore exact viewport", failures);
}

int main() {
    std::vector<Failure> failures;
    test_acceptance_seed(failures);
    test_deterministic_replay(failures);
    test_perturbation_fails_golden_output(failures);
    test_locator_can_remain_visible_when_follow_is_off(failures);
    test_exact_temporary_normal_return(failures);

    if (!failures.empty()) {
        std::cerr << "replay_oracle_tests FAILED: " << failures.size() << " failure(s)\n";
        for (const auto& f : failures) std::cerr << "  " << f.name << ": " << f.message << "\n";
        return 1;
    }

    std::cout << "replay_oracle_tests PASSED\n";
    return 0;
}
