#define CATCH_CONFIG_MAIN  // This tells Catch to provide a main() - only do this in one cpp file
#include "catch.hpp"

// Module under test...
#include "pp_iter.h"

// Test includes
#include <string.h>

SCENARIO("PP_NARG") {
  GIVEN("should count no arguments") {
    REQUIRE( PP_NARG() == 0 );
  }

  GIVEN("should count non-zero arguments") {
    REQUIRE(13 == PP_NARG(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13));
  }

  //Upper limit...
  GIVEN("should count maximum arguments (64)") {
    REQUIRE(64 == PP_NARG(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
                          1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
                          1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
                          1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16)
      );
  }
}

static int accumulated_values[10];
static size_t calls;
static size_t sum;
void accumulate(int next)
{
  accumulated_values[calls++] = next;
  sum+=next;
}
#define ACC(A) accumulate(A);
#define STRINGIFY(A) char const A##_tag[] = #A;

SCENARIO("PP_EACH") {
  calls = sum = accumulated_values[0] = 0;
  GIVEN("wrapped function") {
    WHEN("no additional arguments specified") {
      PP_EACH(accumulate);

      THEN("no calls are made") {
        REQUIRE(calls==0);
      }
    }

    WHEN("3 additional arguments specified") {
      PP_EACH(ACC, 1, 2, 3);

      THEN("3 calls are made") {
        REQUIRE(calls==3);
      }

      THEN("arguments are passed in order") {
        REQUIRE(accumulated_values[0] == 1);
        REQUIRE(accumulated_values[1] == 2);
        REQUIRE(accumulated_values[2] == 3);
      }
    }
  }

  GIVEN("stringifying macro") {
    WHEN("applied") {
      PP_EACH(STRINGIFY, a, b, c);

      THEN("stringification occurs") {
        REQUIRE(strcmp("a", a_tag)==0);
        REQUIRE(strcmp("b", b_tag)==0);
        REQUIRE(strcmp("c", c_tag)==0);
      }
    }
  }
}

typedef struct {
  uint16_t arg0;
  uint16_t arg1;
  uint16_t arg2;
} test_struct;



SCENARIO("PP_EACH_IDX") {
  GIVEN("stringifying macro") {
#define TFEQ(ARG, ARG_IDX) REQUIRE(ARG == tested.arg##ARG_IDX);
    WHEN("applied") {
      test_struct tested = {.arg0 = 6, .arg1 = 5, .arg2 = 4};
      PP_EACH_IDX(TFEQ, 6, 5, 4);
      THEN("arg index stringifies as expected") {

      }
    }
  }
}


#define TFEQFIX(FIXED_ARG, ARG, ARG_IDX) REQUIRE(ARG == FIXED_ARG##ARG_IDX);
// #define TFEQFIX(FIXED_ARG, ARG, ARG_IDX) REQUIRE(ARG == CAT(FIXED_ARG, ARG_IDX));
SCENARIO("PP_PAR_EACH_IDX") {
  GIVEN("stringifying macro with 1 fixed argument") {
    WHEN("applied") {
      test_struct tested = {.arg0 = 6, .arg1 = 5, .arg2 = 4};
      PP_PAR_EACH_IDX(TFEQFIX, (tested.arg), 6, 5, 4);
      THEN("arg index stringifies as expected") {

      }
    }
  }

  GIVEN("stringifying macro with 2 fixed arguments") {
// #define TFEQFIX(FIXED_ARG, ARG, ARG_IDX) REQUIRE(ARG == FIXED_ARG##ARG_IDX);
#define TFEQ2FIX(FIXED_ARG1, FIXED_ARG2, ARG, ARG_IDX) REQUIRE(ARG == CAT(FIXED_ARG1, ARG_IDX));
    WHEN("applied") {
      test_struct tested = {.arg0 = 6, .arg1 = 5, .arg2 = 4};
      PP_PAR_EACH_IDX(TFEQ2FIX, (tested.arg, bla), 6, 5, 4);
      THEN("arg index stringifies as expected") {

      }
    }
  }
}

// SCENARIO("PP_1PAR_EACH_IDX") {
//   GIVEN("stringifying macro") {
// #define TFEQFIX(FIXED_ARG, ARG, ARG_IDX) REQUIRE(ARG == FIXED_ARG##ARG_IDX);
//     WHEN("applied") {
//       test_struct tested = {.arg0 = 6, .arg1 = 5, .arg2 = 4};
//       PP_1PAR_EACH_IDX(TFEQFIX, tested.arg, 6, 5, 4);
//       THEN("arg index stringifies as expected") {

//       }
//     }
//   }
// }
