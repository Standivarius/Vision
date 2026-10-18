#include "core/poi_evidence.h"

#include <iostream>
#include <string>
#include <vector>

using namespace visual::core;

struct Failure { std::string name; std::string message; };

static void require(bool ok, const std::string& name, const std::string& message, std::vector<Failure>& failures) {
    if (!ok) failures.push_back({name, message});
}

static PoiCandidate make(PoiKind kind, PoiSource source, std::uint64_t qpc) {
    PoiCandidate c{};
    c.kind = kind;
    c.source = source;
    c.confidence = PoiConfidence::High;
    c.screen_rect = {100, 100, 110, 120};
    c.timestamp_qpc = qpc;
    return c;
}

int main() {
    std::vector<Failure> failures;
    constexpr std::uint64_t freq = 1000;

    {
        const std::uint64_t now = 10'000;
        const auto caret = make(PoiKind::Caret, PoiSource::UiaTextPattern2Caret, now - 5);
        const auto pointer = make(PoiKind::Pointer, PoiSource::Pointer, now - 10);
        const auto best = select_best_poi({caret, pointer}, now, freq);
        require(best.has_value(), "recent_pointer", "expected a POI", failures);
        if (best) require(best->source == PoiSource::Pointer, "recent_pointer", "deliberate recent pointer movement should override caret", failures);
    }

    {
        const std::uint64_t now = 20'000;
        const auto caret = make(PoiKind::Caret, PoiSource::UiaTextPattern2Caret, now - 5);
        const auto pointer = make(PoiKind::Pointer, PoiSource::Pointer, now - 150); // stale under default 100 ms pointer age
        const auto best = select_best_poi({caret, pointer}, now, freq);
        require(best.has_value(), "caret_resumes", "expected a POI", failures);
        if (best) require(best->source == PoiSource::UiaTextPattern2Caret, "caret_resumes", "caret should resume after pointer evidence ages out", failures);
    }

    {
        const std::uint64_t now = 25'000;
        const auto preexistingCaret = make(PoiKind::Caret, PoiSource::UiaTextPattern2Caret, now - 200);
        const auto stoppedPointer = make(PoiKind::Pointer, PoiSource::Pointer, now - 150); // pointer stale, but newer than caret
        const auto best = select_best_poi({preexistingCaret, stoppedPointer}, now, freq);
        require(!best.has_value(), "pre_pointer_caret_suppressed", "caret evidence from before pointer movement must not reclaim the viewport", failures);
    }

    {
        const std::uint64_t now = 27'000;
        const auto stoppedPointer = make(PoiKind::Pointer, PoiSource::Pointer, now - 150);
        const auto movedCaret = make(PoiKind::Caret, PoiSource::UiaTextPattern2Caret, now - 5);
        const auto best = select_best_poi({stoppedPointer, movedCaret}, now, freq);
        require(best.has_value(), "post_pointer_caret_resumes", "caret movement after pointer intent should resume tracking", failures);
        if (best) require(best->source == PoiSource::UiaTextPattern2Caret, "post_pointer_caret_resumes", "newer caret should own the viewport", failures);
    }
    {
        const std::uint64_t now = 30'000;
        const auto explicitTarget = make(PoiKind::ExplicitTarget, PoiSource::ExplicitUserTarget, now - 10);
        const auto pointer = make(PoiKind::Pointer, PoiSource::Pointer, now - 1);
        const auto best = select_best_poi({pointer, explicitTarget}, now, freq);
        require(best.has_value(), "explicit_target", "expected a POI", failures);
        if (best) require(best->source == PoiSource::ExplicitUserTarget, "explicit_target", "explicit user target must remain highest priority", failures);
    }

    {
        auto prior = make(PoiKind::Caret, PoiSource::UiaTextPattern2Caret, 40'000);
        prior.process_id = 10;
        prior.identity = 20;
        auto blink_sample = prior;
        blink_sample.timestamp_qpc = 40'500;
        require(same_poi_target(prior, blink_sample), "stationary_caret_same_target", "unchanged caret sample should not be new activity", failures);

        auto moved = blink_sample;
        moved.screen_rect.left += 8.0;
        moved.screen_rect.right += 8.0;
        require(!same_poi_target(prior, moved), "moved_caret_new_target", "caret geometry movement must count as new activity", failures);
    }

    {
        auto prior = make(PoiKind::Focus, PoiSource::UiaFocus, 50'000);
        prior.process_id = 11;
        prior.identity = 21;
        auto repeated = prior;
        repeated.timestamp_qpc = 50'500;
        require(same_poi_target(prior, repeated), "stationary_focus_same_target", "unchanged focus sample should not be new activity", failures);

        auto changed = repeated;
        changed.identity = 22;
        require(!same_poi_target(prior, changed), "changed_focus_new_target", "focus identity change must count as new activity", failures);
    }

    // A live foreground Win32 caret must remain authoritative when the
    // insertion point is unchanged; otherwise a broad Word document focus
    // rectangle drags the 4x Detail viewport away after 250 ms.
    {
        auto previous = make(PoiKind::Caret, PoiSource::Win32Caret, 60'000);
        previous.process_id = 42;
        previous.identity = 0x1234;
        previous.screen_rect = {5173, 493, 5174, 532};
        auto observed = previous;
        observed.timestamp_qpc = 60'600;
        const auto refreshed = live_win32_caret_timestamp(observed, previous, 0);
        require(refreshed == 60'600, "word_still_foreground",
                "live Win32 caret must refresh while foreground owner is unchanged", failures);
        observed.timestamp_qpc = refreshed;
        auto broadFocus = make(PoiKind::Focus, PoiSource::UiaFocus, 60'600);
        broadFocus.process_id = previous.process_id;
        broadFocus.screen_rect = {3901, 343, 5580, 920};
        const auto selected = select_best_poi({observed, broadFocus}, 60'600, freq);
        require(selected && selected->source == PoiSource::Win32Caret,
                "word_caret_outlives_focus",
                "live caret must not yield to unrelated broad focus rectangle", failures);
    }

    // The same stationary caret must NOT reclaim Detail after the user
    // deliberately moves the pointer. Only a new caret position may do so.
    {
        auto oldCaret = make(PoiKind::Caret, PoiSource::Win32Caret, 70'000);
        oldCaret.process_id = 45;
        oldCaret.identity = 0x20;
        auto unchanged = oldCaret;
        unchanged.timestamp_qpc = 70'350;
        const auto retained = live_win32_caret_timestamp(unchanged, oldCaret, 70'180);
        require(retained == 70'000, "pointer_barrier_retains_stale_caret",
                "stationary caret after pointer motion must remain old evidence", failures);
        unchanged.timestamp_qpc = retained;
        auto pointer = make(PoiKind::Pointer, PoiSource::Pointer, 70'180);
        const auto selected = select_best_poi({unchanged, pointer}, 70'350, freq, {}, 70'180);
        require(!selected, "pointer_barrier_prevents_caret_reclaim",
                "stale pointer and pre-pointer stationary caret must not steal the view", failures);

        auto moved = unchanged;
        moved.timestamp_qpc = 70'355;
        moved.screen_rect.left += 65;
        moved.screen_rect.right += 65;
        const auto newTimestamp = live_win32_caret_timestamp(moved, unchanged, 70'180);
        require(newTimestamp == 70'355, "caret_motion_after_pointer",
                "new caret geometry after pointer intent must be eligible", failures);
    }

    // A different owning process is a new caret, not a continuation of a
    // stale Word insertion point when switching to Excel.
    {
        auto word = make(PoiKind::Caret, PoiSource::Win32Caret, 80'000);
        word.process_id = 50;
        word.identity = 0xCA;
        auto excel = word;
        excel.process_id = 51;
        excel.timestamp_qpc = 80'350;
        require(live_win32_caret_timestamp(excel, word, 80'170) == 80'350,
                "cross_app_caret_identity",
                "Word caret must not suppress fresh Excel caret geometry", failures);
    }
    if (!failures.empty()) {
        std::cerr << "poi_arbitration_tests FAILED: " << failures.size() << " failure(s)\n";
        for (const auto& f : failures) std::cerr << "  " << f.name << ": " << f.message << "\n";
        return 1;
    }
    std::cout << "poi_arbitration_tests PASSED\n";
    return 0;
}
