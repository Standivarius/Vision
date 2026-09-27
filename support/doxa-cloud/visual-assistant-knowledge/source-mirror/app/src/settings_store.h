#pragma once

#include "core/settings_model.h"

#include <filesystem>

namespace visual::settings {

struct AssistanceState {
    bool screen_roles_explained{false};
    bool view_locator_explained{false};
    bool one_x_return_explained{false};
};

[[nodiscard]] std::filesystem::path default_settings_path();
[[nodiscard]] visual::core::VisualSettings load_settings(const std::filesystem::path& path);
[[nodiscard]] bool save_settings(const std::filesystem::path& path, const visual::core::VisualSettings& settings) noexcept;
[[nodiscard]] AssistanceState load_assistance_state(const std::filesystem::path& path);
[[nodiscard]] bool save_assistance_state(const std::filesystem::path& path, const AssistanceState& state) noexcept;

} // namespace visual::settings
