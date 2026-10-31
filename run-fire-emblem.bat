@echo off
rem Starts Fire Emblem (04007EF01F8AE000) on this build with the settings it needs.
rem Usage: run-fire-emblem.bat "<path to the game's exefs\main>"
rem
rem EDEN_NX2_TENSOR: tensor-core (HMMA) emulation, which the game's compute shaders need.
rem EDEN_NX2_BINDLESS_FALLBACK: textures whose handles the game reads from memory at run time
rem   sample neutral grey instead of rejecting the whole shader.
rem EDEN_NX2_NAN_CONSTANT_FIX: the post-process constants (exposure, tonemap, bloom, UI fade)
rem   arrive as NaN and the HDR paper white as 0, which blanks the frame; patch them.
rem EDEN_NX2_CROP_*: the game draws its 1280x720 output into the corner of a 3840x2160 image.
rem EDEN_NX2_SKIP_PS_HASH: one battlefield draw resets the host GPU when the tutorial loads;
rem   skipping it avoids the crash (some battlefield graphics are missing).
setlocal
if "%~1"=="" (
    echo Usage: %~nx0 "C:\path\to\Fire Emblem\exefs\main"
    exit /b 1
)
set "EDEN_NX2_TENSOR=1"
set "EDEN_NX2_BINDLESS_FALLBACK=1"
set "EDEN_NX2_NAN_CONSTANT_FIX=1"
set "EDEN_NX2_CROP_WIDTH=1280"
set "EDEN_NX2_CROP_HEIGHT=720"
set "EDEN_NX2_SKIP_PS_HASH=c25f0c0e843817af"
start "" "%~dp0build-cli\bin\eden-cli.exe" -g "%~1"
