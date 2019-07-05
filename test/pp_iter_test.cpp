#define CATCH_CONFIG_MAIN  // This tells Catch to provide a main() - only do this in one cpp file
#include "catch.hpp"

// Module under test...
#include "pp_iter.h"

// Test includes
#include <string.h>

SCENARIO("NOT") {
  GIVEN("should evaluate to 1 given 0") {
    REQUIRE( NOT(0) == 1 );
  }

  GIVEN("should evaluate to 0 given 1") {
    REQUIRE( NOT(1) == 0 );
  }

  GIVEN("should evaluate to 0 given >1") {
    REQUIRE( NOT(9) == 0 );
  }

#define _INDIRECT(x) x
  GIVEN("should evaluate to 1 given indirect 0") {
    REQUIRE( NOT(_INDIRECT(0)) == 1 );
  }

  GIVEN("should evaluate to 0 given indirect 1") {
    REQUIRE( NOT(_INDIRECT(1)) == 0 );
  }

  GIVEN("should evaluate to 0 given indirect >1") {
    REQUIRE( NOT(_INDIRECT(9)) == 0 );
  }

  GIVEN("should handle counting 0 args") {
    REQUIRE( NOT(PP_NARG()) == 1 );
  }

  GIVEN("should handle counting multiple args") {
    REQUIRE( NOT(PP_NARG(1, 2, 3)) == 0 );
  }
}

SCENARIO("NOT_EMPTY") {
  GIVEN("should evaluate to 0 given no args") {
    REQUIRE( NOT_EMPTY() == 0 );
  }

  GIVEN("should evaluate to 1 given 1 arg") {
    REQUIRE( NOT_EMPTY(3) == 1 );
  }

  GIVEN("should evaluate to 1 given multiple args") {
    REQUIRE( NOT_EMPTY(3, b, 4) == 1 );
  }

  GIVEN("should evaluate to 1 given quoted arg") {
    REQUIRE( NOT_EMPTY('a') == 1 );
  }
}

SCENARIO("IS_EMPTY") {
  GIVEN("should evaluate to 1 given no args") {
    REQUIRE( IS_EMPTY() == 1 );
  }

  GIVEN("should evaluate to 0 given 1 arg") {
    REQUIRE( IS_EMPTY(3) == 0 );
  }

  GIVEN("should evaluate to 0 given multiple arg") {
    REQUIRE( IS_EMPTY(3, b, 4) == 0 );
  }

  GIVEN("should evaluate to 0 given quoted arg") {
    REQUIRE( IS_EMPTY('a') == 0 );
  }
}

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

static int accumulated_values[256];
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

    WHEN("256 arguments specified") {
      PP_EACH(ACC,
              1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32,
              1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32,
              1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32,
              1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32,

              1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32,
              1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32,
              1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32,
              1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32
        )

      THEN("256 calls are made") {
        REQUIRE(calls==256);
      }

      THEN("arguments are passed in order") {
        REQUIRE(accumulated_values[0] == 1);
        REQUIRE(accumulated_values[255] == 32);
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

  GIVEN("quoted parameters") {
    WHEN("single quoted") {
#define CACHE_CHAR(A) chars[i++] = A;
      char chars[3];
      int i = 0;
      PP_EACH(CACHE_CHAR, 'a', 'b', 'c');
      THEN("chars handled successfully") {
        REQUIRE(i==3);
        REQUIRE(chars[0]=='a');
        REQUIRE(chars[1]=='b');
        REQUIRE(chars[2]=='c');
      }
    }
    WHEN("double quoted") {
#define CACHE_INITIAL(A) chars[i++] = A[0];
      char chars[3];
      int i = 0;
      PP_EACH(CACHE_INITIAL, "a", "b", "c");
      THEN("chars handled successfully") {
        REQUIRE(i==3);
        REQUIRE(chars[0]=='a');
        REQUIRE(chars[1]=='b');
        REQUIRE(chars[2]=='c');
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

  GIVEN("quoted parameters") {
    WHEN("single quoted") {
#define CACHE_CHAR_AT_IDX(A, IDX) chars[IDX] = A;
      char chars[3];
      PP_EACH_IDX(CACHE_CHAR_AT_IDX, 'a', 'b', 'c');
      THEN("chars handled successfully") {
        REQUIRE(chars[0]=='a');
        REQUIRE(chars[1]=='b');
        REQUIRE(chars[2]=='c');
      }
    }
    WHEN("double quoted") {
#define CACHE_INITIAL_AT_IDX(A, IDX) chars[IDX] = A[0];
      char chars[3];
      PP_EACH_IDX(CACHE_INITIAL_AT_IDX, "a", "b", "c");
      THEN("chars handled successfully") {
        REQUIRE(chars[0]=='a');
        REQUIRE(chars[1]=='b');
        REQUIRE(chars[2]=='c');
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
#define TFEQ2FIX(FIXED_ARG1, FIXED_ARG2, ARG, ARG_IDX) REQUIRE(ARG*FIXED_ARG1 == FIXED_ARG2##ARG_IDX);
    WHEN("applied") {
      test_struct tested = {.arg0 = 6, .arg1 = 4, .arg2 = 2};
      PP_PAR_EACH_IDX(TFEQ2FIX, (2, tested.arg), 3, 2, 1);
      THEN("arg index stringifies as expected") {

      }
    }
  }

  GIVEN("stringifying macro with 1 unparenthesised argument") {
    WHEN("applied") {
      test_struct tested = {.arg0 = 6, .arg1 = 5, .arg2 = 4};
      PP_PAR_EACH_IDX(TFEQFIX, tested.arg, 6, 5, 4);
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
