#pragma once
#include "view_state.h"
#include <cstdint>
#include <optional>
#include <mutex>
#include <vector>

namespace visual::core {
struct SourceId { std::uint64_t value{}; friend bool operator==(SourceId,SourceId)=default; };
enum class RuntimeNodeState : std::uint8_t { Active, Suspended, Failed };

struct SourceRuntimeNode { SourceId id{}; RuntimeNodeState state{RuntimeNodeState::Active}; };
struct ViewRuntimeNode {
    ViewId id{};
    SourceId source_id{};
    RuntimeNodeState state{RuntimeNodeState::Active};
};

class WorkspaceRuntimeGraph {
public:
    bool add_source(SourceId id) {
        if (find_source(id)) return false;
        sources_.push_back({id,RuntimeNodeState::Active}); return true;
    }
    bool add_view(ViewId id, SourceId sourceId) {
        if (find_view(id) || !find_source(sourceId)) return false;
        views_.push_back({id,sourceId,RuntimeNodeState::Active}); return true;
    }
    bool select(ViewId id) noexcept { if(!find_view(id)) return false; selected_=id; return true; }
    [[nodiscard]] std::optional<ViewId> selected() const noexcept { return selected_; }

    bool set_source_state(SourceId id, RuntimeNodeState state) noexcept {
        std::scoped_lock lock(mutex_);
        auto* s=find_source(id); if(!s) return false; s->state=state;
        for(auto& v:views_) if(v.source_id==id) v.state=(state==RuntimeNodeState::Active?RuntimeNodeState::Active:RuntimeNodeState::Suspended);
        return true;
    }
    [[nodiscard]] bool view_active(ViewId id) const noexcept {
        std::scoped_lock lock(mutex_);
        for(const auto& v:views_) if(v.id==id) return v.state==RuntimeNodeState::Active;
        return false;
    }
    [[nodiscard]] const std::vector<SourceRuntimeNode>& sources() const noexcept{return sources_;}
    [[nodiscard]] const std::vector<ViewRuntimeNode>& views() const noexcept{return views_;}
    [[nodiscard]] const SourceRuntimeNode* source(SourceId id) const noexcept {
        for(const auto& s:sources_) if(s.id==id)return &s; return nullptr;
    }
    [[nodiscard]] const ViewRuntimeNode* view(ViewId id) const noexcept {
        for(const auto& v:views_) if(v.id==id)return &v; return nullptr;
    }
private:
    SourceRuntimeNode* find_source(SourceId id) noexcept {
        for(auto& s:sources_) if(s.id==id)return &s; return nullptr;
    }
    ViewRuntimeNode* find_view(ViewId id) noexcept {
        for(auto& v:views_) if(v.id==id)return &v; return nullptr;
    }
    mutable std::mutex mutex_;
    std::vector<SourceRuntimeNode> sources_;
    std::vector<ViewRuntimeNode> views_;
    std::optional<ViewId> selected_{};
};
}
