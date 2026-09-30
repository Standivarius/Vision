cmake_minimum_required(VERSION 3.20)
project(VisualSpike3FocusCaretEvidence LANGUAGES CXX)

enable_testing()

add_executable(visual_spike3_probe src/probe.cpp app.manifest)
add_executable(visual_spike3_stimulus WIN32 src/stimulus.cpp app.manifest)
add_executable(visual_spike3_poi_evidence_tests src/poi_evidence_tests.cpp src/poi_evidence.h)

foreach(t visual_spike3_probe visual_spike3_stimulus visual_spike3_poi_evidence_tests)
  target_compile_features(${t} PRIVATE cxx_std_20)
  target_compile_definitions(${t} PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
  target_compile_options(${t} PRIVATE /W4 /permissive- /EHsc)
endforeach()

target_link_libraries(visual_spike3_probe PRIVATE user32 ole32 oleaut32 uiautomationcore)
target_link_libraries(visual_spike3_stimulus PRIVATE user32 ole32 oleaut32)

add_test(NAME poi_evidence_tests COMMAND visual_spike3_poi_evidence_tests)
