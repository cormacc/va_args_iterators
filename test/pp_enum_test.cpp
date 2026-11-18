#include "catch.hpp"

// Module under test...
#include "pp_enum.h"

// Test includes
#include <string.h>

#define PiperIDs                                \
  WILLIE_CLANCY,                                \
  SEAMUS_ENNIS,                                 \
  TOMMY_RECK

TAGGED_ENUM(Piper);
ENUM_DESCRIBE(Piper);

#define FluteIDs                                \
  MATT_MOLLOY,                                  \
  CATHAL_MCCONNELL

TAGGED_ENUM_TYPE(Flute);
ENUM_DESCRIBE_EXPLICIT(Flute,
                       "Matt Molloy",
                       "Cathal McConnell");

#define FiddlerIDs                              \
  TOMMY_PEOPLES,                                \
  MARTIN_HAYES

TAGGED_ENUM_TYPE_EXTEND(Piper, Fiddler);
EXTENDED_ENUM_DESCRIBE(Piper, Fiddler);

#define SingerIDs JOE_HEANEY

TAGGED_ENUM_EXTEND(Piper, Singer);
EXTENDED_ENUM_DESCRIBE(Piper, Singer);

static int WILLIE_CLANCY_ = 1922, SEAMUS_ENNIS_ = 1919, TOMMY_RECK_ = 1921;
static int * const PIPER_BORN[] = ENUMERATED_ARRAY(Piper);
static void const * const PIPER_BORN_ANY[] = ENUMERATED_ARRAY_CAST(Piper, void const *);

SCENARIO("TAGGED_ENUM with ENUM_DESCRIBE") {
  GIVEN("an untyped enum with automatic tags") {
    THEN("members are numbered in order and counted") {
      REQUIRE(WILLIE_CLANCY == 0);
      REQUIRE(TOMMY_RECK == 2);
      REQUIRE(Piper_COUNT == 3);
      REQUIRE(ENUM_COUNT(Piper) == 3);
      REQUIRE(ENUM_MAX(Piper) == TOMMY_RECK);
    }

    THEN("each member's tag is its name") {
      REQUIRE(strcmp(Piper_asCString(WILLIE_CLANCY), "WILLIE_CLANCY") == 0);
      REQUIRE(strcmp(Piper_asCString(SEAMUS_ENNIS), "SEAMUS_ENNIS") == 0);
      REQUIRE(strcmp(Piper_asCString(TOMMY_RECK), "TOMMY_RECK") == 0);
    }

    THEN("an out-of-range id gives ENUM_UNDEFINED_TAG") {
      REQUIRE(strcmp(Piper_asCString(Piper_COUNT), ENUM_UNDEFINED_TAG) == 0);
      REQUIRE(strcmp(Piper_asCString(-1), ENUM_UNDEFINED_TAG) == 0);
    }

    THEN("fromCString finds a member by its tag") {
      REQUIRE(Piper_fromCString("SEAMUS_ENNIS") == SEAMUS_ENNIS);
      REQUIRE(Piper_fromCString("JOHNNY_DORAN") == ENUM_UNKNOWN(Piper));
    }

    THEN("ENUM_DESCRIPTOR names the descriptor function") {
      char const * (*descriptor)(int) = ENUM_DESCRIPTOR(Piper);
      REQUIRE(strcmp(descriptor(TOMMY_RECK), "TOMMY_RECK") == 0);
    }

    THEN("ENUM_EACH visits each member once, in order") {
      int visited = 0;
      ENUM_EACH(Piper, id, visited = visited * 10 + id + 1)
      REQUIRE(visited == 123);
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

    THEN("fromCString matches the explicit string") {
      REQUIRE(Flute_fromCString("Matt Molloy") == MATT_MOLLOY);
      REQUIRE(Flute_fromCString("MATT_MOLLOY") == ENUM_UNKNOWN(Flute));
    }
  }
}

SCENARIO("Extended enums") {
  GIVEN("a typed extension with two members") {
    THEN("its members continue after the base") {
      REQUIRE(TOMMY_PEOPLES == Piper_COUNT);
      REQUIRE(MARTIN_HAYES == Piper_COUNT + 1);
      REQUIRE(Fiddler_COUNT == Piper_COUNT + 2);
    }

    THEN("its descriptor and decoder cover the base and the extension") {
      REQUIRE(strcmp(Fiddler_asCString(SEAMUS_ENNIS), "SEAMUS_ENNIS") == 0);
      REQUIRE(strcmp(Fiddler_asCString(MARTIN_HAYES), "MARTIN_HAYES") == 0);
      REQUIRE(strcmp(Fiddler_asCString(Fiddler_COUNT), ENUM_UNDEFINED_TAG) == 0);
      REQUIRE(strcmp(Fiddler_asCString(-1), ENUM_UNDEFINED_TAG) == 0);
      REQUIRE(Fiddler_fromCString("WILLIE_CLANCY") == WILLIE_CLANCY);
      REQUIRE(Fiddler_fromCString("TOMMY_PEOPLES") == TOMMY_PEOPLES);
      REQUIRE(Fiddler_fromCString("JOE_COOLEY") == ENUM_UNKNOWN(Fiddler));
    }
  }

  GIVEN("an untyped extension with one member") {
    THEN("it has one member after the base") {
      REQUIRE(JOE_HEANEY == Piper_COUNT);
      REQUIRE(Singer_COUNT == Piper_COUNT + 1);
      REQUIRE(strcmp(Singer_asCString(JOE_HEANEY), "JOE_HEANEY") == 0);
    }
  }
}

SCENARIO("Enumerated arrays") {
  GIVEN("an element for each member, named with ELNAME") {
    THEN("ENUMERATED_ARRAY holds their addresses in member order") {
      REQUIRE(sizeof(PIPER_BORN) / sizeof(PIPER_BORN[0]) == Piper_COUNT);
      REQUIRE(*PIPER_BORN[SEAMUS_ENNIS] == 1919);
    }

    THEN("ENUMERATED_ARRAY_CAST casts each address") {
      REQUIRE(PIPER_BORN_ANY[TOMMY_RECK] == static_cast<void const *>(&TOMMY_RECK_));
    }
  }
}
