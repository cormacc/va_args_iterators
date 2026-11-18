/*
 * C test for pp_iter.h and pp_enum.h. The Catch tests compile as C++; this file checks that
 * the headers also work in C. CMakeLists.txt builds it as strict C99 (no GNU extensions),
 * the oldest C standard that the target compilers (e.g. Microchip XC-DSC) use.
 *
 * Compile-time checks use CHECK, which declares an array with a negative size on failure.
 * Run-time checks set a non-zero exit status.
 */
#include <stdio.h>
#include <string.h>

#include "pp_iter.h"
#include "pp_enum.h"

#define CHECK(name, cond) typedef char check_##name[(cond) ? 1 : -1];

CHECK(has_va_opt, PP_HAS_VA_OPT == 1)
CHECK(narg_0, PP_NARG() == 0)
CHECK(narg_1, PP_NARG(a) == 1)
CHECK(narg_3, PP_NARG(a, b, c) == 3)
CHECK(narg_63, PP_NARG(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,
                       1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15) == 63)
CHECK(is_empty_0, PP_IS_EMPTY() == 1)
CHECK(is_empty_1, PP_IS_EMPTY(x) == 0)
CHECK(not_empty_3, PP_NOT_EMPTY(a, b, c) == 1)

#define DECL(A) static int A = 1;
PP_EACH(DECL, each_a, each_b, each_c)
PP_EACH(DECL)

#define DECL_IDX(A, IDX) static int A##_##IDX = IDX;
PP_EACH_IDX(DECL_IDX, idx_a, idx_b)

#define DECL_PAR(T, A, IDX) static T A##_##IDX = IDX;
PP_PAR_EACH_IDX(DECL_PAR, (long), par_a, par_b)

static int sum3(int a, int b, int c) { return a + b + c; }
#define ID(A) A

#define ColourTags RED, GREEN, BLUE
TAGGED_ENUM(Colour);
ENUM_DESCRIBE(Colour);
CHECK(enum_count, Colour_COUNT == 3)

static int failures = 0;
static void expect(int ok, const char *what) {
  if (!ok) { printf("FAILED: %s\n", what); failures++; }
}

int main(void) {
  expect(each_a + each_b + each_c == 3, "PP_EACH declares each argument");
  expect(idx_a_0 == 0 && idx_b_1 == 1, "PP_EACH_IDX passes 0-based indices");
  expect(par_a_0 == 0 && par_b_1 == 1, "PP_PAR_EACH_IDX passes the fixed argument and indices");
  expect(sum3(PP_COMMA_EACH(ID, 1, 2, 3)) == 6, "PP_COMMA_EACH separates results with commas");
  expect(strcmp(Colour_asCString(GREEN), "GREEN") == 0, "ENUM_DESCRIBE tags");
  expect(strcmp(Colour_asCString(Colour_COUNT), ENUM_UNDEFINED_TAG) == 0, "upper bound");
  expect(strcmp(Colour_asCString(-1), ENUM_UNDEFINED_TAG) == 0, "negative id");
  if (failures == 0) printf("All C checks passed\n");
  return failures != 0;
}
