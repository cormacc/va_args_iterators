/**
 * @file
 *
 * Tagged Enum - automated generation of string tags associated with enum members
 *
 * @author Cormac Cannon (cormacc-public@gmail.com)
 *
 * These macros are used to generate enums and associated tags without repetition, e.g.
 *
 * 1. Define the unique names in a new macro
 * #define MyEnumTags NAME_1, NAME_2, NAME_3
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
 * The header will declare the function ~char const * MyEnum_asCString(int)~
 * The source file will define an array of strings using the defined MyEnumTags and
 * the implementation of ~char const * MyEnum_asCString(int)~
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

#define PP_I_ENUM_TAG(NAME) #NAME,

#define PP_I_ENUM_DESCRIPTOR_DECLARATION(NAME)           \
  char const * NAME##_asCString(int id)

#define PP_I_ENUM_DESCRIPTOR_DEFINITION(NAME)                                    \
  PP_I_ENUM_DESCRIPTOR_DECLARATION(NAME) { return (unsigned)id < (unsigned)NAME##_COUNT ? NAME##_TAGS[id] : ENUM_UNDEFINED_TAG; }

#define PP_I_ENUM(NAME) enum NAME { NAME##Tags , NAME##_COUNT }
#define PP_I_ENUM_TYPE(NAME) typedef enum { NAME##Tags , NAME##_COUNT } NAME

#define TAGGED_ENUM(NAME)                       \
  PP_I_ENUM(NAME);                                   \
  PP_I_ENUM_DESCRIPTOR_DECLARATION(NAME)

#define TAGGED_ENUM_TYPE(NAME)                       \
  PP_I_ENUM_TYPE(NAME);                                   \
  PP_I_ENUM_DESCRIPTOR_DECLARATION(NAME)

// Indirection necessary to expand NAME##Tags
#define PP_I_ENUM_TAGS_EXPAND(IDS) PP_EACH(PP_I_ENUM_TAG, IDS)
#define PP_I_ENUM_TAGS_AUTO(NAME)                         \
  static char const * NAME##_TAGS[] = {         \
    PP_I_ENUM_TAGS_EXPAND(NAME##Tags)                      \
  }

//Explicit array size used here to keep us honest -- i.e. ensure
// number of tags provided matches enum member count....
#define PP_I_ENUM_TAGS_EXPLICIT(NAME, ...)               \
  static char const * NAME##_TAGS[NAME##_COUNT] = { \
    __VA_ARGS__                                     \
  }

#define ENUM_DESCRIBE(NAME)                          \
  PP_I_ENUM_TAGS_AUTO(NAME);                              \
  PP_I_ENUM_DESCRIPTOR_DEFINITION(NAME)

#define ENUM_DESCRIBE_EXPLICIT(NAME, ...)    \
  PP_I_ENUM_TAGS_EXPLICIT(NAME, __VA_ARGS__);     \
  PP_I_ENUM_DESCRIPTOR_DEFINITION(NAME)

#endif  /* PP_ENUM_H */
