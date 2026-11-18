/*
 * Test of the embedding mode (embed_macros(require_va_opt: false) after va_opt_probe), with the
 * host header that test/embed_host.rb generates. CMakeLists.txt builds this file twice, as C99:
 *
 * - embed_tests: EXPECT_PP_MACROS=1. The embedded macros work, and a later standalone pp_iter.h
 *   deduplicates with them through the PP_*_H include guards.
 * - embed_tests_no_va_opt: EXPECT_PP_MACROS=0 and PP_HAS_VA_OPT=0, as on a preprocessor without
 *   __VA_OPT__. The host header compiles, and none of the embedded macros is defined.
 */
#include <stdio.h>

#include "embed_host.h"

#define CHECK(name, cond) typedef char check_##name[(cond) ? 1 : -1];

CHECK(host_core, HOST_CORE_VALUE == 42)

#if EXPECT_PP_MACROS

/* Check the embedded copy before the standalone header, which would define the macros itself. */
#if !defined(PP_NARG) || !defined(PP_EACH) || !defined(PP_PAR_EACH_IDX) || !defined(PP_HEAD)
#  error "the embedded macros should be defined when PP_HAS_VA_OPT is 1"
#endif

CHECK(has_va_opt, PP_HAS_VA_OPT == 1)
CHECK(narg_0, PP_NARG() == 0)
CHECK(narg_3, PP_NARG(a, b, c) == 3)
CHECK(is_empty, PP_IS_EMPTY() == 1)
CHECK(head, PP_HEAD(7, 8) == 7)

#define DECL(A) static int A = 1;
PP_EACH(DECL, each_a, each_b)

#define DECL_PAR(T, A, IDX) static T A##_##IDX = IDX;
PP_PAR_EACH_IDX(DECL_PAR, (long), par_a, par_b)

/* The embedded copy defines the include guards that the standalone pp_iter.h tests, so a later
   standalone header skips each group. (Its definitions are identical, so a redefinition would be
   legal and silent: check the guard names instead.) */
#if !defined(PP_UTIL_H) || !defined(PP_NARG_H) || !defined(PP_DEFER_H) || !defined(PP_EVAL_H) \
  || !defined(PP_CAT_H) || !defined(PP_LOGIC_H) || !defined(PP_LISTS_H) || !defined(PP_TUPLES_H) \
  || !defined(PP_EACH_H) || !defined(PP_EACH_IDX_H) || !defined(PP_PAR_EACH_IDX_H) \
  || !defined(PP_COMMA_H) || !defined(PP_COMMA_EACH_H)
#  error "the embedded copy should define every PP_*_H include guard of pp_iter.h"
#endif

/* Its #error does not fire, because the embedded probe has set PP_HAS_VA_OPT to 1. */
#include "pp_iter.h"
CHECK(narg_after_standalone, PP_NARG(a, b) == 2)

int main(void) {
  int ok = each_a + each_b == 2 && par_a_0 == 0 && par_b_1 == 1;
  printf(ok ? "Embedded macros work\n" : "FAILED: embedded macros\n");
  return !ok;
}

#else

#if PP_HAS_VA_OPT
#  error "PP_HAS_VA_OPT should be 0 in this build"
#endif
#if defined(PP_NARG) || defined(PP_EACH) || defined(PP_PAR_EACH_IDX) || defined(PP_CAT) \
  || defined(PP_HEAD) || defined(PP_SEQ_N) || defined(PP_UTIL_H)
#  error "the embedded macros should not be defined when PP_HAS_VA_OPT is 0"
#endif

int main(void) {
  printf("Host header compiles without the embedded macros\n");
  return 0;
}

#endif
