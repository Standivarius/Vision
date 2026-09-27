#pragma once

#include <string>

namespace visual::assistant {

struct AnswerResult {
    std::wstring title;
    std::wstring answer;
    std::wstring status;
    bool used_remote{};
    bool success{};
};

// Runtime-only configuration. Visual never embeds a provider credential.
// If VISUAL_ASSISTANT_ENDPOINT is absent, Ask Visual remains useful through the local help catalog.
[[nodiscard]] std::wstring configured_endpoint();
[[nodiscard]] bool remote_configured();

// Local catalog answers are preferred. The configured HTTPS endpoint is used only when
// the local catalog cannot confidently answer the user's question.
[[nodiscard]] AnswerResult answer_question(const std::wstring& question, const std::string& context_json);

} // namespace visual::assistant
