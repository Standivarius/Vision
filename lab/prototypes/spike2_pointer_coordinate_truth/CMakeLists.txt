cmake_minimum_required(VERSION 3.20)
project(VisualSpike2PointerCoordinateTruth LANGUAGES CXX)

enable_testing()

add_executable(visual_spike2_coordinate_truth
    src/main.cpp
    src/coordinate_model.h
    app.manifest
)

target_compile_features(visual_spike2_coordinate_truth PRIVATE cxx_std_20)
target_compile_definitions(visual_spike2_coordinate_truth PRIVATE
    UNICODE
    _UNICODE
    WIN32_LEAN_AND_MEAN
    NOMINMAX
)
target_compile_options(visual_spike2_coordinate_truth PRIVATE
    /W4
    /permissive-
    /EHsc
)
target_link_libraries(visual_spike2_coordinate_truth PRIVATE
    user32
    shcore
    shell32
)

add_executable(visual_spike2_coordinate_model_tests
    src/coordinate_model_tests.cpp
    src/coordinate_model.h
)

target_compile_features(visual_spike2_coordinate_model_tests PRIVATE cxx_std_20)
target_compile_definitions(visual_spike2_coordinate_model_tests PRIVATE
    NOMINMAX
)
target_compile_options(visual_spike2_coordinate_model_tests PRIVATE
    /W4
    /permissive-
    /EHsc
)

add_test(NAME coordinate_model_tests COMMAND visual_spike2_coordinate_model_tests)

set_property(TARGET visual_spike2_coordinate_truth PROPERTY VS_DEBUGGER_WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}")
