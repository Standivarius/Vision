#include "assistant_client.h"

#include "core/help_catalog.h"

#include <windows.h>
#include <winhttp.h>

#include <array>
#include <sstream>
#include <string>

namespace visual::assistant {
namespace {

std::string narrow_utf8(const std::wstring& value) {
    if (value.empty()) return {};
    const int needed = WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()), nullptr, 0, nullptr, nullptr);
    if (needed <= 0) return {};
    std::string result(static_cast<std::size_t>(needed), '\0');
    WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()), result.data(), needed, nullptr, nullptr);
    return result;
}

std::wstring widen_utf8(const std::string& value) {
    if (value.empty()) return {};
    const int needed = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(), static_cast<int>(value.size()), nullptr, 0);
    if (needed <= 0) return {};
    std::wstring result(static_cast<std::size_t>(needed), L'\0');
    MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(), static_cast<int>(value.size()), result.data(), needed);
    return result;
}

std::string json_escape(const std::string& value) {
    std::ostringstream out;
    for (unsigned char ch : value) {
        switch (ch) {
        case '"': out << "\\\""; break;
        case '\\': out << "\\\\"; break;
        case '\b': out << "\\b"; break;
        case '\f': out << "\\f"; break;
        case '\n': out << "\\n"; break;
        case '\r': out << "\\r"; break;
        case '\t': out << "\\t"; break;
        default:
            if (ch < 0x20) {
                const char* hex = "0123456789abcdef";
                out << "\\u00" << hex[(ch >> 4) & 0x0f] << hex[ch & 0x0f];
            } else {
                out << static_cast<char>(ch);
            }
            break;
        }
    }
    return out.str();
}

std::string json_string_field(const std::string& json, const std::string& field) {
    const std::string needle = "\"" + field + "\"";
    const auto key = json.find(needle);
    if (key == std::string::npos) return {};
    const auto colon = json.find(':', key + needle.size());
    if (colon == std::string::npos) return {};
    auto start = json.find('"', colon + 1);
    if (start == std::string::npos) return {};
    ++start;

    std::string value;
    bool escaped = false;
    for (std::size_t i = start; i < json.size(); ++i) {
        const char ch = json[i];
        if (escaped) {
            switch (ch) {
            case 'n': value.push_back('\n'); break;
            case 'r': value.push_back('\r'); break;
            case 't': value.push_back('\t'); break;
            case 'b': value.push_back('\b'); break;
            case 'f': value.push_back('\f'); break;
            case '"': value.push_back('"'); break;
            case '\\': value.push_back('\\'); break;
            default: value.push_back(ch); break;
            }
            escaped = false;
        } else if (ch == '\\') {
            escaped = true;
        } else if (ch == '"') {
            break;
        } else {
            value.push_back(ch);
        }
    }
    return value;
}

struct HttpResult {
    DWORD status{};
    std::string body;
    std::string error;
};

HttpResult post_json(const std::wstring& endpoint, const std::string& body) {
    HttpResult result{};

    URL_COMPONENTSW parts{};
    parts.dwStructSize = sizeof(parts);
    std::array<wchar_t, 512> host{};
    std::array<wchar_t, 4096> path{};
    parts.lpszHostName = host.data();
    parts.dwHostNameLength = static_cast<DWORD>(host.size());
    parts.lpszUrlPath = path.data();
    parts.dwUrlPathLength = static_cast<DWORD>(path.size());
    if (!WinHttpCrackUrl(endpoint.c_str(), 0, 0, &parts)) {
        result.error = "invalid_endpoint";
        return result;
    }
    if (parts.nScheme != INTERNET_SCHEME_HTTPS) {
        result.error = "https_required";
        return result;
    }

    std::wstring host_name(parts.lpszHostName, parts.dwHostNameLength);
    std::wstring request_path(parts.lpszUrlPath, parts.dwUrlPathLength);
    if (request_path.empty()) request_path = L"/";

    HINTERNET session = WinHttpOpen(L"Visual Ask/1.0", WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY,
                                    WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
    if (!session) {
        result.error = "session_failed";
        return result;
    }
    WinHttpSetTimeouts(session, 5000, 5000, 5000, 45000);

    HINTERNET connect = WinHttpConnect(session, host_name.c_str(), parts.nPort, 0);
    if (!connect) {
        result.error = "connect_failed";
        WinHttpCloseHandle(session);
        return result;
    }

    HINTERNET request = WinHttpOpenRequest(connect, L"POST", request_path.c_str(), nullptr,
                                           WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES, WINHTTP_FLAG_SECURE);
    if (!request) {
        result.error = "request_failed";
        WinHttpCloseHandle(connect);
        WinHttpCloseHandle(session);
        return result;
    }

    const wchar_t headers[] = L"Content-Type: application/json\r\nAccept: application/json\r\n";
    const BOOL sent = WinHttpSendRequest(request, headers, static_cast<DWORD>(-1L),
                                         const_cast<char*>(body.data()), static_cast<DWORD>(body.size()),
                                         static_cast<DWORD>(body.size()), 0);
    if (!sent || !WinHttpReceiveResponse(request, nullptr)) {
        result.error = "send_or_receive_failed";
    } else {
        DWORD status_size = sizeof(result.status);
        WinHttpQueryHeaders(request, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                            WINHTTP_HEADER_NAME_BY_INDEX, &result.status, &status_size, WINHTTP_NO_HEADER_INDEX);
        for (;;) {
            DWORD available = 0;
            if (!WinHttpQueryDataAvailable(request, &available) || available == 0) break;
            if (result.body.size() + available > 65536) {
                result.error = "response_too_large";
                break;
            }
            std::string chunk(static_cast<std::size_t>(available), '\0');
            DWORD read = 0;
            if (!WinHttpReadData(request, chunk.data(), available, &read) || read == 0) break;
            chunk.resize(read);
            result.body += chunk;
        }
    }

    WinHttpCloseHandle(request);
    WinHttpCloseHandle(connect);
    WinHttpCloseHandle(session);
    return result;
}

AnswerResult generic_local_fallback(bool remote_available) {
    AnswerResult result{};
    result.title = L"Ask Visual";
    result.answer = remote_available
        ? L"I couldn't get an online answer. Try asking about Screen Roles, Tracking, the View Locator, 1x View / Return, Colour & Contrast, shortcuts, settings, Reference, or Freeze View / Hooked Areas."
        : L"Ask Visual is using local help only. Try asking about Screen Roles, Tracking, the View Locator, 1x View / Return, Colour & Contrast, shortcuts, settings, Reference, or Freeze View / Hooked Areas.";
    result.status = remote_available ? L"Online help unavailable — local help remains available" : L"Local Visual help";
    result.success = true;
    return result;
}

} // namespace

std::wstring configured_endpoint() {
    DWORD needed = GetEnvironmentVariableW(L"VISUAL_ASSISTANT_ENDPOINT", nullptr, 0);
    if (needed == 0) return {};
    std::wstring value(static_cast<std::size_t>(needed), L'\0');
    const DWORD written = GetEnvironmentVariableW(L"VISUAL_ASSISTANT_ENDPOINT", value.data(), needed);
    if (written == 0 || written >= needed) return {};
    value.resize(written);
    return value;
}

bool remote_configured() {
    return !configured_endpoint().empty();
}

AnswerResult answer_question(const std::wstring& question, const std::string& context_json) {
    if (const auto local = visual::core::help_answer_for_query(question); local.matched) {
        return {local.title, local.body, L"Local Visual help", false, true};
    }

    const auto endpoint = configured_endpoint();
    if (endpoint.empty()) return generic_local_fallback(false);

    const auto utf8_question = narrow_utf8(question);
    if (utf8_question.empty()) return generic_local_fallback(true);

    const std::string body = std::string("{\"schema_version\":\"1\",\"intent\":\"ask_visual\",\"question\":\"")
        + json_escape(utf8_question) + "\",\"context\":" + (context_json.empty() ? "{}" : context_json) + "}";

    const auto http = post_json(endpoint, body);
    if (!http.error.empty() || http.status < 200 || http.status >= 300) return generic_local_fallback(true);

    const auto answer_utf8 = json_string_field(http.body, "answer");
    if (answer_utf8.empty()) return generic_local_fallback(true);
    const auto title_utf8 = json_string_field(http.body, "title");

    AnswerResult result{};
    result.title = title_utf8.empty() ? L"Ask Visual" : widen_utf8(title_utf8);
    result.answer = widen_utf8(answer_utf8);
    result.status = L"Online contextual help";
    result.used_remote = true;
    result.success = !result.answer.empty();
    if (!result.success) return generic_local_fallback(true);
    return result;
}

} // namespace visual::assistant
