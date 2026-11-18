/**
 * @file
 *
 * Tagged Enum - automated generation of string tags associated with enum members
 *
 * @author Cormac Cannon (cormacc-public@gmail.com)
 *
 * These macros are used to generate enums and associated tags without repetition, e.g.
 *
 * 1. Define the member identifiers in a new macro, named <Name>IDs
 * #define MyEnumIDs NAME_1, NAME_2, NAME_3
 *
 * 2. Create the enum (In the .h, typically)
 * TAGGED_ENUM(MyEnum);
 *    ... or, for a typedeffed enum ...
 * TAGGED_ENUM_TYPE(MyEnum);
 *
 * 3. Create the tags (In the .c, typically)
 * ENUM_DESCRIBE(MyEnum);
 *
 * The defined enum / enum type will include a `<Name>_COUNT` member.
 * The header will declare the functions
 *   char const * MyEnum_asCString(int id)          -- the tag of a member, or ENUM_UNDEFINED_TAG
 *   int MyEnum_fromCString(char const * tag)       -- the member with that tag, or ENUM_UNKNOWN(MyEnum)
 * The source file will define an array of strings using the defined MyEnumIDs and
 * the implementations of both functions. MyEnum_fromCString uses strcmp from <string.h>.
 *
 * ENUM(MyEnum) and ENUM_TYPE(MyEnum) create the enum without the functions.
 *
 * EXTENSION -- extended enums
 * ENUM_EXTEND(MyEnum, MyExtEnum) (or TAGGED_ENUM_EXTEND, ENUM_TYPE_EXTEND, TAGGED_ENUM_TYPE_EXTEND)
 * creates an enum whose members, from MyExtEnumIDs, continue after MyEnum_COUNT.
 * EXTENDED_ENUM_DESCRIBE(MyEnum, MyExtEnum) defines MyExtEnum_asCString and
 * MyExtEnum_fromCString, which also cover the members of MyEnum.
 *
 * EXTENSION -- enumerated arrays
 * the ENUMERATED_ARRAY(MyEnum) macro can be used to generate an array with elements linked to
 * the defined enum IDs
 * e.g.
 *
 * This:
 * @code{.c}
 * static MyStructType ELNAME(NAME_1) = {.some_member = 1};
 * static MyStructType ELNAME(NAME_2) = {.some_member = 2};
 * static MyStructType ELNAME(NAME_3) = {.some_member = 3};
 * static MyStructType * const THE_ARRAY[] = ENUMERATED_ARRAY(MyEnum);
 * @endcode
 *
 * ... is equivalent to this:
 * @code{.c}
 * static MyStructType NAME_1_ = {.some_member = 1};
 * static MyStructType NAME_2_ = {.some_member = 2};
 * static MyStructType NAME_3_ = {.some_member = 3};
 * static MyStructType * const THE_ARRAY[] = {
 *      &NAME_1_,
 *      &NAME_2_,
 *      &NAME_3_,
 * };
 * @endcode
 *
 * ENUMERATED_ARRAY_CAST(MyEnum, T) does the same with each element pointer cast to T.
 * This is useful for larger arrays, as it eliminates the need to manually keep the enum IDs and
 * array elements in sync, which is easily forgotten as the number of elements changes over time -
 * particularly if the enum is defined in a header and array in the corresponding source file.
 *
 * N.B. Tag generation uses PP_EACH from "pp_iter.h", so an enum can have at most as many
 * members as that header's argument limit. See that file for a link to the generator script if a
 * higher limit is required. A generated header included first takes precedence over this include,
 * as they use the same guard definition -- i.e
 * #include "pp_iter512.h"
 * #include "pp_enum.h"
 */

#ifndef PP_ENUM_H
#  define PP_ENUM_H

// GCC and Clang: treat this as a system header. In strict modes (e.g. -std=c99 -pedantic), each
// use of the macros otherwise warns about __VA_OPT__ and about variadic macros called with no
// variadic arguments. Warnings from the arguments that you pass to the macros are still reported.
#  if defined(__GNUC__)
#    pragma GCC system_header
#  endif

// ----------------------------------------------------------------------------
// Includes
// ----------------------------------------------------------------------------
#include "pp_iter.h"
#include <string.h>   // strcmp, for <Name>_fromCString

// ----------------------------------------------------------------------------
// Macros
// ----------------------------------------------------------------------------

/**
 * Override this with another string literal
 * Alternatively, override with an external string constant to save a few bytes per tagged enum
 *
 * e.g. in 'my_tagged_enum.h'
 *
 *      extern char const GLOBAL_ENUM_UNDEFINED_TAG[];
 *      #define ENUM_UNDEFINED_TAG GLOBAL_ENUM_UNDEFINED_TAG
 *      #include "pp_enum.h"
 *
 * and in 'my_tagged_enum.c'
 *
 *      char const GLOBAL_ENUM_UNDEFINED_TAG[] = "N.A."; //or, in the immortal words of Seamus Ennis, 'Whateveryouplays, sur'
 */
#ifndef ENUM_UNDEFINED_TAG
#define ENUM_UNDEFINED_TAG "UNDEFINED"
#endif

// Member count, highest member, and the value that <Name>_fromCString returns for an unknown tag
#define ENUM_COUNT(NAME) NAME##_COUNT
#define ENUM_MAX(NAME) (NAME##_COUNT - 1)
#define ENUM_UNKNOWN(NAME) ENUM_COUNT(NAME)

// The names of the generated functions, e.g. to pass the descriptor as a function pointer
#define ENUM_DESCRIPTOR(NAME) NAME##_asCString
#define ENUM_DECODER(NAME) NAME##_fromCString

#define PP_I_ENUM_TAG(NAME) #NAME,

#define PP_I_ENUM_DESCRIPTOR_DECLARATION(NAME)           \
  char const * ENUM_DESCRIPTOR(NAME)(int id)

// The unsigned comparison also rejects a negative id
#define PP_I_ENUM_DESCRIPTOR_DEFINITION(NAME)                                    \
  PP_I_ENUM_DESCRIPTOR_DECLARATION(NAME) { return (unsigned)id < (unsigned)NAME##_COUNT ? NAME##_TAGS[id] : ENUM_UNDEFINED_TAG; }

#define PP_I_EXTENDED_ENUM_DESCRIPTOR_DEFINITION(BASE, EXTENDED)                        \
  PP_I_ENUM_DESCRIPTOR_DECLARATION(EXTENDED) {                                          \
    if ((unsigned)id < (unsigned)BASE##_COUNT) { return ENUM_DESCRIPTOR(BASE)(id); }    \
    return (unsigned)id < (unsigned)EXTENDED##_COUNT ? EXTENDED##_TAGS[id - BASE##_COUNT] \
                                                     : ENUM_UNDEFINED_TAG;              \
  }

#define PP_I_ENUM_DECODER_DECLARATION(NAME)            \
  int ENUM_DECODER(NAME)(char const * tag)

#define PP_I_ENUM_DECODER_DEFINITION(NAME)                         \
  PP_I_ENUM_DECODER_DECLARATION(NAME) {                            \
    int id = 0;                                                    \
    while (id < ENUM_COUNT(NAME)) {                                \
      if (strcmp(tag, ENUM_DESCRIPTOR(NAME)(id)) == 0) {           \
        return id;                                                 \
      }                                                            \
      id++;                                                        \
    }                                                              \
    return ENUM_UNKNOWN(NAME);                                     \
  }

/**
 * Iterate over each member of an enum defined using these macros
 *
 * @param NAME Enum name
 * @param ITER Name of a local iterator (int) to be referenced within loop
 * @param __VA_ARGS__ One or more operations to be performed per iteration
 */
#define ENUM_EACH(NAME, ITER, ...) {                                    \
    int ITER = 0;                                                       \
    while (ITER < ENUM_COUNT(NAME)) {                                   \
      __VA_ARGS__;                                                      \
      ITER++;                                                           \
    }                                                                   \
  }

#define ENUM(NAME) enum NAME { NAME##IDs , ENUM_COUNT(NAME) }
#define ENUM_TYPE(NAME) typedef ENUM(NAME) NAME

// Indirection necessary to expand EXTENDED##IDs. __VA_OPT__ drops the comma after a single member.
#define PP_I_ENUM_EXTEND_MEMBERS(BASE, FIRST, ...) FIRST = ENUM_COUNT(BASE), __VA_ARGS__ __VA_OPT__(,)
#define PP_I_ENUM_EXTEND(BASE, EXTENDED, ...) \
  enum EXTENDED { PP_I_ENUM_EXTEND_MEMBERS(BASE, __VA_ARGS__) ENUM_COUNT(EXTENDED) }
#define ENUM_EXTEND(BASE, EXTENDED) PP_I_ENUM_EXTEND(BASE, EXTENDED, EXTENDED##IDs)
#define ENUM_TYPE_EXTEND(BASE, EXTENDED) typedef ENUM_EXTEND(BASE, EXTENDED) EXTENDED

#define TAGGED_ENUM(NAME)                       \
  ENUM(NAME);                                   \
  PP_I_ENUM_DESCRIPTOR_DECLARATION(NAME);       \
  PP_I_ENUM_DECODER_DECLARATION(NAME)

#define TAGGED_ENUM_TYPE(NAME)                  \
  ENUM_TYPE(NAME);                              \
  PP_I_ENUM_DESCRIPTOR_DECLARATION(NAME);       \
  PP_I_ENUM_DECODER_DECLARATION(NAME)

#define TAGGED_ENUM_EXTEND(BASE, EXTENDED)      \
  ENUM_EXTEND(BASE, EXTENDED);                  \
  PP_I_ENUM_DESCRIPTOR_DECLARATION(EXTENDED);   \
  PP_I_ENUM_DECODER_DECLARATION(EXTENDED)

#define TAGGED_ENUM_TYPE_EXTEND(BASE, EXTENDED) \
  ENUM_TYPE_EXTEND(BASE, EXTENDED);             \
  PP_I_ENUM_DESCRIPTOR_DECLARATION(EXTENDED);   \
  PP_I_ENUM_DECODER_DECLARATION(EXTENDED)

// Indirection necessary to expand NAME##IDs
#define PP_I_ENUM_TAGS_EXPAND(IDS) PP_EACH(PP_I_ENUM_TAG, IDS)
#define ENUM_TAGS_AUTO(NAME)                         \
  static char const * NAME##_TAGS[] = {              \
    PP_I_ENUM_TAGS_EXPAND(NAME##IDs)                 \
  }

//Explicit array size used here to keep us honest -- i.e. ensure
// number of tags provided matches enum member count....
#define ENUM_TAGS_EXPLICIT(NAME, ...)                \
  static char const * NAME##_TAGS[NAME##_COUNT] = {  \
    __VA_ARGS__                                      \
  }

#define ENUM_DESCRIBE(NAME)                          \
  ENUM_TAGS_AUTO(NAME);                              \
  PP_I_ENUM_DESCRIPTOR_DEFINITION(NAME);             \
  PP_I_ENUM_DECODER_DEFINITION(NAME)

#define ENUM_DESCRIBE_EXPLICIT(NAME, ...)            \
  ENUM_TAGS_EXPLICIT(NAME, __VA_ARGS__);             \
  PP_I_ENUM_DESCRIPTOR_DEFINITION(NAME);             \
  PP_I_ENUM_DECODER_DEFINITION(NAME)

#define EXTENDED_ENUM_DESCRIBE(BASE, EXTENDED)                 \
  ENUM_TAGS_AUTO(EXTENDED);                                    \
  PP_I_EXTENDED_ENUM_DESCRIPTOR_DEFINITION(BASE, EXTENDED);    \
  PP_I_ENUM_DECODER_DEFINITION(EXTENDED)

// Arrays with elements mapped to enum members
#define ELNAME(ELID) ELID##_
#define PP_I_ENUMARR_MEMBER(ELID) &ELNAME(ELID),
// Indirection necessary to expand NAME##IDs
#define PP_I_ENUMARR(IDS) PP_EACH(PP_I_ENUMARR_MEMBER, IDS)
#define ENUMERATED_ARRAY(NAME)                  \
  {                                             \
    PP_I_ENUMARR(NAME##IDs)                     \
  }

#define PP_I_ENUMARR_MEMBER_CAST(T, ID, IDX) (T)(&ELNAME(ID)),
#define PP_I_ENUMARR_CAST(T, IDS) PP_PAR_EACH_IDX(PP_I_ENUMARR_MEMBER_CAST, (T), IDS)
#define ENUMERATED_ARRAY_CAST(NAME, T)          \
  {                                             \
    PP_I_ENUMARR_CAST(T, NAME##IDs)             \
  }

#endif  /* PP_ENUM_H */
