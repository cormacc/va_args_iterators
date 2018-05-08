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
  attr_reader :max_arg_count, :gcc, :defer_levels
  def initialize(n = MAX_ARG_COUNT_DEFAULT, use_gcc_extensions: true, defer_levels: DEFER_LEVELS_DEFAULT)
    @gcc = use_gcc_extensions
    @max_arg_count = n
    @defer_levels = defer_levels
  end

  def arg_seq(reverse: false, first: 0, last: @max_arg_count, prefix: '', sep:', ')
    seq = (first..last).map{ |i| "#{prefix}#{i}"}
    seq.reverse! if reverse
    seq.join(sep)
  end

  def eval
    level_count = Math.log2(@max_arg_count).ceil
    CFile::define_macro_set('PP_EVAL',
                            [
                              "PP_EVAL(...) _PP_EVAL_#{level_count}(__VA_ARGS__)",
                              "_PP_EVAL_1(...) __VA_ARGS__"
                            ] + (2..level_count).map{ |l| "_PP_EVAL_#{l}(...) _PP_EVAL_#{l-1}(_PP_EVAL_#{l-1}(__VA_ARGS__))"}
                           )
  end

  def defer
    CFile::define_macro_set('PP_DEFER',
                            [
                              'PP_NOP()',
                              'PP_DEFER(...) __VA_ARGS__ PP_NOP()',
                              'PP_DEFER2(...) __VA_ARGS__ PP_DEFER(PP_NOP) ()',
                            ] + (3..@defer_levels).map{ |l| "PP_DEFER#{l}(...) __VA_ARGS__ PP_DEFER#{l-1}(PP_NOP) ()"}
                           )
  end

  def narg_common
    CFile::define_macro_set('PP_UTIL',
                            [
                              # Fix for MSVC expansion order (nicked from fff project)
                              "EXPAND(x) x",
                              "HEAD(FIRST, ...) FIRST",
                              "TAIL(FIRST, ...) __VA_ARGS__",
                              "CAT(A, B) _CAT(A,B)",
                              "_CAT(A, B) A ## B",
                              "DEPAREN_(...) __VA_ARGS__",
                              "DEPAREN(...) DEPAREN_ __VA_ARGS__",
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

  def each
    CFile::define_macro_set('PP_EACH',
                            [
                              "PP_EACH(TF, ...) _PP_EACH(TF, PP_NARG(__VA_ARGS__), __VA_ARGS__)",
                              "_PP_EACH(TF, N, ...) __PP_EACH(TF, N, __VA_ARGS__)",
                              "__PP_EACH(TF, N, ...) _PP_EACH_##N(TF, __VA_ARGS__)",
                              "",
                              "_PP_EACH_0(TF, ...)",
                              "_PP_EACH_1(TF, next_arg) TF(next_arg)",
                            ] + (2..@max_arg_count).map { |arg_count| "_PP_EACH_#{arg_count}(TF, next_arg, ...) TF(next_arg) _PP_EACH_#{arg_count-1}(TF, __VA_ARGS__)" }
                           )
  end

  def each_with_index
    CFile::define_macro_set('PP_EACH_IDX',
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

  # TODO: Maybe append FARGS using ## notation once verified as stands
  # _PP_APPLY(TF, FARGS, VARG, IDX) DEFER(TF) (DEPAREN(FARGS), VARG, IDX)
  def parameterised_each_with_index
    # fargs = (1..n).map { |aidx| "P#{aidx}"}.join(", ")
    CFile::define_macro_set("PP_PAR_EACH_IDX",
                            [
                              "PP_PAR_EACH_IDX(TF, FARGS, ...) _PP_PAR_EACH_IDX(TF, FARGS, PP_NARG(__VA_ARGS__), __VA_ARGS__)",
                              "_PP_PAR_EACH_IDX(TF, FARGS, N, ...) __PP_PAR_EACH_IDX(TF, FARGS, N, __VA_ARGS__)",
                              "__PP_PAR_EACH_IDX(TF, FARGS, N, ...) _PP_PAR_IDX_##N(TF, FARGS, __VA_ARGS__)",
                              "_PP_APPLY(TF, FARGS, VARG, IDX) PP_DEFER(TF) (DEPAREN(FARGS), VARG, IDX)",
                              "",
                              "_PP_PAR_IDX_0(TF, FARGS, dummy)",
                            ] + (1..@max_arg_count).map do |arg_count|
                              arg_indices = (0..arg_count-1)
                              arg_ids = arg_indices.map{ |aidx| "_#{aidx}"}
                              macro_signature = "_PP_PAR_IDX_#{arg_count}(TF, FARGS, #{arg_ids.join(', ')})"
                              macro_body = arg_indices.map { |aidx| "_PP_APPLY(TF, FARGS, _#{aidx}, #{aidx})" }.join(' ')
                              "#{macro_signature} PP_EVAL(#{macro_body})"
                            end
                           )
  end

  def parameterised_each_with_index_n(n)
    fargs = (1..n).map { |aidx| "P#{aidx}"}.join(", ")
    CFile::define_macro("PP_#{n}PAR_EACH_IDX(TF, #{fargs}, ...) PP_PAR_EACH_IDX(TF, (#{fargs}), __VA_ARGS__)")
  end

  # def parameterised_each_with_index_n(n)
  #   fargs = (1..n).map { |aidx| "P#{aidx}"}.join(", ")
  #   CFile::define_macro_set("PP_#{n}PAR_EACH_IDX",
  #     [
  #       "PP_#{n}PAR_EACH_IDX(TF, #{fargs}, ...) _PP_#{n}PAR_EACH_IDX(TF, #{fargs}, PP_NARG(__VA_ARGS__), __VA_ARGS__)",
  #       "_PP_#{n}PAR_EACH_IDX(TF, #{fargs}, N, ...) __PP_#{n}PAR_EACH_IDX(TF, #{fargs}, N, __VA_ARGS__)",
  #       "__PP_#{n}PAR_EACH_IDX(TF, #{fargs}, N, ...) _PP_#{n}PAR_IDX_##N(TF, #{fargs}, __VA_ARGS__)",
  #       "",
  #       "_PP_#{n}PAR_IDX_0(TF, ARG, dummy)",
  #     ] + (1..@max_arg_count).map do |arg_count|
  #       arg_indices = (0..arg_count-1)
  #       arg_ids = arg_indices.map{ |aidx| "_#{aidx}"}
  #       macro_signature = "_PP_#{n}PAR_IDX_#{arg_count}(TF, #{fargs}, #{arg_ids.join(', ')})"
  #       macro_body = arg_indices.map { |aidx| "TF(#{fargs}, _#{aidx}, #{aidx})" }.join(' ')
  #       "#{macro_signature} #{macro_body}"
  #     end
  #   )
  # end

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

//MSVC non-standard macro expansion fix
#{narg_common}

//Defer / evaluate macros
#{defer}
#{eval}

//Argument counting
#{narg}


//PP_EACH
#{each}


//PP_EACH_IDX
#{each_with_index}

//PP_PAR_EACH_IDX
#{parameterised_each_with_index}

//PP_1PAR_EACH_IDX
#{parameterised_each_with_index_n(1)}

//PP_2PAR_EACH_IDX
#{parameterised_each_with_index_n(2)}

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
