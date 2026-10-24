#include "tracking/evidence_sampler.h"

#include <iostream>
#include <string>
#include <vector>

using namespace visual;

struct Failure { std::string name; std::string message; };

static void require(bool ok, const std::string& name, const std::string& message, std::vector<Failure>& failures) {
    if (!ok) failures.push_back({name, message});
}

static void test_snapshot_is_value_owned(std::vector<Failure>& failures) {
    const std::string name = "value_owned";
    tracking::EvidenceSnapshot a{};
    core::PoiCandidate c{};
    c.kind = core::PoiKind::Caret;
    c.source = core::PoiSource::Win32Caret;
    c.screen_rect = {10, 20, 11, 40};
    c.timestamp_qpc = 100;
    a.candidates.push_back(c);
    a.sampled_qpc = 120;
    a.pointer_movement_qpc = 90;
    a.uia_sampled_qpc = 110;
    a.uia_current_caret_present = true;

    auto b = a;
    b.candidates[0].screen_rect.left = 999;
    b.sampled_qpc = 999;

    require(a.candidates[0].screen_rect.left == 10, name, "candidate storage was shared", failures);
    require(a.sampled_qpc == 120, name, "snapshot metadata was shared", failures);
}

static void test_snapshot_preserves_provider_metadata(std::vector<Failure>& failures) {
    const std::string name = "provider_metadata";
    tracking::EvidenceSnapshot s{};
    s.sampled_qpc = 1000;
    s.pointer_movement_qpc = 900;
    s.uia_sampled_qpc = 950;
    s.uia_current_caret_present = true;
    s.uia_current_focus_present = false;

    require(s.sampled_qpc == 1000, name, "sample timestamp lost", failures);
    require(s.pointer_movement_qpc == 900, name, "pointer timestamp lost", failures);
    require(s.uia_sampled_qpc == 950, name, "UIA timestamp lost", failures);
    require(s.uia_current_caret_present && !s.uia_current_focus_present, name, "UIA presence flags lost", failures);
}

int main() {
    std::vector<Failure> failures;
    test_snapshot_is_value_owned(failures);
    test_snapshot_preserves_provider_metadata(failures);

    if (!failures.empty()) {
        std::cerr << "evidence_snapshot_tests FAILED: " << failures.size() << " failure(s)\n";
        for (const auto& f : failures) std::cerr << "  " << f.name << ": " << f.message << "\n";
        return 1;
    }
    std::cout << "evidence_snapshot_tests PASSED\n";
    return 0;
}
