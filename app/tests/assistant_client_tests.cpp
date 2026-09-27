#include "assistant_client.h"

#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>
#include <windows.h>

struct Failure { std::string name; std::string message; };
static void require(bool ok, const std::string& name, const std::string& message, std::vector<Failure>& failures) {
    if (!ok) failures.push_back({name, message});
}

int main() {
    std::vector<Failure> failures;
    SetEnvironmentVariableW(L"VISUAL_ASSISTANT_ENDPOINT", nullptr);

    const auto known = visual::assistant::answer_question(L"Where is ZoomText Freeze View?", "{}");
    require(known.success, "known_success", "known local question should succeed", failures);
    require(!known.used_remote, "known_local", "known local question must not use remote", failures);
    require(known.title == L"Freeze View / Hooked Areas", "known_title", "Freeze query should return migration title", failures);
    require(known.answer.find(L"does not currently implement") != std::wstring::npos,
            "known_truth", "Freeze answer must preserve implementation truth", failures);

    const auto unknown = visual::assistant::answer_question(L"Please explain something not in the local catalog", "{}");
    require(unknown.success, "unknown_fallback", "offline unknown question should return a usable fallback", failures);
    require(!unknown.used_remote, "unknown_no_remote", "offline fallback must not claim remote use", failures);
    require(unknown.status.find(L"Local") != std::wstring::npos, "unknown_status", "offline fallback should identify local help", failures);

    if (!failures.empty()) {
        std::cerr << "assistant_client_tests FAILED: " << failures.size() << " failure(s)\n";
        for (const auto& f : failures) std::cerr << "  " << f.name << ": " << f.message << "\n";
        return 1;
    }
    std::cout << "assistant_client_tests PASSED\n";
    return 0;
}
