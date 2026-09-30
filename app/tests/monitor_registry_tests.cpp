#include "core/monitor_registry.h"
#include <cstdlib>
#include <iostream>

namespace {
void require(bool value, const char* message) {
    if (!value) { std::cerr << "FAILED: " << message << "\n"; std::exit(1); }
}
visual::core::MonitorSnapshot monitor(const wchar_t* name, double left, bool primary=false) {
    visual::core::MonitorSnapshot m{};
    m.identity.gdi_device_name=name; m.bounds={left,0,left+1920,1080}; m.primary=primary;
    return m;
}
}
int main() {
    using namespace visual::core;
    MonitorRegistry registry;
    require(registry.snapshot().generation==1, "initial generation");
    require(registry.update({monitor(L"DISPLAY2",1920),monitor(L"DISPLAY1",0,true)}), "first topology changes");
    require(registry.snapshot().generation==2, "first generation increment");
    require(registry.snapshot().monitors[0].identity.gdi_device_name==L"DISPLAY1", "canonical order");
    require(!registry.update({monitor(L"DISPLAY1",0,true),monitor(L"DISPLAY2",1920)}), "same topology stable");
    require(registry.snapshot().generation==2, "stable topology keeps generation");
    require(registry.update({monitor(L"DISPLAY1",0,true),monitor(L"DISPLAY2",1920,true)}), "primary change detected");
    require(registry.snapshot().generation==3, "primary change increments generation");
    auto changed=monitor(L"DISPLAY2",1920); changed.dpi_x=144; changed.dpi_y=144;
    require(registry.update({monitor(L"DISPLAY1",0,true),changed}), "dpi change detected");
    require(registry.snapshot().generation==4, "dpi change increments generation");
    std::cout<<"monitor_registry_tests PASSED\n";
}
