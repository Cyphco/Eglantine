@echo off
rem Like run-fire-emblem.bat, plus frame dumps on demand: run dump-frame.bat while playing.
set "EDEN_NX2_TENSOR=1"
set "EDEN_NX2_SKIP_PS_HASH=c25f0c0e843817af"
set "EDEN_NX2_BINDLESS_FALLBACK=1"
set "EDEN_NX2_NAN_CONSTANT_FIX=1"
set "EDEN_NX2_CROP_WIDTH=1280"
set "EDEN_NX2_CROP_HEIGHT=720"
set "EDEN_NX2_DUMP_DIR=C:\Users\Benny\Desktop\Eglantine-fe-debug\manual"
if not exist "%EDEN_NX2_DUMP_DIR%" mkdir "%EDEN_NX2_DUMP_DIR%"
start "" "%~dp0build-cli\bin\eden-cli.exe" -g "C:\Users\Benny\Desktop\Game\Fire Emblem\131072\exefs\main"
