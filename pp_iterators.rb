#!/usr/bin/env ruby

# Generator logic for a family of macros for C metaprogramming
#
# The recursive iteration macros (PP_EACH etc.) are based on:
# - http://saadahmad.ca/cc-preprocessor-metaprogramming-2/

require 'optparse'

class PPIterators

  class CFile
    INDENT = 2
    class << self

      def indent(content)
        indentation = " " * INDENT
        indentation + content.gsub("\n","\n#{indentation}").gsub("\n#{indentation}\n", "\n\n").sub(/\s+\Z/,"\n")
      end

      def include_guard(name, content)
        content.prepend("#define #{name}\n") unless content =~ /#define #{name}/

        "#ifndef #{name}\n" + indent(content) + "#endif //#{name}\n"
      end

      def define_macro(m)
        "\#define #{m}\n"
      end

      def define_macros(macros)
        macros.map{ |m| define_macro(m) }.join
      end

      def define_macro_set(guard_name, macros)
        include_guard(guard_name, define_macros(macros))
      end
    end
  end

  # MSVC enforces the standard minimum requirement of 127 VA_ARGS
  MAX_ARG_COUNT_DEFAULT = 63

  attr_reader :nargs_max
  # EVAL needs at least one expansion level, which ceil(log2(nargs_max)) gives only from 2
  def initialize(nargs_max: MAX_ARG_COUNT_DEFAULT)
    raise ArgumentError, "nargs_max must be an integer of at least 2 (got #{nargs_max.inspect})" unless nargs_max.is_a?(Integer) && nargs_max >= 2
    @nargs_max = nargs_max
  end

  def arg_seq(reverse: false, first: 0, last: @nargs_max, prefix: '')
    seq = (first..last).map{ |i| "#{prefix}#{i}"}
    seq.reverse! if reverse
    seq.join(', ')
  end

  # This complex implementation of a concatenation macro is tuple-aware
  # i.e. is valid for braced tuples during pattern matching (see matcher macros later)
  # This is required for recursive for_each on an array of tuples, each PP_EACH(TF, (1, 2), (3, 4))
  # As the list empty macros will break down otherwise
  # See saadahmad's posts for further info
  def concat
    CFile::include_guard('PP_CAT', <<-EOH
// Defer the call to the CAT so that we get the updated parameters first
#define CAT(a, b) _CAT_EVAL ( _CAT_EXPAND_PARAMETERS(a, b) )
#define _CAT_EVAL(...) _CAT_HELPER __VA_ARGS__

// Find the result of testing whether a macro is enclosed or not
#define _CAT_EXPAND_PARAMETERS(a, b) (a, _CAT_PAREN_CHECK b, DEFAULT, b )
#define _CAT_PAREN_CHECK(...) EXPANDED, ENCLOSED, (__VA_ARGS__) ) EAT (

// Pattern match the result of testing if it is enclose or not
#define _CAT_HELPER(a, _, f, b) _CAT_HELPER_ ## f (a, b)
#define _CAT_HELPER_ENCLOSED(a, b) a b
#define _CAT_HELPER_DEFAULT(a, b) a ## b

EOH
                        )
  end

  def eval
    level_count = Math.log2(@nargs_max).ceil
    CFile::define_macro_set('EVAL',
                            [
                              "EVAL(...) _EVAL_#{level_count}(__VA_ARGS__)",
                              "_EVAL_1(...) __VA_ARGS__"
                            ] + (2..level_count).map{ |l| "_EVAL_#{l}(...) _EVAL_#{l-1}(_EVAL_#{l-1}(__VA_ARGS__))"}
                           )
  end

  def defer
    CFile::define_macro_set('DEFER',
                            [
                              'PP_NOP()',
                              'DEFER(...) __VA_ARGS__ PP_NOP()',
                              'DEFER2(...) __VA_ARGS__ DEFER(PP_NOP) ()'
                            ]
                           )
  end

  # See http://saadahmad.ca/cc-preprocessor-metaprogramming-basic-pattern-matching-macros-and-conditionals/
  def logical
    CFile::include_guard('PP_LOGIC', <<-EOH
//Usage: IF(<condition>) (<then>, <else>)
#define  IF(value) CAT(_IF_, value)
#define _IF_1(true, ...) true
#define _IF_0(true, ...) __VA_ARGS__

#define NOT(x) PP_MATCHER ( CAT(NOT_, x), 0 )
#define NOT_0 EXISTS(1)

//== Building blocks

//PP_MATCHER
#define PP_MATCHER(value, ...) \
  IF ( _MATCH(_MATCH_FIND(value)) )\
       ( _MATCH_EXTRACT(value), __VA_ARGS__ )

#define _MATCH(x) CAT(__MATCH_, x)
#define __MATCH_EXISTS(...) 1
#define __MATCH_UNMATCHED 0

#define _MATCH_FIND(x) __MATCH_RESULT_EXTRACT (  __MATCH_RESULT_FIND(x) )

/**
 * Extract 2nd element of a match result in the format:
 * (IGNORED, EXISTS(DEFINED_VALUE)) or (IGNORED, UNMATCHED)
 * This is appended to __MATCH_ to convert result to a boolean,
 */
#define __MATCH_RESULT_EXTRACT(x) __MATCH_RESULT_EXTRACT_HELPER  x
#define __MATCH_RESULT_EXTRACT_HELPER(match, return_value) return_value

/**
 * __MATCH_RESULT_FIND( EXISTS(bla) ) returns ( EXPANDED, EXISTS(bla) )
 * __MATCH_RESULT_FIND( bla ) returns ( TEST_bla, UNMATCHED)
 */
#define __MATCH_RESULT_FIND(x) ( CAT(__MATCH_RESULT_EXPAND_, x),  UNMATCHED )
#define __MATCH_RESULT_EXPAND_EXISTS(...) EXPANDED, EXISTS(__VA_ARGS__) ) EAT (
#define EAT(...)

//_MATCH_EXTRACT / __MATCH_EXTRACT_EXISTS
#define _MATCH_EXTRACT(value) CAT(__MATCH_EXTRACT_, value)
#define __MATCH_EXTRACT_EXISTS(...) __VA_ARGS__

EOH
)
  end

  def lists
    CFile::include_guard('PP_LISTS', <<-EOH
#define HEAD(FIRST, ...) FIRST
#define TAIL(FIRST, ...) __VA_ARGS__

#define NOT_EMPTY(...) NOT(IS_EMPTY(__VA_ARGS__))
#define IS_EMPTY(...) NOT(PP_NARG(__VA_ARGS__))
EOH
                        )
  end

  def tuples
    CFile::include_guard('PP_TUPLES', <<-EOH
#define DEPAREN(...) DEPAREN_ __VA_ARGS__
#define DEPAREN_(...) __VA_ARGS__

#define IS_ENCLOSED(x, ...) PP_MATCHER ( IS_ENCLOSED_TEST x, 0 )
#define IS_ENCLOSED_TEST(...) EXISTS(1)

#define IF_ENCLOSED(...) CAT(_IF_ENCLOSED_, IS_ENCLOSED(__VA_ARGS__))
#define _IF_ENCLOSED_0(true, ...) __VA_ARGS__
#define _IF_ENCLOSED_1(true, ...) true
// This function will optionally remove parentheses around its arguments
// if there are any. Otherwise it will return normally
#define OPT_DEPAREN(...) \
  IF_ENCLOSED (__VA_ARGS__) ( DEPAREN(__VA_ARGS__), __VA_ARGS__ )
EOH
                        )
  end

  def narg_common
    CFile::define_macro_set('PP_UTIL',
                            [
                              "PP_SEQ_N() #{arg_seq(last: @nargs_max)}",
                              "PP_RSEQ_N() #{arg_seq(last: @nargs_max, reverse: true)}",
                              # PP_HAS_VA_OPT is 1 if __VA_OPT__(,) expands to a comma, which shifts the 1 into third place
                              "_PP_THIRD_ARG(a, b, c, ...) c",
                              "_PP_VA_OPT_PROBE(...) _PP_THIRD_ARG(__VA_OPT__(,), 1, 0, )",
                              "PP_HAS_VA_OPT _PP_VA_OPT_PROBE(?)"
                            ]
                           ) + <<-EOH
#if !PP_HAS_VA_OPT
  #error "pp_iter.h requires a preprocessor with __VA_OPT__ support (for MSVC, use /Zc:preprocessor)"
#endif
EOH
  end

  # The leading _0 placeholder in PP_NARG needs one more slot than nargs_max
  def arg_n_seq(delta)
    seq = arg_seq(first: 1, last: @nargs_max+1, prefix: '_')
    delta==0 ? seq :[arg_seq(first: 0, last: delta-1, prefix: '__', reverse: true), seq].join(', ')
  end

  def narg
    narg_minus(0)
  end

  # The leading _0 placeholder lets the argument list be empty;
  # __VA_OPT__(,) emits the comma after it only when there are arguments.
  # PP_ARG_N is an indirection so that PP_RSEQ_N() expands before _PP_ARG_N counts its arguments.
  def narg_minus(m)
    suffix = m>0 ? "_MINUS#{m}" : ''
    CFile::define_macro_set("PP_NARG#{suffix}",
                            [
                              "PP_ARG#{suffix}_N(...) _PP_ARG#{suffix}_N(__VA_ARGS__)",
                              "PP_NARG#{suffix}(...) PP_ARG#{suffix}_N(_0 __VA_OPT__(,) __VA_ARGS__, PP_RSEQ_N())",
                              "_PP_ARG#{suffix}_N(#{arg_n_seq(m)}, N, ...) N"
                            ]
                           )
  end

  def each
    CFile::include_guard('PP_EACH', <<-'EOH'
#define PP_EACH(TF, ...) \
  EVAL(_PP_EACH_DEFER(TF, __VA_ARGS__))

#define _PP_EACH_DEFER(TF, ...) \
  IF ( NOT_EMPTY( __VA_ARGS__ )  ) \
  ( \
    DEFER(TF) (OPT_DEPAREN(HEAD(__VA_ARGS__))) \
    DEFER2 ( __PP_EACH_DEFER ) () (TF, TAIL(__VA_ARGS__)) \
  )

//This indirection along with the DEFER2 and EVAL macros allows the recursive implementation of _PP_EACH_DEFER
#define __PP_EACH_DEFER() _PP_EACH_DEFER
EOH
           )
  end

  def comma
    CFile::include_guard('PP_COMMA', <<-'EOH'
#define PP_COMMA() ,
EOH
           )
  end

  def list_each
    CFile::include_guard('PP_COMMA_EACH', <<-'EOH'
#define PP_COMMA_EACH(TF, ...) \
  EVAL(_PP_COMMA_EACH_DEFER(TF, __VA_ARGS__))

#define _PP_COMMA_EACH_DEFER(TF, ...) \
  IF ( NOT_EMPTY( __VA_ARGS__ )  ) \
  ( \
    DEFER(TF) (OPT_DEPAREN(HEAD(__VA_ARGS__))) \
    IF ( NOT_EMPTY(TAIL(__VA_ARGS__))) (PP_COMMA()) \
    DEFER2 ( __PP_COMMA_EACH_DEFER ) () (TF, TAIL(__VA_ARGS__)) \
  )

//This indirection along with the DEFER2 and EVAL macros allows the recursive implementation of _PP_COMMA_EACH_DEFER
#define __PP_COMMA_EACH_DEFER() _PP_COMMA_EACH_DEFER
EOH
           )
  end

  def each_with_index
    CFile::include_guard('PP_EACH_IDX', <<-'EOH'
#define PP_EACH_IDX(TF, ...) EVAL(_PP_EACH_IDX_DEFER(TF, (PP_SEQ_N()), __VA_ARGS__))

#define _PP_EACH_IDX_DEFER(TF, VA_INDICES, ...) \
    IF ( NOT_EMPTY( __VA_ARGS__ )  ) \
    ( \
      DEFER2(TF) (OPT_DEPAREN(HEAD(__VA_ARGS__)), DEFER(HEAD)(DEPAREN(VA_INDICES))) \
      DEFER2 ( __PP_EACH_IDX_DEFER ) () (TF, (TAIL VA_INDICES), TAIL(__VA_ARGS__)) \
    )

  #define __PP_EACH_IDX_DEFER() _PP_EACH_IDX_DEFER
EOH
           )
  end

  def parameterised_each_with_index
    CFile::include_guard('PP_PAR_EACH_IDX', <<-'EOH'
#define PP_PAR_EACH_IDX(TF, FARGS, ...) EVAL(_PP_PAR_EACH_IDX_DEFER(TF, FARGS, (PP_SEQ_N()), __VA_ARGS__))

#define _PP_PAR_EACH_IDX_DEFER(TF, FARGS, VA_INDICES, ...)                         \
  IF ( NOT_EMPTY( __VA_ARGS__ )  )                                      \
  (                                                                     \
    DEFER2(TF) (OPT_DEPAREN(FARGS), OPT_DEPAREN(HEAD(__VA_ARGS__)), DEFER(HEAD)(DEPAREN(VA_INDICES))) \
    DEFER2 ( __PP_PAR_EACH_IDX_DEFER ) () (TF, FARGS, (TAIL VA_INDICES), TAIL(__VA_ARGS__)) \
  )

#define __PP_PAR_EACH_IDX_DEFER() _PP_PAR_EACH_IDX_DEFER
EOH
           )
  end

  def generate_header
    <<-EOH
/**
 * @file
 *
 * pp_iter.h
 * Some useful c preprocessor extensions for dealing with variadic macros
 *
 * @author Cormac Cannon (cormacc.public@gmail.com)
 *
 * This is auto-generated code. The generator script and further background/usage info may be found here:
 * https://github.com/cormacc/va_args_iterators
 *
 * Autogenerated on #{Time.now.strftime("%d/%m/%Y %H:%M")}
 * - Script:             #{$0}
 * - Max argument count: #{@nargs_max}
 *
 * I initially encountered the variadic macro counting logic in this post by Laurent Deniau:
 * https://groups.google.com/forum/#!topic/comp.std.c/d-6Mj5Lko_s
 * PP_NARG uses __VA_OPT__ to count zero arguments.
 *
 * The recursive implementations of PP_EACH, PP_EACH_IDX, PP_PAR_EACH_IDX and PP_COMMA_EACH are based on an
 * excellent series of posts by Saad Ahmad:
 * http://saadahmad.ca/cc-preprocessor-metaprogramming-2/
 *
 * Requires a preprocessor with __VA_OPT__ support (standard in C++20 and C23; MSVC needs /Zc:preprocessor).
 */

#ifndef PP_ITER_H
#  define PP_ITER_H

#{embed_macros}
#endif  /* PP_ITER_H */
EOH
  end

  def embed_macros
    <<-EOH
//Argument counting (first, so that a missing __VA_OPT__ is reported before anything else)
#{narg_common}
#{narg}

//Defer / evaluate macros
#{defer}
#{eval}

//Token concatenation (tuple-aware)
#{concat}

//Logical operations
#{logical}

//Lists (HEAD, TAIL, ISEMPTY etc.)
#{lists}

//Tuples
#{tuples}

//PP_EACH
#{each}

//PP_EACH_IDX
#{each_with_index}

//PP_PAR_EACH_IDX
#{parameterised_each_with_index}

//PP_COMMA
#{comma}

//PP_COMMA_EACH
#{list_each}

EOH
  end

end

# Generate a header if run standalone rather than required as a dependency
if __FILE__==$0

  nargs_max = PPIterators::MAX_ARG_COUNT_DEFAULT

  OptionParser.new do |opts|
    opts.banner = "Usage: pp_iterators.rb [options]"
    opts.on("--limit N", Integer, "Argument count limit (defaults to #{PPIterators::MAX_ARG_COUNT_DEFAULT})") do |n|
      nargs_max = n
    end
  end.parse!
  begin
    ppi = PPIterators.new(nargs_max: nargs_max)
  rescue ArgumentError => e
    abort "pp_iterators.rb: --limit: #{e.message}"
  end
  puts ppi.generate_header
end
