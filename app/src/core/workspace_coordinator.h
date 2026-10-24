#pragma once

#include "view_state.h"

#include <cstdint>
#include <optional>
#include <vector>

namespace visual::core {


struct WorkspaceIntent {
    std::wstring context_monitor_device{};
    std::wstring detail_monitor_device{};
    std::wstring reference_monitor_device{};
};

struct ResolvedWorkspace {
    ViewBinding detail_binding{};
    bool single_monitor_fallback{};
    bool context_intent_resolved{};
    bool detail_intent_resolved{};
    bool reference_intent_resolved{};
};

struct ViewSessionState {
    ViewId id{kCurrentDetailViewId};
    ViewBinding binding{};
    bool movement_enabled{true};
};

struct WorkspaceSnapshot {
    std::uint64_t workspace_id{1};
    std::uint64_t topology_generation{1};
    ViewId selected_view{kCurrentDetailViewId};
    ViewId movement_owner{kCurrentDetailViewId};
};

class WorkspaceCoordinator {
public:
    explicit WorkspaceCoordinator(ViewSessionState initial) : sessions_{std::move(initial)} {
        const auto id = sessions_.front().id;
        snapshot_.selected_view = id;
        snapshot_.movement_owner = id;
    }

    [[nodiscard]] const WorkspaceSnapshot& snapshot() const noexcept { return snapshot_; }
    [[nodiscard]] const std::vector<ViewSessionState>& sessions() const noexcept { return sessions_; }

    [[nodiscard]] const ViewSessionState* selected_session() const noexcept {
        return find(snapshot_.selected_view);
    }

    [[nodiscard]] bool movement_permitted(ViewId id) const noexcept {
        const auto* session = find(id);
        return session && session->movement_enabled && snapshot_.movement_owner == id;
    }

    [[nodiscard]] ViewId route_evidence_to() const noexcept {
        return snapshot_.movement_owner;
    }

    bool add_session(ViewSessionState session) {
        if (find(session.id)) return false;
        sessions_.push_back(std::move(session));
        return true;
    }

    bool select(ViewId id) noexcept {
        if (!find(id)) return false;
        snapshot_.selected_view = id;
        return true;
    }

    bool set_movement_owner(ViewId id) noexcept {
        if (!find(id)) return false;
        snapshot_.movement_owner = id;
        return true;
    }

    void set_topology_generation(std::uint64_t generation) noexcept {
        snapshot_.topology_generation = generation == 0 ? 1 : generation;
    }

private:
    [[nodiscard]] const ViewSessionState* find(ViewId id) const noexcept {
        for (const auto& session : sessions_) {
            if (session.id == id) return &session;
        }
        return nullptr;
    }

    std::vector<ViewSessionState> sessions_;
    WorkspaceSnapshot snapshot_{};
};

} // namespace visual::core
