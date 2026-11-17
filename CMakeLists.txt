# <min>...<max>: 3.12 is the first release that knows CXX_STANDARD 20;
# policies follow the newest release tested (4.4), or the running CMake if older.
cmake_minimum_required(VERSION 3.12...4.4)
# Catch uses noexcept
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

project(cmake_test)

# Prepare "Catch" library for other executables
set(CATCH_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/vendor/catch)
add_library(Catch INTERFACE)
target_include_directories(Catch INTERFACE ${CATCH_INCLUDE_DIR})

# Make test executable
set(TEST_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/test/pp_iter_test.cpp)
add_executable(tests ${TEST_SOURCES})
target_include_directories(tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(tests Catch)

# The macros need a conformant preprocessor (MSVC >= VS 2019 16.5).
# C5105 ("macro expansion producing 'defined' has undefined behavior") fires on
# PP_IS_GCC_EXTENDED and related feature macros in pp_iter.h.
target_compile_options(tests PRIVATE "$<$<CXX_COMPILER_ID:MSVC>:/Zc:preprocessor;/wd5105>")
