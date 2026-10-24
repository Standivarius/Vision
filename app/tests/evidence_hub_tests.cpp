#include "tracking/evidence_hub.h"
#include <cstdlib>
#include <iostream>
namespace{void req(bool v,const char*m){if(!v){std::cerr<<"FAILED: "<<m<<"\n";std::exit(1);}}}
int main(){using namespace visual::tracking;
 EvidenceHub hub; req(hub.snapshot().generation==0,"initial empty generation");
 EvidenceSnapshot a{}; a.sampled_qpc=100; hub.publish(a);
 auto one=hub.snapshot(); req(one.generation==1&&one.snapshot.sampled_qpc==100,"first publication");
 EvidenceSnapshot b{}; b.sampled_qpc=200; hub.publish(b);
 auto two=hub.snapshot(); req(two.generation==2&&two.snapshot.sampled_qpc==200,"second publication");
 req(one.generation==1&&one.snapshot.sampled_qpc==100,"consumer snapshot value-owned");
 std::cout<<"evidence_hub_tests PASSED\n";
}
