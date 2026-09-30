#pragma once
#include "evidence_sampler.h"
#include <cstdint>
#include <mutex>

namespace visual::tracking {
struct PublishedEvidence {
    EvidenceSnapshot snapshot{};
    std::uint64_t generation{};
};
class EvidenceHub {
public:
    void publish(EvidenceSnapshot snapshot) {
        std::scoped_lock lock(mutex_);
        current_.snapshot=std::move(snapshot);
        ++current_.generation;
    }
    [[nodiscard]] PublishedEvidence snapshot() const {
        std::scoped_lock lock(mutex_);
        return current_;
    }
private:
    mutable std::mutex mutex_;
    PublishedEvidence current_{};
};
}
