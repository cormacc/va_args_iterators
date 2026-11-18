@echo off
rem Regenerate pp_iter.h. Extra arguments go to the generator, e.g. --limit 127.
rem The output goes to a temporary file first, so that a failed run keeps the existing header.
cd /d "%~dp0"
ruby pp_iterators.rb %* > pp_iter.h.tmp || (del pp_iter.h.tmp & exit /b 1)
move /y pp_iter.h.tmp pp_iter.h > nul
