@echo off
setlocal

rem Builds the Timbre raylib sample for the web with Emscripten. See
rem README.md for the full prerequisites, in short an activated emsdk
rem (emcc on PATH), then:
rem
rem     build_web.bat <raylib dir> <timbre include dir> <timbre archive>
rem
rem     <raylib dir>          an unpacked raylib webassembly release
rem     <timbre include dir>  the SDK folder holding timbre\timbre.h
rem     <timbre archive>      the SDK's timbre-emscripten.a

rem Expanded to full paths before the cd below, so relative paths stay
rem relative to where the caller ran this from.
set "RAYLIB_DIR=%~f1"
set "TIMBRE_INCLUDE=%~f2"
set "TIMBRE_ARCHIVE=%~f3"

if "%TIMBRE_ARCHIVE%"=="" (
    echo usage: build_web.bat ^<raylib dir^> ^<timbre include dir^> ^<timbre archive^>
    echo.
    echo     ^<raylib dir^>          an unpacked raylib webassembly release
    echo     ^<timbre include dir^>  the SDK folder holding timbre\timbre.h
    echo     ^<timbre archive^>      the SDK's timbre-emscripten.a
    exit /b 1
)

cd /d "%~dp0"

where emcc >nul 2>nul
if errorlevel 1 (
    echo build_web: emcc is not on PATH. Install and activate emsdk first.
    exit /b 1
)

rem The webassembly release package names the library libraylib.web.a,
rem a source build of PLATFORM_WEB produces libraylib.a. Take either.
set "RAYLIB_LIB=%RAYLIB_DIR%\lib\libraylib.web.a"
if not exist "%RAYLIB_LIB%" set "RAYLIB_LIB=%RAYLIB_DIR%\lib\libraylib.a"

if not exist "%RAYLIB_LIB%" (
    echo build_web: no raylib webassembly build under "%RAYLIB_DIR%".
    echo Download a raylib release's _webassembly package and unpack it
    echo there.
    exit /b 1
)

if not exist "%TIMBRE_INCLUDE%\timbre\timbre.h" (
    echo build_web: "%TIMBRE_INCLUDE%" does not hold timbre\timbre.h.
    exit /b 1
)

if not exist "%TIMBRE_ARCHIVE%" (
    echo build_web: "%TIMBRE_ARCHIVE%" is not there. Pass the path to
    echo timbre-emscripten.a from a Timbre SDK or build.
    exit /b 1
)

if not exist "..\assets\sample_project.timbre" (
    echo build_web: the shared samples\assets folder is missing
    echo sample_project.timbre, see README.md.
    exit /b 1
)

if not exist build mkdir build

call emcc -c main.c -Os -Wall ^
  -I"%TIMBRE_INCLUDE%" -I"%RAYLIB_DIR%\include" ^
  -o build\main.o
if errorlevel 1 exit /b 1

rem em++ rather than emcc: Timbre is C++ internally, so the link needs
rem Emscripten's C++ support libraries. --embed-file bakes the shared
rem samples\assets folder into the module at the file system root.
call em++ build\main.o "%TIMBRE_ARCHIVE%" "%RAYLIB_LIB%" ^
  -Os ^
  -sUSE_GLFW=3 ^
  -sALLOW_MEMORY_GROWTH ^
  --embed-file ../assets@/ ^
  -o build\index.html
if errorlevel 1 exit /b 1

echo.
echo Built build\index.html. Browsers will not run wasm from a file://
echo URL, so serve the folder over http, for example:
echo.
echo     python -m http.server -d build
echo.
echo and open http://localhost:8000/
