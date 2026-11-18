#!/usr/bin/env ruby
# Compile and run a test with real MSVC (or any other compiler) on Compiler Explorer (godbolt.org),
# for a quick check during local development. The full MSVC suite runs in GitHub Actions.
#
# The source is sent to godbolt.org. pp_iter.h and pp_enum.h are inlined, because Compiler
# Explorer compiles a single file.
#
# Usage:
#   tools/compiler_explorer.rb              # test/pp_c_test.c with MSVC, as C and as C++
#   tools/compiler_explorer.rb --list       # MSVC compiler ids
#   tools/compiler_explorer.rb --compiler vc_v19_44_VS17_14_x64 --lang c --args "/Zc:preprocessor"
#
# Exit status: 0 if every check compiles and its program exits with 0, else 1.

require 'json'
require 'net/http'
require 'optparse'
require 'uri'

ROOT = File.expand_path('..', __dir__)
API = 'https://godbolt.org/api'

# Default checks: the C test as C and as C++, with the latest MSVC.
DEFAULT_CHECKS = [
  { compiler: 'vc_v19_latest_x64', lang: 'c', args: '/Zc:preprocessor /W4' },
  { compiler: 'vcpp_v19_latest_x64', lang: 'c++', args: '/std:c++20 /Zc:preprocessor /W4' }
].freeze

def api_request(request)
  uri = request.uri
  request['Accept'] = 'application/json'
  Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 30, read_timeout: 120) do |http|
    response = http.request(request)
    abort "#{uri}: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)
  end
end

def inline_headers(source)
  iter = File.read(File.join(ROOT, 'pp_iter.h'))
  enum = File.read(File.join(ROOT, 'pp_enum.h')).sub('#include "pp_iter.h"', '')
  source.sub('#include "pp_iter.h"', iter).sub('#include "pp_enum.h"', enum)
end

def lines(entries)
  (entries || []).map { |e| e['text'] }
end

# Returns true if the source compiles and the program exits with 0.
def run_check(source, compiler:, lang:, args:)
  request = Net::HTTP::Post.new(URI("#{API}/compiler/#{compiler}/compile"), 'Content-Type' => 'application/json')
  request.body = JSON.generate(source: source, lang: lang,
                               options: { userArguments: args,
                                          filters: { execute: true },
                                          compilerOptions: { executorRequest: true } })
  result = api_request(request)
  build = result['buildResult'] || result
  diagnostics = lines(build['stdout']) + lines(build['stderr'])
  ok = build['code'] == 0 && result['didExecute'] && result['code'] == 0
  puts "#{ok ? 'PASS' : 'FAIL'}  #{compiler} (#{lang}) #{args}"
  diagnostics.reject { |l| l.strip.empty? || l.strip == 'example.c' || l.strip == 'example.cpp' }
             .each { |l| puts "      #{l}" }
  puts "      build exit #{build['code']}" if build['code'] != 0
  if result['didExecute']
    lines(result['stdout']).each { |l| puts "      | #{l}" }
    puts "      program exit #{result['code']}" if result['code'] != 0
  end
  ok
end

options = { source: File.join(ROOT, 'test', 'pp_c_test.c') }
OptionParser.new do |opts|
  opts.banner = 'Usage: tools/compiler_explorer.rb [options]'
  opts.on('--source FILE', 'Test source (default test/pp_c_test.c)') { |f| options[:source] = f }
  opts.on('--compiler ID', 'Compiler Explorer compiler id (see --list)') { |c| options[:compiler] = c }
  opts.on('--lang LANG', 'c or c++ (with --compiler)') { |l| options[:lang] = l }
  opts.on('--args ARGS', 'Compiler arguments (with --compiler)') { |a| options[:args] = a }
  opts.on('--list', 'List the MSVC compiler ids and exit') { options[:list] = true }
end.parse!

if options[:list]
  %w[c c++].each do |lang|
    compilers = api_request(Net::HTTP::Get.new(URI("#{API}/compilers/#{lang}?fields=id,name")))
    compilers.select { |c| c['name'] =~ /msvc/i }.each { |c| puts "#{lang.ljust(4)} #{c['id'].ljust(28)} #{c['name']}" }
  end
  exit 0
end

checks = if options[:compiler]
           [{ compiler: options[:compiler], lang: options.fetch(:lang, 'c'), args: options.fetch(:args, '') }]
         else
           DEFAULT_CHECKS
         end
source = inline_headers(File.read(options[:source]))
results = checks.map { |check| run_check(source, **check) }
exit(results.all? ? 0 : 1)
