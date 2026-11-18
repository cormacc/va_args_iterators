# Fail if pp_iter.h differs from the output of pp_iterators.rb with the default limit.
# Usage: cmake -DRUBY=<ruby> -DSOURCE_DIR=<repository root> -DOUTPUT=<scratch file> -P check_header.cmake
execute_process(
  COMMAND "${RUBY}" "${SOURCE_DIR}/pp_iterators.rb"
  OUTPUT_FILE "${OUTPUT}"
  RESULT_VARIABLE generate_result)
if(NOT generate_result EQUAL 0)
  message(FATAL_ERROR "pp_iterators.rb failed: ${generate_result}")
endif()
execute_process(
  COMMAND "${CMAKE_COMMAND}" -E compare_files "${OUTPUT}" "${SOURCE_DIR}/pp_iter.h"
  RESULT_VARIABLE compare_result)
if(NOT compare_result EQUAL 0)
  message(FATAL_ERROR "pp_iter.h is out of date: run ./regenerate and commit the result")
endif()
