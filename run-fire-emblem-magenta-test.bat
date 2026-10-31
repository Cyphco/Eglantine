@echo off
rem Diagnostic: clears the game's window images to magenta before it draws its 1280x720 picture.
rem Magenta on screen (around or instead of the picture) means presentation works and the black
rem comes from the game's own rendering; still all black means the picture never reaches the screen.
set "EDEN_NX2_TENSOR=1"
set "EDEN_NX2_DEBUG_CLEAR=window"
start "" "%~dp0build-cli\bin\eden-cli.exe" -g "C:\Users\Benny\Desktop\Game\Fire Emblem\131072\exefs\main"
