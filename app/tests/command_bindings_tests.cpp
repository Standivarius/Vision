#include "core/command_bindings.h"

#include <iostream>
#include <set>
#include <string>
#include <vector>

using namespace visual::core;

int main() {
    std::vector<std::string> failures;
    std::set<int> ids;
    std::set<unsigned long long> chords;

    for (const auto& binding : kInternalAlphaHotkeys) {
        if (!ids.insert(binding.registration_id).second) {
            failures.push_back("duplicate registration id");
        }
        const auto chord =
            (static_cast<unsigned long long>(binding.modifiers) << 32) |
            static_cast<unsigned long long>(binding.virtual_key);
        if (!chords.insert(chord).second) {
            failures.push_back("duplicate hotkey chord");
        }
        const auto roundtrip = command_for_hotkey_id(binding.registration_id);
        if (!roundtrip || *roundtrip != binding.command) {
            failures.push_back("registration id does not round-trip to command");
        }
        if (binding.display.empty()) {
            failures.push_back("empty shortcut display");
        }
    }

    if (kInternalAlphaHotkeyProfileExternalReleaseSafe) {
        failures.push_back("legacy Ctrl+Alt profile must remain explicitly blocked for external release");
    }

    const auto settings = hotkey_for_command(VisionCommand::OpenSettings);
    if (!settings || settings->display != L"Ctrl+Alt+S") {
        failures.push_back("internal-alpha settings binding changed unexpectedly");
    }

    if (!failures.empty()) {
        std::cerr << "command_bindings_tests FAILED: " << failures.size() << " failure(s)\n";
        for (const auto& failure : failures) std::cerr << "  " << failure << "\n";
        return 1;
    }
    std::cout << "command_bindings_tests PASSED\n";
    return 0;
}
