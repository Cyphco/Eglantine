@echo off
rem While run-fire-emblem-debug.bat is running: dump the current frame's post-process chain
rem (scene, upscaler output, tonemap, final source, UI) to Eglantine-fe-debug\manual.
> "C:\Users\Benny\Desktop\Eglantine-fe-debug\manual\dump-now" echo 8110773000,81104a3000,8110593000,8110863000,8112319000,8105fa0000,8111f59000,810874a000,81101ea000
echo Frame dump requested.
timeout /t 2 >nul
