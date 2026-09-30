cmake_minimum_required(VERSION 3.20)
project(VisualSpike4ViewportPolicy LANGUAGES CXX)

enable_testing()

add_executable(visual_spike4_viewport_policy_tests
    src/viewport_policy_tests.cpp
    src/viewport_policy.h
)

target_compile_features(visual_spike4_viewport_policy_tests PRIVATE cxx_std_20)
target_compile_definitions(visual_spike4_viewport_policy_tests PRIVATE NOMINMAX)
target_compile_options(visual_spike4_viewport_policy_tests PRIVATE /W4 /permissive- /EHsc)

add_test(NAME viewport_policy_tests COMMAND visual_spike4_viewport_policy_tests)
