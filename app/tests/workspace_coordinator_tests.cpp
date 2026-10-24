#include "core/workspace_coordinator.h"

#include <cstdlib>
#include <iostream>

namespace {
void require(bool value, const char* message) {
    if (!value) {
        std::cerr << "FAILED: " << message << "\n";
        std::exit(1);
    }
}
}

int main() {
    using namespace visual::core;
    ViewSessionState detail{};
    detail.id = kCurrentDetailViewId;
    detail.binding.source_monitor_device = L"DISPLAY1";
    detail.binding.destination_monitor_device = L"DISPLAY2";

    WorkspaceIntent intent{};
    intent.context_monitor_device = L"DISPLAY-A";
    intent.detail_monitor_device = L"DISPLAY-B";
    ResolvedWorkspace resolved{};
    resolved.detail_binding = detail.binding;
    resolved.single_monitor_fallback = true;
    require(intent.context_monitor_device == L"DISPLAY-A", "fallback does not mutate context intent");
    require(intent.detail_monitor_device == L"DISPLAY-B", "fallback does not mutate detail intent");

    WorkspaceCoordinator workspace(detail);
    require(workspace.sessions().size() == 1, "one initial session");
    require(workspace.snapshot().workspace_id == 1, "workspace identity");
    require(workspace.snapshot().selected_view == kCurrentDetailViewId, "selected detail");
    require(workspace.snapshot().movement_owner == kCurrentDetailViewId, "movement owner detail");
    require(workspace.movement_permitted(kCurrentDetailViewId), "movement permitted for owner");
    require(workspace.route_evidence_to() == kCurrentDetailViewId, "evidence routed to movement owner");
    require(workspace.selected_session() != nullptr, "selected session resolves");
    require(workspace.selected_session()->binding.source_monitor_device == L"DISPLAY1", "source binding retained");
    ViewSessionState secondary{};
    secondary.id = ViewId{2};
    secondary.binding.source_monitor_device = L"DISPLAY1";
    secondary.binding.destination_monitor_device = L"DISPLAY2";
    require(workspace.add_session(secondary), "second session can be added");
    require(workspace.sessions().size() == 2, "two sessions retained");
    require(!workspace.add_session(secondary), "duplicate session rejected");
    require(workspace.select(ViewId{2}), "secondary can be selected");
    require(!workspace.movement_permitted(ViewId{2}), "selected view is not automatically movement owner");
    require(workspace.set_movement_owner(ViewId{2}), "movement owner can transfer explicitly");
    require(workspace.movement_permitted(ViewId{2}), "new movement owner permitted");
    require(!workspace.movement_permitted(kCurrentDetailViewId), "old movement owner no longer permitted");
    require(workspace.set_movement_owner(kCurrentDetailViewId), "movement owner restores");

    require(!workspace.select(ViewId{99}), "unknown view cannot be selected");
    require(!workspace.set_movement_owner(ViewId{99}), "unknown view cannot own movement");
    workspace.set_topology_generation(7);
    require(workspace.snapshot().topology_generation == 7, "topology generation retained");
    workspace.set_topology_generation(0);
    require(workspace.snapshot().topology_generation == 1, "zero topology generation normalised");

    std::cout << "workspace_coordinator_tests PASSED\n";
    return 0;
}
