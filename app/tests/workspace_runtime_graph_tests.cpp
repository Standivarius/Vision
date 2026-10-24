#include "core/workspace_runtime_graph.h"
#include <cstdlib>
#include <iostream>
namespace{void req(bool v,const char*m){if(!v){std::cerr<<"FAILED: "<<m<<"\n";std::exit(1);}}}
int main(){using namespace visual::core;
 WorkspaceRuntimeGraph g; SourceId a{1},b{2}; ViewId v1{1},v2{2},v3{3};
 req(g.add_source(a)&&g.add_source(b),"two sources");
 req(!g.add_source(a),"duplicate source rejected");
 req(g.add_view(v1,a)&&g.add_view(v2,a)&&g.add_view(v3,b),"generic view dependencies");
 req(g.select(v3)&&g.selected()->value==3,"explicit command target");
 req(g.set_source_state(a,RuntimeNodeState::Failed),"source failure accepted");
 req(g.view(v1)->state==RuntimeNodeState::Suspended&&g.view(v2)->state==RuntimeNodeState::Suspended,"only dependent views suspended");
 req(g.view(v3)->state==RuntimeNodeState::Active,"independent source/view remains active");
 req(g.set_source_state(a,RuntimeNodeState::Active),"source recovery");
 req(g.view(v1)->state==RuntimeNodeState::Active&&g.view(v2)->state==RuntimeNodeState::Active,"dependent views resume");
 std::cout<<"workspace_runtime_graph_tests PASSED\n";
}
