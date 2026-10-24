#include "poi_evidence.h"

#include <iostream>
#include <string>
#include <vector>

using namespace visual::poi;

struct Failure { std::string name; std::string message; };

static void require(bool ok, const std::string& name, const std::string& message, std::vector<Failure>& failures) {
    if (!ok) failures.push_back({name, message});
}

static Candidate make_candidate(Kind kind, Source source, Confidence confidence, std::uint64_t qpc) {
    Candidate c{};
    c.kind = kind;
    c.source = source;
    c.confidence = confidence;
    c.screen_rect = {100, 100, 110, 120};
    c.timestamp_qpc = qpc;
    c.process_id = 42;
    return c;
}

static void test_caret_precedence(std::vector<Failure>& failures) {
    const std::string name = "caret_precedence";
    const std::uint64_t freq = 10'000;
    const std::uint64_t now = 100'000;
    std::vector<Candidate> c{
        make_candidate(Kind::Focus, Source::UiaFocus, Confidence::High, now - 20),
        make_candidate(Kind::Caret, Source::Win32Caret, Confidence::High, now - 30),
        make_candidate(Kind::Caret, Source::UiaTextPatternSelection, Confidence::Medium, now - 40),
        make_candidate(Kind::Caret, Source::UiaTextPattern2Caret, Confidence::High, now - 50),
    };
    const auto best = select_best(c, now, freq);
    require(best.has_value(), name, "expected a candidate", failures);
    if (best) require(best->source == Source::UiaTextPattern2Caret, name, "TextPattern2 caret should win when fresh", failures);
}

static void test_win32_fallback(std::vector<Failure>& failures) {
    const std::string name = "win32_fallback";
    const std::uint64_t freq = 1'000;
    const std::uint64_t now = 50'000;
    SelectionPolicy policy{};
    std::vector<Candidate> c{
        make_candidate(Kind::Caret, Source::UiaTextPattern2Caret, Confidence::High, now - 500),
        make_candidate(Kind::Caret, Source::Win32Caret, Confidence::High, now - 50),
    };
    const auto best = select_best(c, now, freq, policy);
    require(best.has_value(), name, "expected fallback candidate", failures);
    if (best) require(best->source == Source::Win32Caret, name, "fresh Win32 caret should beat stale UIA caret", failures);
}

static void test_focus_when_no_caret(std::vector<Failure>& failures) {
    const std::string name = "focus_when_no_caret";
    const std::uint64_t freq = 1'000;
    const std::uint64_t now = 20'000;
    std::vector<Candidate> c{
        make_candidate(Kind::Focus, Source::Win32Focus, Confidence::Medium, now - 10),
        make_candidate(Kind::Focus, Source::UiaFocus, Confidence::High, now - 20),
    };
    const auto best = select_best(c, now, freq);
    require(best.has_value(), name, "expected focus candidate", failures);
    if (best) require(best->source == Source::UiaFocus, name, "UIA focus should beat Win32 focus", failures);
}

static void test_explicit_target(std::vector<Failure>& failures) {
    const std::string name = "explicit_target";
    const std::uint64_t freq = 1'000;
    const std::uint64_t now = 8'000;
    std::vector<Candidate> c{
        make_candidate(Kind::Caret, Source::UiaTextPattern2Caret, Confidence::High, now - 1),
        make_candidate(Kind::ExplicitTarget, Source::ExplicitUserTarget, Confidence::High, now - 2),
    };
    const auto best = select_best(c, now, freq);
    require(best.has_value(), name, "expected target", failures);
    if (best) require(best->source == Source::ExplicitUserTarget, name, "explicit target should take precedence", failures);
}

static void test_stale_means_none(std::vector<Failure>& failures) {
    const std::string name = "stale_means_none";
    const std::uint64_t freq = 1'000;
    const std::uint64_t now = 10'000;
    SelectionPolicy p{};
    p.max_caret_age_ms = 100.0;
    std::vector<Candidate> c{ make_candidate(Kind::Caret, Source::Win32Caret, Confidence::High, now - 500) };
    const auto best = select_best(c, now, freq, p);
    require(!best.has_value(), name, "stale evidence should produce no automatic target", failures);
}

static void test_invalid_rect_rejected(std::vector<Failure>& failures) {
    const std::string name = "invalid_rect_rejected";
    Candidate c = make_candidate(Kind::Caret, Source::Win32Caret, Confidence::High, 100);
    c.screen_rect = {5, 5, 5, 10};
    const auto best = select_best({c}, 101, 1'000);
    require(!best.has_value(), name, "invalid geometry must not become POI", failures);
}

int main() {
    std::vector<Failure> failures;
    test_caret_precedence(failures);
    test_win32_fallback(failures);
    test_focus_when_no_caret(failures);
    test_explicit_target(failures);
    test_stale_means_none(failures);
    test_invalid_rect_rejected(failures);

    if (!failures.empty()) {
        std::cerr << "poi_evidence_tests FAILED: " << failures.size() << " failure(s)\n";
        for (const auto& f : failures) std::cerr << "  " << f.name << ": " << f.message << "\n";
        return 1;
    }
    std::cout << "poi_evidence_tests PASSED\n";
    return 0;
}
