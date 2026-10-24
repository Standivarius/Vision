#include "core/topology_reconciler.h"
#include <cstdlib>
#include <iostream>
namespace { void require(bool v,const char* m){if(!v){std::cerr<<"FAILED: "<<m<<"\n";std::exit(1);}} }
int main(){
 using namespace visual::core;
 TopologyReconciler r(500);
 require(r.accepts_generation(1),"initial generation accepted");
 r.signal_change(1000);
 require(!r.accepts_generation(1),"old generation paused immediately");
 require(r.poll(1499)==TopologyReconcileState::Debouncing,"debounce holds");
 r.signal_change(1400);
 require(r.poll(1899)==TopologyReconcileState::Debouncing,"later event resets debounce");
 require(r.poll(1900)==TopologyReconcileState::RebuildReady,"quiet window enables rebuild");
 require(!r.accepts_generation(1),"no generation accepted before rebuild");
 r.rebuild_completed(2);
 require(r.accepts_generation(2),"new generation accepted");
 require(!r.accepts_generation(1),"old generation rejected");
 std::cout<<"topology_reconciler_tests PASSED\n";
}
