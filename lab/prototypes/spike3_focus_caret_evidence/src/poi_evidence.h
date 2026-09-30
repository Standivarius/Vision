#pragma once

#include <algorithm>
#include <cstdint>
#include <optional>
#include <string_view>
#include <vector>

namespace visual::poi {

enum class Kind {
    Pointer,
    Caret,
    Focus,
    ExplicitTarget,
};

enum class Source {
    UiaTextPattern2Caret,
    UiaTextPatternSelection,
    Win32Caret,
    UiaFocus,
    Win32Focus,
    Pointer,
    ExplicitUserTarget,
};

enum class Confidence {
    Low = 1,
    Medium = 2,
    High = 3,
};

struct ScreenRect {
    double left{};
    double top{};
    double right{};
    double bottom{};

    [[nodiscard]] double width() const noexcept { return right - left; }
    [[nodiscard]] double height() const noexcept { return bottom - top; }
    [[nodiscard]] bool valid() const noexcept {
        return right > left && bottom > top;
    }
};

struct Candidate {
    Kind kind{Kind::Focus};
    Source source{Source::UiaFocus};
    Confidence confidence{Confidence::Low};
    ScreenRect screen_rect{};
    std::uint64_t timestamp_qpc{};
    std::uint32_t process_id{};
    std::uint64_t identity{};

    [[nodiscard]] bool usable() const noexcept {
        return screen_rect.valid() && timestamp_qpc != 0;
    }
};

struct SelectionPolicy {
    double max_caret_age_ms{250.0};
    double max_focus_age_ms{500.0};
    double max_pointer_age_ms{100.0};
};

[[nodiscard]] inline std::string_view source_name(Source s) noexcept {
    switch (s) {
    case Source::UiaTextPattern2Caret: return "uia_textpattern2_caret";
    case Source::UiaTextPatternSelection: return "uia_textpattern_selection";
    case Source::Win32Caret: return "win32_caret";
    case Source::UiaFocus: return "uia_focus";
    case Source::Win32Focus: return "win32_focus";
    case Source::Pointer: return "pointer";
    case Source::ExplicitUserTarget: return "explicit_user_target";
    }
    return "unknown";
}

[[nodiscard]] inline int source_priority(Source s) noexcept {
    switch (s) {
    case Source::ExplicitUserTarget: return 700;
    case Source::UiaTextPattern2Caret: return 620;
    case Source::UiaTextPatternSelection: return 610;
    case Source::Win32Caret: return 600;
    case Source::Pointer: return 500;
    case Source::UiaFocus: return 400;
    case Source::Win32Focus: return 300;
    }
    return 0;
}

[[nodiscard]] inline double max_age_ms_for(const Candidate& c, const SelectionPolicy& policy) noexcept {
    switch (c.kind) {
    case Kind::Caret: return policy.max_caret_age_ms;
    case Kind::Focus: return policy.max_focus_age_ms;
    case Kind::Pointer: return policy.max_pointer_age_ms;
    case Kind::ExplicitTarget: return 1000.0;
    }
    return 0.0;
}

[[nodiscard]] inline bool is_fresh(
    const Candidate& c,
    std::uint64_t now_qpc,
    std::uint64_t qpc_frequency,
    const SelectionPolicy& policy) noexcept {
    if (!c.usable() || qpc_frequency == 0 || now_qpc < c.timestamp_qpc) return false;
    const auto ticks = now_qpc - c.timestamp_qpc;
    const double age_ms = 1000.0 * static_cast<double>(ticks) / static_cast<double>(qpc_frequency);
    return age_ms <= max_age_ms_for(c, policy);
}

[[nodiscard]] inline std::optional<Candidate> select_best(
    const std::vector<Candidate>& candidates,
    std::uint64_t now_qpc,
    std::uint64_t qpc_frequency,
    const SelectionPolicy& policy = {}) noexcept {
    std::optional<Candidate> best;
    for (const auto& c : candidates) {
        if (!is_fresh(c, now_qpc, qpc_frequency, policy)) continue;
        if (!best) {
            best = c;
            continue;
        }
        const int c_rank = source_priority(c.source) * 10 + static_cast<int>(c.confidence);
        const int b_rank = source_priority(best->source) * 10 + static_cast<int>(best->confidence);
        if (c_rank > b_rank || (c_rank == b_rank && c.timestamp_qpc > best->timestamp_qpc)) best = c;
    }
    return best;
}

} // namespace visual::poi
