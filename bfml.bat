@echo off

rem Driver script for Branflake

if %1. == .     goto usage


bftrans < %1.bf > %1.asm
ml /Fe%1.exe /Fo%1.obj %1.asm

goto fin


:usage
echo Usage: bfml filename
echo (Uses filename.bf as source, creates filename.asm and .exe.)
goto fin


:fin
