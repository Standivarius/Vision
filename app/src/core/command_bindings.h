#pragma once

#include <array>
#include <cstdint>
#include <optional>
#include <string_view>

namespace visual::core {

enum class VisionCommand : std::uint8_t {
    Zoom1,
    Zoom2,
    Zoom3,
    Zoom4,
    ToggleTracking,
    OpenSettings,
    OpenHelp,
    NormalReturn,
    Exit,
};

enum HotkeyModifier : std::uint8_t {
    HotkeyControl = 1u << 0,
    HotkeyAlt = 1u << 1,
    HotkeyShift = 1u << 2,
    HotkeyWin = 1u << 3,
    HotkeyNoRepeat = 1u << 4,
};

struct HotkeyBinding {
    VisionCommand command{};
    int registration_id{};
    unsigned int virtual_key{};
    std::uint8_t modifiers{};
    std::wstring_view display;
};

// Compatibility profile for the current internal alpha only.
// Microsoft explicitly advises Windows applications not to use Ctrl+Alt
// shortcuts because that chord is AltGr on some keyboard layouts.
// Keep the profile isolated so product commands are no longer coupled to it.
inline constexpr std::array<HotkeyBinding, 9> kInternalAlphaHotkeys{{
    {VisionCommand::Zoom1,          101, static_cast<unsigned int>('1'), HotkeyControl | HotkeyAlt | HotkeyNoRepeat, L"Ctrl+Alt+1"},
    {VisionCommand::Zoom2,          102, static_cast<unsigned int>('2'), HotkeyControl | HotkeyAlt | HotkeyNoRepeat, L"Ctrl+Alt+2"},
    {VisionCommand::Zoom3,          103, static_cast<unsigned int>('3'), HotkeyControl | HotkeyAlt | HotkeyNoRepeat, L"Ctrl+Alt+3"},
    {VisionCommand::Zoom4,          104, static_cast<unsigned int>('4'), HotkeyControl | HotkeyAlt | HotkeyNoRepeat, L"Ctrl+Alt+4"},
    {VisionCommand::ToggleTracking, 110, static_cast<unsigned int>('T'), HotkeyControl | HotkeyAlt | HotkeyNoRepeat, L"Ctrl+Alt+T"},
    {VisionCommand::OpenSettings,   111, static_cast<unsigned int>('S'), HotkeyControl | HotkeyAlt | HotkeyNoRepeat, L"Ctrl+Alt+S"},
    {VisionCommand::OpenHelp,       112, static_cast<unsigned int>('H'), HotkeyControl | HotkeyAlt | HotkeyNoRepeat, L"Ctrl+Alt+H"},
    {VisionCommand::NormalReturn,   120, static_cast<unsigned int>('0'), HotkeyControl | HotkeyAlt | HotkeyNoRepeat, L"Ctrl+Alt+0"},
    {VisionCommand::Exit,           199, static_cast<unsigned int>('Q'), HotkeyControl | HotkeyAlt | HotkeyNoRepeat, L"Ctrl+Alt+Q"},
}};

inline constexpr bool kInternalAlphaHotkeyProfileExternalReleaseSafe = false;

[[nodiscard]] constexpr const HotkeyBinding* hotkey_for_command(VisionCommand command) noexcept {
    for (const auto& binding : kInternalAlphaHotkeys) {
        if (binding.command == command) return &binding;
    }
    return nullptr;
}

[[nodiscard]] constexpr std::optional<VisionCommand> command_for_hotkey_id(int id) noexcept {
    for (const auto& binding : kInternalAlphaHotkeys) {
        if (binding.registration_id == id) return binding.command;
    }
    return std::nullopt;
}

[[nodiscard]] constexpr std::optional<VisionCommand> command_for_local_key(unsigned int key) noexcept {
    switch (key) {
    case '1': return VisionCommand::Zoom1;
    case '2': return VisionCommand::Zoom2;
    case '3': return VisionCommand::Zoom3;
    case '4': return VisionCommand::Zoom4;
    case 'T': return VisionCommand::ToggleTracking;
    case 'S': return VisionCommand::OpenSettings;
    case 'H': return VisionCommand::OpenHelp;
    case '0': return VisionCommand::NormalReturn;
    default: return std::nullopt;
    }
}

} // namespace visual::core
