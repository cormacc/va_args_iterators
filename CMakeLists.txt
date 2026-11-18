# <min>...<max>: 3.21 is the first release with CMakePresets.json version 3 (no generator needed);
# policies follow the newest release tested (4.4), or the running CMake if older.
cmake_minimum_required(VERSION 3.21...4.4)

project(va_args_iterators LANGUAGES C CXX)

enable_testing()

# The macros need __VA_OPT__, which MSVC supports only with its conformant
# preprocessor (VS 2019 16.5 or later): see the /Zc:preprocessor options below.

# Catch2 single-header library
add_library(Catch INTERFACE)
target_include_directories(Catch INTERFACE ${CMAKE_CURRENT_SOURCE_DIR}/vendor/catch)

# C++ unit tests. C++20 for the designated initialisers in test/pp_iter_test.cpp.
add_executable(tests
    test/pp_iter_test.cpp
    test/pp_enum_test.cpp)
set_target_properties(tests PROPERTIES CXX_STANDARD 20 CXX_STANDARD_REQUIRED ON)
target_include_directories(tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(tests Catch)
target_compile_options(tests PRIVATE "$<$<CXX_COMPILER_ID:MSVC>:/Zc:preprocessor>")
add_test(NAME tests COMMAND tests)

# C test, as strict C99 without GNU extensions: the headers are used from C on embedded targets.
add_executable(c_tests test/pp_c_test.c)
set_target_properties(c_tests PROPERTIES C_STANDARD 99 C_STANDARD_REQUIRED ON C_EXTENSIONS OFF)
target_include_directories(c_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
target_compile_options(c_tests PRIVATE "$<$<C_COMPILER_ID:MSVC>:/Zc:preprocessor>")
add_test(NAME c_tests COMMAND c_tests)

# The committed pp_iter.h must match the generator output. Needs Ruby (provided by the Nix devShell).
find_program(RUBY ruby)
if(RUBY)
  add_test(NAME header_up_to_date
           COMMAND ${CMAKE_COMMAND} -DRUBY=${RUBY} -DSOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}
                   -DOUTPUT=${CMAKE_CURRENT_BINARY_DIR}/pp_iter.generated.h
                   -P ${CMAKE_CURRENT_SOURCE_DIR}/test/check_header.cmake)
endif()
