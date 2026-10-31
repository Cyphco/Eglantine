@echo off
setlocal EnableExtensions
cd /d "%~dp0"
set "SRC=%~dp0."
set "BUILD_DIR=%~dp0build-cli"

for /f "usebackq delims=" %%V in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VS_INSTALL=%%V"
call "%VS_INSTALL%\VC\Auxiliary\Build\vcvars64.bat" || exit /b 1
set "NINJA_EXE=%VS_INSTALL%\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja\ninja.exe"
set "PATH=%ProgramFiles%\Git\cmd;%ProgramFiles%\Git\usr\bin;%PATH%"

git -C "%SRC%" submodule update --init --recursive || exit /b 1

"%ProgramFiles%\CMake\bin\cmake.exe" -S "%SRC%" -B "%BUILD_DIR%" -G Ninja ^
    "-DCMAKE_MAKE_PROGRAM:FILEPATH=%NINJA_EXE%" ^
    -DCMAKE_C_COMPILER=cl.exe -DCMAKE_CXX_COMPILER=cl.exe ^
    -DCMAKE_BUILD_TYPE=RelWithDebInfo ^
    -DENABLE_QT=OFF -DYUZU_CMD=ON -DYUZU_ROOM=OFF ^
    -DBUILD_TESTING=OFF -DYUZU_TESTS=OFF -DDYNARMIC_TESTS=OFF ^
    -DENABLE_CUBEB=OFF -DENABLE_RESHADE=OFF ^
    -DENABLE_OPENGL=OFF -DENABLE_WEB_SERVICE=OFF ^
    -DENABLE_LTO=OFF -DYUZU_DISABLE_LLVM=ON -DENABLE_WERROR=OFF ^
    "-DGLSLANGVALIDATOR=%LOCALAPPDATA%\Android\Sdk\emulator\lib64\vulkan\glslangValidator.exe" || exit /b 1

"%ProgramFiles%\CMake\bin\cmake.exe" --build "%BUILD_DIR%" --target yuzu-cmd --parallel %NUMBER_OF_PROCESSORS% || exit /b 1
echo BUILD OK
