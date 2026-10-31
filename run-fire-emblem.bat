@echo off
rem Fire Emblem on the patched nx2 build.
rem EDEN_NX2_TENSOR: nx2's tensor-core (HMMA) emulation, which this game's compute shaders need.
rem EDEN_NX2_BINDLESS_FALLBACK: textures whose handles the game reads from memory at run time
rem sample neutral grey instead of rejecting the whole shader (materials look wrong, but the
rem frame renders).
rem EDEN_NX2_NAN_CONSTANT_FIX: the post-process constants (exposure, tonemap, UI fade) arrive as
rem NaN and the HDR paper white as 0, which blanks the frame; patch them to 1.0 / 100 nits.
rem EDEN_NX2_CROP_*: the game draws its 1280x720 output into the corner of a 3840x2160 image.
rem EDEN_NX2_SKIP_PS_HASH: one battlefield draw (pixel shader hash c25f0c0e843817af) resets the
rem host GPU when the tutorial loads; skipping it avoids the crash (some graphics are missing).
set "EDEN_NX2_TENSOR=1"
set "EDEN_NX2_SKIP_PS_HASH=c25f0c0e843817af"
set "EDEN_NX2_BINDLESS_FALLBACK=1"
set "EDEN_NX2_NAN_CONSTANT_FIX=1"
set "EDEN_NX2_CROP_WIDTH=1280"
set "EDEN_NX2_CROP_HEIGHT=720"
start "" "%~dp0build-cli\bin\eden-cli.exe" -g "C:\Users\Benny\Desktop\Game\Fire Emblem\131072\exefs\main"
