#include "core/view_update_step.h"

#include <cmath>
#include <iostream>
#include <string>
#include <vector>

using namespace visual::core;

struct Failure { std::string name; std::string message; };

static void require(bool ok, const std::string& name, const std::string& message, std::vector<Failure>& failures) {
    if (!ok) failures.push_back({name, message});
}

static bool near(double a, double b, double eps = 1e-9) { return std::abs(a - b) <= eps; }
static bool same_rect(const ScreenRect& a, const ScreenRect& b) {
    return near(a.left,b.left) && near(a.top,b.top) && near(a.right,b.right) && near(a.bottom,b.bottom);
}

static PoiCandidate pointer_at(double x, double y, std::uint64_t qpc) {
    PoiCandidate p{};
    p.kind = PoiKind::Pointer;
    p.source = PoiSource::Pointer;
    p.confidence = PoiConfidence::High;
    p.screen_rect = {x,y,x+1,y+1};
    p.timestamp_qpc = qpc;
    return p;
}

static void test_current_acceptance_seed(std::vector<Failure>& failures) {
    const std::string name="acceptance_seed";
    ViewUpdateStep step;
    VisualSettings settings{};
    settings.zoom=2.0;
    const auto out=step.update({{0,0,1920,1080},settings,{pointer_at(640,360,1000)},1068,1000});
    require(same_rect(out.view.viewport,{160.5,90.5,1120.5,630.5}),name,"viewport changed",failures);
    require(out.locator.visible,name,"locator should be visible",failures);
}

static void test_follow_filter_is_legacy_compatible(std::vector<Failure>& failures) {
    const std::string name="follow_filter";
    ViewUpdateStep step;
    VisualSettings settings{};
    settings.zoom=2.0;
    settings.follow_pointer=false;
    const auto out=step.update({{0,0,1920,1080},settings,{pointer_at(640,360,1000)},1010,1000});
    require(!out.view.selected_poi.has_value(),name,"disabled pointer following still selected pointer",failures);
    require(out.locator.visible,name,"pointer cue should remain visible when following is disabled",failures);
}

static void test_overlay_visibility_is_independent_of_follow(std::vector<Failure>& failures) {
    const std::string name="overlay_without_follow";
    ViewUpdateStep step;
    VisualSettings settings{};
    settings.zoom=2.0;
    settings.follow_caret=false;
    PoiCandidate caret{};
    caret.kind=PoiKind::Caret; caret.source=PoiSource::UiaTextPattern2Caret;
    caret.confidence=PoiConfidence::High; caret.screen_rect={640,360,642,380}; caret.timestamp_qpc=1000;
    const auto out=step.update({{0,0,1920,1080},settings,{caret},1010,1000});
    require(!out.view.selected_poi.has_value(),name,"caret with following off moved/selected view",failures);
    require(out.view.action==ViewportAction::Hold,name,"overlay-only caret should hold viewport",failures);
    require(out.locator.visible,name,"caret locator hidden when following off",failures);
    require(out.locator.kind==PoiKind::Caret,name,"wrong overlay kind",failures);

    caret.screen_rect={1800,900,1802,920}; caret.timestamp_qpc=1020;
    const auto outside=step.update({{0,0,1920,1080},settings,{caret},1030,1000});
    require(!outside.locator.visible,name,"out-of-viewport overlay should be hidden",failures);
}

static void test_tracking_off_holds_but_preserves_selected_locator(std::vector<Failure>& failures) {
    const std::string name="tracking_off";
    ViewUpdateStep step;
    VisualSettings settings{};
    settings.zoom=2.0;
    const auto first=step.update({{0,0,1920,1080},settings,{pointer_at(640,360,1000)},1010,1000});
    settings.tracking_enabled=false;
    const auto held=step.update({{0,0,1920,1080},settings,{pointer_at(900,500,1020)},1030,1000});
    require(held.view.action==ViewportAction::Hold,name,"tracking-off should hold",failures);
    require(same_rect(first.view.viewport,held.view.viewport),name,"tracking-off moved viewport",failures);
    require(held.locator.visible,name,"selected target locator should remain visible",failures);
}

int main(){
    std::vector<Failure> failures;
    test_current_acceptance_seed(failures);
    test_follow_filter_is_legacy_compatible(failures);
    test_overlay_visibility_is_independent_of_follow(failures);
    test_tracking_off_holds_but_preserves_selected_locator(failures);
    if(!failures.empty()){
        std::cerr<<"view_update_step_tests FAILED: "<<failures.size()<<" failure(s)\n";
        for(const auto& f:failures) std::cerr<<"  "<<f.name<<": "<<f.message<<"\n";
        return 1;
    }

    // Pointer-leave policy: pointer intent remains a barrier after the pointer leaves
    // the source and is therefore absent from routed candidates.
    const std::string p1name="pointer_leave_policy";
    ViewUpdateStep pointerLeaveStep;
    VisualSettings p1settings{};
    p1settings.zoom=2.0;
    const ScreenRect p1source{0,0,1920,1080};
    const auto p1pointer=pointer_at(640,360,1000);

    ViewStepInput seedInput{};
    seedInput.source=p1source; seedInput.settings=p1settings; seedInput.evidence={p1pointer};
    seedInput.now_qpc=1000; seedInput.qpc_frequency=1000; seedInput.pointer_intent_barrier_qpc=1000;
    const auto pointerSeed=pointerLeaveStep.update(seedInput);

    PoiCandidate staleFocus{};
    staleFocus.kind=PoiKind::Focus; staleFocus.source=PoiSource::UiaFocus;
    staleFocus.confidence=PoiConfidence::High; staleFocus.screen_rect={100,100,200,150};
    staleFocus.timestamp_qpc=900;
    ViewStepInput leaveInput{};
    leaveInput.source=p1source; leaveInput.settings=p1settings; leaveInput.evidence={staleFocus};
    leaveInput.now_qpc=1050; leaveInput.qpc_frequency=1000; leaveInput.pointer_intent_barrier_qpc=1000;
    const auto heldOutside=pointerLeaveStep.update(leaveInput);
    require(heldOutside.view.action==ViewportAction::Hold,p1name,"pointer leave did not hold",failures);
    require(!heldOutside.view.selected_poi.has_value(),p1name,"stale semantic evidence reclaimed viewport",failures);
    require(same_rect(heldOutside.view.viewport,pointerSeed.view.viewport),p1name,"pointer leave changed viewport",failures);

    PoiCandidate freshCaret{};
    freshCaret.kind=PoiKind::Caret; freshCaret.source=PoiSource::UiaTextPattern2Caret;
    freshCaret.confidence=PoiConfidence::High; freshCaret.screen_rect={1700,900,1702,920};
    freshCaret.timestamp_qpc=1100;
    ViewStepInput transferInput{};
    transferInput.source=p1source; transferInput.settings=p1settings; transferInput.evidence={freshCaret};
    transferInput.now_qpc=1100; transferInput.qpc_frequency=1000; transferInput.pointer_intent_barrier_qpc=1000;
    const auto semanticTransfer=pointerLeaveStep.update(transferInput);
    require(semanticTransfer.view.selected_poi.has_value(),p1name,"new semantic activity did not transfer",failures);
    require(semanticTransfer.view.selected_poi && semanticTransfer.view.selected_poi->kind==PoiKind::Caret,
            p1name,"fresh caret did not win transfer",failures);

    if(!failures.empty()){
        std::cerr<<"view_update_step_tests FAILED: "<<failures.size()<<" failure(s)\n";
        for(const auto& f:failures) std::cerr<<"  "<<f.name<<": "<<f.message<<"\n";
        return 1;
    }
std::cout<<"view_update_step_tests PASSED\n";
    return 0;
}
