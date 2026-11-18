# AGENTS.md

Header-only C preprocessor library to count and iterate over `__VA_ARGS__`. The user documentation is `README.org`.

## Commands

Run all commands in the Nix devShell (`flake.nix`: cmake, ruby, stdenv gcc, and `clang`/`clang++` only, so that `cc`/`c++` stay GCC). direnv loads it through `.envrc`; otherwise prefix a command with `nix develop -c`.

```sh
# Build and run the tests with each compiler (CMakePresets.json: gcc, clang; build/<preset>)
# CTest runs tests (C++20, Catch2 v2.13.9 in vendor/catch), c_tests (strict C99) and header_up_to_date
for p in gcc clang; do cmake --preset $p && cmake --build --preset $p && ctest --preset $p; done
./build/gcc/tests                 # Catch2 report
cmake --list-presets              # available presets

# Regenerate pp_iter.h (default limit 63 args); extra args pass through to the generator
./regenerate                      # = ruby pp_iterators.rb "$@" > pp_iter.h
ruby pp_iterators.rb --help       # generator options (only --limit N)
ruby pp_iterators.rb --limit 127 > pp_iter.h

# Show the preprocessed test source, to debug macro expansion
./inspect_macro_expansion         # = gcc -I . -I ./vendor/catch -E test/pp_iter_test.cpp
```

`CMakeLists.txt` declares `cmake_minimum_required(VERSION 3.21...4.4)`: 3.21 is the first version that reads `CMakePresets.json` version 3, which does not need a `generator`, and 4.4 is the newest version tested. Raise the upper bound when you test a newer CMake. The expected result is `All tests passed (71 assertions in 9 test cases)`.

Generation is deterministic. The CTest test `header_up_to_date` (`test/check_header.cmake`, added when CMake finds Ruby) fails if `pp_iter.h` differs from the generator output.

## Task memory

Tasks are in `TASKS.org` (org-tasks protocol; use the `ot` CLI, e.g. `ot list`, `ot doctor`). `TASKS.local.org` is gitignored and holds the local selection.

## Architecture

- `pp_iterators.rb` is the source of truth. `pp_iter.h` is generated output: do not edit it by hand. Change the generator, run `./regenerate`, then commit both. The header records the `--limit` value; a regeneration with the same limit produces no diff.
- `PPIterators` (in `pp_iterators.rb`) has one method for each macro group (`defer`, `eval`, `concat`, `logical`, `lists`, `tuples`, `narg`, `each`, `each_with_index`, `parameterised_each_with_index`, `list_each`, ...). `embed_macros` sets their order in the header; `generate_header` wraps them. `PPIterators::CFile` is the helper for include guards, indentation and `#define` lists. Other code generators (for example the fake function framework) can `require` this file and call the methods to emit a subset of the macros.
- Naming: every macro starts with `PP_`, so that the headers do not clash with user macros. Public helpers are `PP_<NAME>`; internal macros and pattern-matching tokens are `PP_I_<NAME>`. Some internal names are built by token pasting (for example `PP_CAT(PP_I_IF_, value)` reaches `PP_I_IF_1`, and `PP_I_MATCH_PP_I_EXISTS` is `PP_I_MATCH_` pasted with the token `PP_I_EXISTS`), so rename a prefix and its targets together. Do not use names that start with `_` and a capital letter or contain `__`; the C standard reserves them.
- Each group has its own include guard (`PP_EACH_H`, `PP_NARG_H`, `PP_DEFER_H`, `PP_EVAL_H`, ...), so the macros can be embedded in other headers without a clash.
- Iteration (`PP_EACH`, `PP_EACH_IDX`, `PP_PAR_EACH_IDX`, `PP_COMMA_EACH`) is recursive. It uses `PP_DEFER`/`PP_EVAL` and pattern-matching macros (`PP_IF`, `PP_NOT`, `PP_MATCHER`, tuple-aware `PP_CAT`), after Saad Ahmad's blog posts. The `PP_EVAL` depth is `ceil(log2(limit))` levels, so the limit must be at least 2. Indices come from `PP_SEQ_N()`, so the argument limit also bounds the index range.
- The header requires `__VA_OPT__`; there are no compiler-specific code paths. `PP_NARG` is `PP_I_PLACEHOLDER __VA_OPT__(,) __VA_ARGS__` counted against `PP_RSEQ_N()`, and `PP_IS_EMPTY` is `PP_NOT(PP_NARG(...))`. `narg_common` defines the probe `PP_HAS_VA_OPT` and emits `#error` when it is 0; argument counting is emitted first so that this error comes first.
- The minimum supported embedded compiler is Microchip XC-DSC v4.00 (GCC 8.3.1 based, C only). It supports `__VA_OPT__` in all C modes. In strict `-std=c99`/`c11`/`c17` with `-pedantic`, GCC warns about it and about variadic macros called with no variadic arguments; `#pragma GCC system_header` in both headers suppresses those warnings (measured: 61 warnings to 1 for `test/pp_c_test.c`). The Nix devShell does not provide XC-DSC.
- `pp_enum.h` is hand-written. It builds on `pp_iter.h` and provides `TAGGED_ENUM`, `TAGGED_ENUM_TYPE`, `ENUM_DESCRIBE` and `ENUM_DESCRIBE_EXPLICIT`, which generate `<Name>_COUNT` and `<Name>_asCString`. It reads the member list from a user macro named `<Name>Tags` (`PP_I_ENUM` uses `NAME##Tags`). Its internal macros follow the same `PP_I_` naming.
- Tests: `test/pp_iter_test.cpp` (`SCENARIO` blocks for each `pp_iter.h` macro, and the Catch main) and `test/pp_enum_test.cpp` build `tests`; `test/pp_c_test.c` builds `c_tests` as C99 without extensions. `pp_c_test.c` checks values at compile time with `CHECK` (a negative array size) and at run time through its exit status. The 63-argument tests in `PP_NARG` and `PP_EACH` assume the default limit, so a header generated with a lower `--limit` does not compile against them.
- MSVC needs its conformant preprocessor (`/Zc:preprocessor`, VS 2019 16.5 or later) for `__VA_OPT__`; `CMakeLists.txt` sets it. MSVC support is optional and untested; only current versions matter. MSVC enforces the C standard minimum of 127 macro arguments; this is why the default limit is 63.

## Earlier versions

- The tag `legacy-preprocessors` (`e6a5190`) is the last version with fallbacks for preprocessors without `__VA_OPT__`, and the remote branch `non-recursive` holds a generator variant that does not use recursion. `README.org` points users to both. Do not reintroduce either on `master`. The tag also has the removed `PP_1PAR_EACH_IDX`/`PP_2PAR_EACH_IDX` wrappers and the unused `DEFER3`-`DEFER6`, `EVAL_`, `TEST_LAST` and `PAREN` macros.
