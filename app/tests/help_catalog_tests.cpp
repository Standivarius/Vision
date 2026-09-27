#include "core/help_catalog.h"

#include <iostream>
#include <string>
#include <vector>

using namespace visual::core;

struct Failure { std::string name; std::string message; };
static void require(bool ok, const std::string& name, const std::string& message, std::vector<Failure>& failures) {
    if (!ok) failures.push_back({name, message});
}

int main() {
    std::vector<Failure> failures;

    auto answer = help_answer_for_query(L"Where is ZoomText Freeze View?");
    require(answer.matched, "freeze_match", "Freeze View should match", failures);
    require(answer.body.find(L"does not currently implement") != std::wstring::npos,
            "freeze_truth", "Freeze answer must not claim Reference is equivalent", failures);

    answer = help_answer_for_query(L"What is the rectangle on the Context screen?");
    require(answer.matched && answer.title == L"View Locator", "view_locator", "Context rectangle should map to View Locator", failures);

    answer = help_answer_for_query(L"Why doesn't it follow my text cursor?");
    require(answer.matched && answer.title == L"Tracking", "tracking", "text cursor query should map to Tracking", failures);

    answer = help_answer_for_query(L"How do I get back after 1x?");
    require(answer.matched && answer.title == L"1x View / Return", "one_x", "1x return query should match", failures);

    answer = help_answer_for_query(L"totally unrelated question");
    require(!answer.matched, "unknown", "unknown question should be left for remote Ask fallback", failures);

    VisualSettings settings{};
    settings.zoom = 3.0;
    settings.follow_focus = false;
    settings.visual_mode = VisualMode::Inverted;
    settings.context_monitor_device = L"DISPLAY1";
    settings.detail_monitor_device = L"DISPLAY2";
    const auto json = build_assistant_context_json(settings, 2, false);
    require(json.find("\"zoom\":3.0") != std::string::npos, "context_zoom", "context should contain zoom", failures);
    require(json.find("\"follow_keyboard_focus\":false") != std::string::npos, "context_focus", "context should contain focus setting", failures);
    require(json.find("DISPLAY1") == std::string::npos, "context_privacy", "context must not expose monitor device identifiers", failures);
    require(json.find("\"reference_assigned\":false") != std::string::npos, "context_reference", "context should contain assignment boolean", failures);

    if (!failures.empty()) {
        std::cerr << "help_catalog_tests FAILED: " << failures.size() << " failure(s)\n";
        for (const auto& f : failures) std::cerr << "  " << f.name << ": " << f.message << "\n";
        return 1;
    }
    std::cout << "help_catalog_tests PASSED\n";
    return 0;
}
