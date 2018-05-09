#!/usr/bin/env ruby

# Generator logic for a family of macros for C metaprogramming
# See these blog posts in relation to VA_EACH:
# - http://ptspts.blogspot.ie/2013/11/how-to-apply-macro-to-all-arguments-of.html
# - https://codecraft.co/2014/11/25/variadic-macros-tricks/ (Similar, but recursive)
# There's a recursive approach described here, that i couldn't get to work...
# - http://saadahmad.ca/cc-preprocessor-metaprogramming-2/

require 'date'

class PPIterators

  class CFile
    INDENT = 2
    class << self

      def indent(content)
        " " * INDENT + content.gsub("\n","\n  ")
      end

      def include_guard(name, content)
        content.prepend("#define #{name}\n") unless content =~ /#define #{name}/

        "#ifndef #{name}\n" + indent(content) + "\n#endif //#{name}\n"
      end

      def define_macro(m)
        m.empty? ? m : "\#define #{m}"
      end

      def define_macros(macros)
        macros.map{ |m| define_macro(m) }.join("\n")
      end

      def define_macro_set(guard_name, macros)
        include_guard(guard_name, define_macros(macros))
      end
    end
  end

  MAX_ARG_COUNT_DEFAULT = 64
  DEFER_LEVELS_DEFAULT = 8
  attr_reader :max_arg_count, :gcc, :defer_levels, :recursive
  def initialize(n = MAX_ARG_COUNT_DEFAULT, defer_levels: DEFER_LEVELS_DEFAULT, use_gcc_extensions: true, recursive: true)
    @gcc = use_gcc_extensions
    @max_arg_count = n
    @defer_levels = defer_levels
    @recursive = recursive
  end

  def arg_seq(reverse: false, first: 0, last: @max_arg_count, prefix: '', sep:', ')
    seq = (first..last).map{ |i| "#{prefix}#{i}"}
    seq.reverse! if reverse
    seq.join(sep)
  end

  def concat
    CFile::include_guard('PP_CAT', <<-EOH
// Find the result of testing whether a macros is enclosed or not
#define ENCLOSE_EXPAND(...) EXPANDED, ENCLOSED, (__VA_ARGS__) ) EAT (
#define GET_CAT_EXP(a, b) (a, ENCLOSE_EXPAND b, DEFAULT, b )

// Pattern match the result of testing if it is enclose or not
#define CAT_WITH_ENCLOSED(a, b) a b
#define CAT_WITH_DEFAULT(a, b) a ## b
#define CAT_WITH(a, _, f, b) CAT_WITH_ ## f (a, b)

// Defer the call to the CAT so that we get the updated parameters first
#define EVAL_CAT_WITH(...) CAT_WITH __VA_ARGS__
#define CAT(a, b) EVAL_CAT_WITH ( GET_CAT_EXP(a, b) )
EOH
                        )
  end

  def eval_set(suffix: '', prefix: '')
    # level_count = Math.log2(@max_arg_count).ceil
    level_count = 8
    eroot = "#{prefix}EVAL#{suffix}"
    CFile::define_macro_set(eroot,
                            [
                              "#{eroot}(...) _#{eroot}_#{level_count}(__VA_ARGS__)",
                              "_#{eroot}_1(...) __VA_ARGS__"
                            ] + (2..level_count).map{ |l| "_#{eroot}_#{l}(...) _#{eroot}_#{l-1}(_#{eroot}_#{l-1}(__VA_ARGS__))"}
                           )
  end

  #Support two levels of eval nesting
  def eval
    [eval_set, eval_set(:suffix => '_')].join("\n")
  end

  def defer
    CFile::define_macro_set('DEFER',
                            [
                              'PP_NOP()',
                              'DEFER(...) __VA_ARGS__ PP_NOP()',
                              'DEFER2(...) __VA_ARGS__ DEFER(PP_NOP) ()',
                            ] + (3..@defer_levels).map{ |l| "DEFER#{l}(...) __VA_ARGS__ DEFER#{l-1}(PP_NOP) ()"}
                           )
  end

  def logical
    CFile::include_guard('PP_LOGIC', <<-EOH
#define  IF(value) CAT(_IF_, value)
#define _IF_1(true, ...) true
#define _IF_0(true, ...) __VA_ARGS__

#define NOT_0 EXISTS(1)
#define NOT(x) TRY_EXTRACT_EXISTS ( CAT(NOT_, x), 0 )

#define EAT(...)
#define EXPAND_TEST_EXISTS(...) EXPANDED, EXISTS(__VA_ARGS__) ) EAT (
#define GET_TEST_EXISTS_RESULT(x) ( CAT(EXPAND_TEST_, x),  DOESNT_EXIST )
#define GET_TEST_EXIST_VALUE_(expansion, existValue) existValue
#define GET_TEST_EXIST_VALUE(x) GET_TEST_EXIST_VALUE_  x

#define TEST_EXISTS(x) GET_TEST_EXIST_VALUE (  GET_TEST_EXISTS_RESULT(x) )

#define DOES_VALUE_EXIST_EXISTS(...) 1
#define DOES_VALUE_EXIST_DOESNT_EXIST 0
#define DOES_VALUE_EXIST(x) CAT(DOES_VALUE_EXIST_, x)

#define EXTRACT_VALUE_EXISTS(...) __VA_ARGS__
#define EXTRACT_VALUE(value) CAT(EXTRACT_VALUE_, value)

#define TRY_EXTRACT_EXISTS(value, ...) \
  IF ( DOES_VALUE_EXIST(TEST_EXISTS(value)) )\
       ( EXTRACT_VALUE(value), __VA_ARGS__ )

EOH
)
  end

  def lists
    CFile::include_guard('PP_LISTS', <<-EOH
#define HEAD(FIRST, ...) FIRST
#define TAIL(FIRST, ...) __VA_ARGS__

#define TEST_LAST EXISTS(1)
#define IS_EMPTY(...) \
  TRY_EXTRACT_EXISTS( \
    DEFER(HEAD) (__VA_ARGS__ EXISTS(1))\
  , 0)
#define NOT_EMPTY(...) NOT(IS_EMPTY(__VA_ARGS__))

EOH
                        )
  end

  def tuples
    CFile::include_guard('PP_TUPLES', <<-EOH
#define PAREN(...) ( __VA_ARGS__ )
#define DEPAREN(...) DEPAREN_ __VA_ARGS__
#define DEPAREN_(...) __VA_ARGS__

#define IS_ENCLOSED(x, ...) TRY_EXTRACT_EXISTS ( IS_ENCLOSED_TEST x, 0 )
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
                              # Fix for MSVC expansion order (nicked from fff project)
                              "EXPAND(x) x",
                              "PP_SEQ_N() #{arg_seq(reverse: false)}",
                              "PP_RSEQ_N() #{arg_seq(reverse: true)}"
                            ]
                           )
  end

  def arg_n_seq(delta)
    seq = arg_seq(first: 1, last: @gcc ? @max_arg_count+1 : @max_arg_count, prefix: '_')
    delta==0 ? seq :[arg_seq(first: 0, last: delta-1, prefix: '__', reverse: true), seq].join(', ')
  end

  def narg
    narg_minus(0)
  end

  def narg_minus(m)
    suffix = m>0 ? "_MINUS#{m}" : ''
    CFile::define_macro_set("PP_NARG#{suffix}",
                            [
                              "PP_NARG#{suffix}(...)  EXPAND(PP_ARG#{suffix}_N(#{'_0, ##' if @gcc}__VA_ARGS__, PP_RSEQ_N()))",
                              "PP_ARG#{suffix}_N(...) EXPAND(_PP_ARG#{suffix}_N(__VA_ARGS__))",
                              "_PP_ARG#{suffix}_N(#{arg_n_seq(m)}, N, ...) N",
                            ]
                           )
  end

  def each_non_recursive
    CFile::define_macros([
                         "PP_EACH(TF, ...) _PP_EACH(TF, PP_NARG(__VA_ARGS__), __VA_ARGS__)",
                         "_PP_EACH(TF, N, ...) __PP_EACH(TF, N, __VA_ARGS__)",
                         "__PP_EACH(TF, N, ...) _PP_EACH_##N(TF, __VA_ARGS__)",
                         "",
                         "_PP_EACH_0(TF, ...)",
                         "_PP_EACH_1(TF, next_arg) TF(next_arg)",
                       ] + (2..@max_arg_count).map { |arg_count| "_PP_EACH_#{arg_count}(TF, next_arg, ...) TF(next_arg) _PP_EACH_#{arg_count-1}(TF, __VA_ARGS__)" }
                      )
  end

  # _PP_EACH_DEFER below modified from original to get rid of tuple debracing.
  # NB single quotes around heredoc marker suppress interpolation
  def each_recursive
    <<-'EOH'
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
  end

  def each
    CFile::include_guard('PP_EACH', @recursive ? each_recursive : each_non_recursive)
  end

  def each_with_index
    CFile::include_guard('PP_EACH_IDX', @recursive ? each_idx_recursive : each_idx_non_recursive)
  end

  def each_idx_non_recursive
    CFile::define_macros(
      [
        "PP_EACH_IDX(TF, ...) _PP_EACH_IDX(TF, PP_NARG(__VA_ARGS__), __VA_ARGS__)",
        "_PP_EACH_IDX(TF, N, ...) __PP_EACH_IDX(TF, N, __VA_ARGS__)",
        "__PP_EACH_IDX(TF, N, ...) _PP_EACH_IDX_##N(TF, __VA_ARGS__)",
        "",
        "_PP_EACH_IDX_0(TF, dummy)"
      ] + (1..@max_arg_count).map do |arg_count|
        arg_indices = (0..arg_count-1)
        arg_ids = arg_indices.map{ |aidx| "_#{aidx}"}
        macro_signature = "_PP_EACH_IDX_#{arg_count}(TF, #{arg_ids.join(', ')})"
        macro_body = arg_indices.map { |aidx| "TF(_#{aidx}, #{aidx})" }.join(' ')
        "#{macro_signature} #{macro_body}"
      end
    )
  end

  def each_idx_recursive
    <<-'EOH'
#define PP_EACH_IDX(TF, ...) EVAL(_PP_EACH_IDX_DEFER(TF, (PP_SEQ_N()), __VA_ARGS__))

#define _PP_EACH_IDX_DEFER(TF, VA_INDICES, ...) \
    IF ( NOT_EMPTY( __VA_ARGS__ )  ) \
    ( \
      DEFER2(TF) (OPT_DEPAREN(HEAD(__VA_ARGS__)), DEFER(HEAD)(DEPAREN(VA_INDICES))) \
      DEFER2 ( __PP_EACH_IDX_DEFER ) () (TF, (TAIL VA_INDICES), TAIL(__VA_ARGS__)) \
    )

  #define __PP_EACH_IDX_DEFER() _PP_EACH_IDX_DEFER
EOH
  end

  # TODO: Maybe append FARGS using ## notation once verified as stands
  # _PP_APPLY(TF, FARGS, VARG, IDX) DEFER(TF) (DEPAREN(FARGS), VARG, IDX)
  def parameterised_each_with_index
    # fargs = (1..n).map { |aidx| "P#{aidx}"}.join(", ")
    CFile::define_macro_set("PP_PAR_EACH_IDX",
                            [
                              "PP_PAR_EACH_IDX(TF, FARGS, ...) _PP_PAR_EACH_IDX(TF, FARGS, PP_NARG(__VA_ARGS__), __VA_ARGS__)",
                              "_PP_PAR_EACH_IDX(TF, FARGS, N, ...) __PP_PAR_EACH_IDX(TF, FARGS, N, __VA_ARGS__)",
                              "__PP_PAR_EACH_IDX(TF, FARGS, N, ...) _PP_PAR_IDX_##N(TF, FARGS, __VA_ARGS__)",
                              "_PP_APPLY(TF, FARGS, VARG, IDX) DEFER(TF) (DEPAREN(FARGS), VARG, IDX)",
                              "",
                              "_PP_PAR_IDX_0(TF, FARGS, dummy)",
                            ] + (1..@max_arg_count).map do |arg_count|
                              arg_indices = (0..arg_count-1)
                              arg_ids = arg_indices.map{ |aidx| "_#{aidx}"}
                              macro_signature = "_PP_PAR_IDX_#{arg_count}(TF, FARGS, #{arg_ids.join(', ')})"
                              macro_body = arg_indices.map { |aidx| "_PP_APPLY(TF, FARGS, _#{aidx}, #{aidx})" }.join(' ')
                              "#{macro_signature} EVAL(#{macro_body})"
                            end
                           )
  end

  def parameterised_each_with_index_n(n)
    fargs = (1..n).map { |aidx| "P#{aidx}"}.join(", ")
    CFile::define_macro("PP_#{n}PAR_EACH_IDX(TF, #{fargs}, ...) PP_PAR_EACH_IDX(TF, (#{fargs}), __VA_ARGS__)")
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
 * Autogenerated on #{DateTime.now.strftime("%d/%m/%Y %H:%M")}
 * - Script:             #{$0}
 * - Max argument count: #{@max_arg_count}
 *
 * I initially encountered the variadic macro counting logic in this post by Laurent Deniau:
 * https://groups.google.com/forum/#!topic/comp.std.c/d-6Mj5Lko_s
 * Refined by arpad. and zhangj to handle the no-argument case
 *
 * Recursive PP_EACH implementation based on this blog post by Daniel Hardman:
 * https://codecraft.co/2014/11/25/variadic-macros-tricks/
 *
 * The PP_nPAR_EACH_IDX macro implementations extend the non-recursive PP_EACH implementation
 * described in this (anonymous) blog post:
 * http://ptspts.blogspot.ie/2013/11/how-to-apply-macro-to-all-arguments-of.html
 *
 * This MSVC macro expansion fix was lifted from the excellent fake function framework:
 * https://github.com/meekrosoft/fff
 */

#ifndef PP_ITER_H
#  define PP_ITER_H

#  ifdef  __cplusplus
extern "C" {
#  endif

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

//Argument counting
#{narg_common}
#{narg}

//PP_EACH
#{each}

//PP_EACH_IDX
#{each_with_index}

//PP_PAR_EACH_IDX
//{parameterised_each_with_index}

//PP_xPAR_EACH_IDX (Wrappers for deprecated macros)
//{parameterised_each_with_index_n(1)}
//{parameterised_each_with_index_n(2)}

#  ifdef  __cplusplus
}
#  endif

#endif  /* PP_ITER_H */
EOH
  end

end

# Generate a header if run standalone rather than required as a dependency
if __FILE__==$0
  ppi = ARGV.empty? ? PPIterators.new() : PPIterators.new(ARGV[0].to_i)
  puts ppi.generate_header
end
