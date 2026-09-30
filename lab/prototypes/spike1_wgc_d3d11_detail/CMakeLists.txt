cmake_minimum_required(VERSION 3.20)
project(VisualSpike1WgcDetail LANGUAGES CXX)

add_executable(visual_spike1_wgc_detail WIN32
    src/main.cpp
)

target_compile_features(visual_spike1_wgc_detail PRIVATE cxx_std_20)
target_compile_definitions(visual_spike1_wgc_detail PRIVATE
    UNICODE
    _UNICODE
    WIN32_LEAN_AND_MEAN
    NOMINMAX
)
target_compile_options(visual_spike1_wgc_detail PRIVATE
    /W4
    /permissive-
    /EHsc
)
target_link_libraries(visual_spike1_wgc_detail PRIVATE
    d3d11
    dxgi
    d3dcompiler
    windowsapp
    shcore
    shell32
    user32
    gdi32
)

add_executable(visual_spike1_stimulus WIN32
    src/stimulus.cpp
)
target_compile_features(visual_spike1_stimulus PRIVATE cxx_std_20)
target_compile_definitions(visual_spike1_stimulus PRIVATE
    UNICODE
    _UNICODE
    WIN32_LEAN_AND_MEAN
    NOMINMAX
)
target_compile_options(visual_spike1_stimulus PRIVATE
    /W4
    /permissive-
    /EHsc
)
target_link_libraries(visual_spike1_stimulus PRIVATE
    shell32
    user32
    gdi32
)

set_property(TARGET visual_spike1_wgc_detail PROPERTY VS_DEBUGGER_WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}")
set_property(TARGET visual_spike1_stimulus PROPERTY VS_DEBUGGER_WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}")
