#!/usr/bin/env ruby

# Generator logic for a family of macros for C metaprogramming
# See these blog posts in relation to VA_EACH:
# - http://ptspts.blogspot.ie/2013/11/how-to-apply-macro-to-all-arguments-of.html
# - https://codecraft.co/2014/11/25/variadic-macros-tricks/ (Similar, but recursive)
# There's an alternative approach described here, that i couldn't get to work...
# - http://saadahmad.ca/cc-preprocessor-metaprogramming-2/

require 'date'

MAX_ARG_COUNT_DEFAULT = 64

OPERATION = 'OP'
if ARGV.empty?
  puts "WARNING: Maximum number of arguments not specified -- defaulting to #{MAX_ARG_COUNT_DEFAULT}"
  max_arg_count = MAX_ARG_COUNT_DEFAULT
else
  max_arg_count = ARGV[0].to_i
end

macros = [];

# VA_COUNT
seq_fwd = (1..max_arg_count+1).map{ |i| "_#{i}"}.join(', ')
macros << "VA_ARG_N(#{seq_fwd}, N, ...) N"
seq_rev = (0..max_arg_count).map { |i| i.to_s }.reverse.join(', ')
macros << "VA_NARGS(...) VA_ARG_N(_0, ## __VA_ARGS__, #{seq_rev})"

# VA_EACH
macros << "__VA_APPLY_0(TF, ...)"
macros << "__VA_APPLY_1(TF, next_arg) TF(next_arg)"
(2..max_arg_count).each do |arg_count|
  macro_signature = "__VA_APPLY_#{arg_count}(TF, next_arg, ...)"
  macro_body = "TF(next_arg) __VA_APPLY_#{arg_count-1}(TF, __VA_ARGS__)"
  macros << "#{macro_signature} #{macro_body}"
end
submacrolist = (0..max_arg_count).map { |i| "__VA_APPLY_#{i}"}.reverse.join(', ')
macros << "VA_EACH(TF, ...) VA_ARG_N(\"ignored\", ##__VA_ARGS__, #{submacrolist})(TF, ##__VA_ARGS__)"

## THESE RECURSIVE VARIANTS INDEX IN REVERSE ORDER
# # VA_EACH_WITH_INDEX
# macros << "__VA_IDX_APPLY_0(TF, ...)"
# macros << "__VA_IDX_APPLY_1(TF, next_arg) TF(next_arg, 0)"
# (2..max_arg_count).each do |arg_count|
#   macro_signature = "__VA_IDX_APPLY_#{arg_count}(TF, next_arg, ...)"
#   macro_body = "TF(next_arg, #{arg_count-1}) __VA_IDX_APPLY_#{arg_count-1}(TF, __VA_ARGS__)"
#   macros << "#{macro_signature} #{macro_body}"
# end
# submacrolist = (0..max_arg_count).map { |i| "__VA_IDX_APPLY_#{i}"}.reverse.join(', ')
# macros << "VA_IDX_EACH(TF, ...) VA_ARG_N(\"ignored\", ##__VA_ARGS__, #{submacrolist})(TF, ##__VA_ARGS__)"

# # VA_FIX_EACH_WITH_INDEX
# macros << "__VA_FIX_IDX_APPLY_0(TF, FIXED_ARG, ...)"
# macros << "__VA_FIX_IDX_APPLY_1(TF, FIXED_ARG, next_arg) TF(FIXED_ARG, next_arg, 0)"
# (2..max_arg_count).each do |arg_count|
#   macro_signature = "__VA_FIX_IDX_APPLY_#{arg_count}(TF, FIXED_ARG, next_arg, ...)"
#   macro_body = "TF(FIXED_ARG, next_arg, #{arg_count-1}) __VA_FIX_IDX_APPLY_#{arg_count-1}(TF, FIXED_ARG, __VA_ARGS__)"
#   macros << "#{macro_signature} #{macro_body}"
# end
# submacrolist = (0..max_arg_count).map { |i| "__VA_FIX_IDX_APPLY_#{i}"}.reverse.join(', ')
# macros << "VA_FIX_IDX_EACH(TF, FIXED_ARG, ...) VA_ARG_N(\"ignored\", ##__VA_ARGS__, #{submacrolist})(TF, ##__VA_ARGS__)"


#Non-recursive, for proper indexing

# VA_IDX_EACH
macros << "__VA_IDX_APPLY_0(TF, dummy)"
(1..max_arg_count).each do |arg_count|
  arg_indices = (0..arg_count-1)
  arg_ids = arg_indices.map{ |aidx| "_#{aidx}"}
  macro_signature = "__VA_IDX_APPLY_#{arg_count}(TF, #{arg_ids.join(', ')})"
  macro_body = arg_indices.map { |aidx| "TF(_#{aidx}, #{aidx})" }.join(' ')
  macros << "#{macro_signature} #{macro_body}"
end
macros << "_VA_IDX_EACH_H3(TF, N, ...) __VA_IDX_APPLY_##N(TF, __VA_ARGS__)"
macros << "_VA_IDX_EACH_H2(TF, N, ...) _VA_IDX_EACH_H3(TF, N, __VA_ARGS__)"
macros << "VA_IDX_EACH(TF, ...) _VA_IDX_EACH_H2(TF, VA_NARGS(__VA_ARGS__), __VA_ARGS__)"

macros << "VA_EACH_WITH_INDEX(...) VA_IDX_EACH(...)" #alias

# VA_FIX_IDX_EACH
macros << "__VA_FIX_IDX_APPLY_0(TF, ARG, dummy)"
(1..max_arg_count).each do |arg_count|
  arg_indices = (0..arg_count-1)
  arg_ids = arg_indices.map{ |aidx| "_#{aidx}"}
  macro_signature = "__VA_FIX_IDX_APPLY_#{arg_count}(TF, FARG, #{arg_ids.join(', ')})"
  macro_body = arg_indices.map { |aidx| "TF(FARG, _#{aidx}, #{aidx})" }.join(' ')
  macros << "#{macro_signature} #{macro_body}"
end
macros << "_VA_FIX_IDX_EACH_H3(TF, FARG, N, ...) __VA_FIX_IDX_APPLY_##N(TF, FARG, __VA_ARGS__)"
macros << "_VA_FIX_IDX_EACH_H2(TF, FARG, N, ...) _VA_FIX_IDX_EACH_H3(TF, FARG, N, __VA_ARGS__)"
macros << "VA_FIX_IDX_EACH(TF, FARG, ...) _VA_FIX_IDX_EACH_H2(TF, FARG, VA_NARGS(__VA_ARGS__), __VA_ARGS__)"

macros << "VA_EACH_WITH_INDEX_AND_FIXED_ARG(...) VA_FIX_IDX_EACH(...)" #alias


# VA_2FIX_IDX_EACH
macros << "__VA_2FIX_IDX_APPLY_0(TF, ARG, dummy)"
(1..max_arg_count).each do |arg_count|
  arg_indices = (0..arg_count-1)
  arg_ids = arg_indices.map{ |aidx| "_#{aidx}"}
  macro_signature = "__VA_2FIX_IDX_APPLY_#{arg_count}(TF, FARG1, FARG2, #{arg_ids.join(', ')})"
  macro_body = arg_indices.map { |aidx| "TF(FARG1, FARG2, _#{aidx}, #{aidx})" }.join(' ')
  macros << "#{macro_signature} #{macro_body}"
end
macros << "_VA_2FIX_IDX_EACH_H3(TF, FARG1, FARG2, N, ...) __VA_2FIX_IDX_APPLY_##N(TF, FARG1, FARG2, __VA_ARGS__)"
macros << "_VA_2FIX_IDX_EACH_H2(TF, FARG1, FARG2, N, ...) _VA_2FIX_IDX_EACH_H3(TF, FARG1, FARG2, N, __VA_ARGS__)"
macros << "VA_2FIX_IDX_EACH(TF, FARG1, FARG2, ...) _VA_2FIX_IDX_EACH_H2(TF, FARG1, FARG2, VA_NARGS(__VA_ARGS__), __VA_ARGS__)"

File.open("vaiter#{max_arg_count}.h", 'w') do |f|
  f.puts <<-EOF
/**
 * @file
 *
 * va_iter.h
 * Some useful c preprocessor extensions for dealing with variadic macros
 *
 * @author Cormac Cannon (cormacc.public@gmail.com)
 *
 * This is auto-generated code. The generator script and further background/usage info may be found here:
 * https://github.com/cormacc/va_args_iterators
 *
 * Autogenerated on #{DateTime.now.strftime("%d/%m/%Y %H:%M")}
 * - Script:             #{$0}
 * - Max argument count: #{max_arg_count}
 *
 * I initially encountered the variadic macro counting logic in this post by Laurent Deniau:
 * https://groups.google.com/forum/#!topic/comp.std.c/d-6Mj5Lko_s
 * Refined by arpad. and zhangj to handle the no-argument case
 *
 * Recursive VA_EACH implementation based on this blog post by Daniel Hardman:
 * https://codecraft.co/2014/11/25/variadic-macros-tricks/
 *
 * Non-recursive VA_IDX_EACH and VA_FIX_IDX_EACH macro implementations extend
 * the VA_EACH implementation described in this (anonymous) blog post:
 * http://ptspts.blogspot.ie/2013/11/how-to-apply-macro-to-all-arguments-of.html
 */

#ifndef VA_ITER_H
#  define VA_ITER_H

#  ifdef  __cplusplus
extern "C" {
#  endif

#{macros.map{ |m| "\#define #{m}" }.join("\n")}

#  ifdef  __cplusplus
}
#  endif

#endif  /* VA_ITER_H */
EOF
end
