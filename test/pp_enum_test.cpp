#include "catch.hpp"

// Module under test...
#include "pp_enum.h"

// Test includes
#include <string.h>

#define PiperTags                               \
  WILLIE_CLANCY,                                \
  SEAMUS_ENNIS,                                 \
  TOMMY_RECK

TAGGED_ENUM(Piper);
ENUM_DESCRIBE(Piper);

#define FluteTags                               \
  MATT_MOLLOY,                                  \
  CATHAL_MCCONNELL

TAGGED_ENUM_TYPE(Flute);
ENUM_DESCRIBE_EXPLICIT(Flute,
                       "Matt Molloy",
                       "Cathal McConnell");

SCENARIO("TAGGED_ENUM with ENUM_DESCRIBE") {
  GIVEN("an untyped enum with automatic tags") {
    THEN("members are numbered in order and counted") {
      REQUIRE(WILLIE_CLANCY == 0);
      REQUIRE(TOMMY_RECK == 2);
      REQUIRE(Piper_COUNT == 3);
    }

    THEN("each member's tag is its name") {
      REQUIRE(strcmp(Piper_asCString(WILLIE_CLANCY), "WILLIE_CLANCY") == 0);
      REQUIRE(strcmp(Piper_asCString(SEAMUS_ENNIS), "SEAMUS_ENNIS") == 0);
      REQUIRE(strcmp(Piper_asCString(TOMMY_RECK), "TOMMY_RECK") == 0);
    }

    THEN("an out-of-range id gives ENUM_UNDEFINED_TAG") {
      REQUIRE(strcmp(Piper_asCString(Piper_COUNT), ENUM_UNDEFINED_TAG) == 0);
    }
  }
}

SCENARIO("TAGGED_ENUM_TYPE with ENUM_DESCRIBE_EXPLICIT") {
  GIVEN("a typedef enum with explicit tags") {
    Flute flute = CATHAL_MCCONNELL;

    THEN("members are counted") {
      REQUIRE(Flute_COUNT == 2);
    }

    THEN("each member's tag is the explicit string") {
      REQUIRE(strcmp(Flute_asCString(MATT_MOLLOY), "Matt Molloy") == 0);
      REQUIRE(strcmp(Flute_asCString(flute), "Cathal McConnell") == 0);
    }
  }
}
