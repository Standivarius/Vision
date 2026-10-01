#include "core/ui_strings.h"

#include <iostream>
#include <set>
#include <string>
#include <vector>

using namespace visual::core;

int main() {
    std::vector<std::string> failures;
    std::set<std::string> keys;

    for (std::size_t i = 0; i < static_cast<std::size_t>(UiStringId::Count); ++i) {
        const auto id = static_cast<UiStringId>(i);
        const auto key = ui_string_key(id);
        const auto value = ui_string(id);
        if (key.empty()) failures.push_back("empty key at index " + std::to_string(i));
        if (value.empty()) failures.push_back("empty English value at index " + std::to_string(i));
        if (!keys.insert(std::string(key)).second) failures.push_back("duplicate key: " + std::string(key));
    }

    if (ui_string(UiStringId::SettingsTitle) != L"Vision Settings") {
        failures.push_back("SettingsTitle mapping changed unexpectedly");
    }
    if (ui_string_key(UiStringId::HelpWorkingStatus) != "help.working.status") {
        failures.push_back("stable help working-status key changed");
    }

    if (!failures.empty()) {
        std::cerr << "ui_strings_tests FAILED: " << failures.size() << " failure(s)\n";
        for (const auto& failure : failures) std::cerr << "  " << failure << "\n";
        return 1;
    }
    std::cout << "ui_strings_tests PASSED: " << keys.size() << " stable keys\n";
    return 0;
}
