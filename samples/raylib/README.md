# Timbre raylib sample

A browser demo of the Timbre audio runtime inside a
[raylib](https://www.raylib.com) + [raygui](https://github.com/raysan5/raygui)
app. Play and stop buttons, a playback speed slider and a lowpass
cutoff slider, both driving Timbre event parameters live.

The interesting part is the audio path. The sound manager is created
with `TIMBRE_SOUND_MANAGER_HOST_MIXED`, so Timbre opens no audio
device and runs no thread of its own. Every frame the sample pulls
mixed stereo out of the runtime with `timbreSoundManagerMix()` and
pushes it into a raylib `AudioStream`. The same arrangement works on 
any engine with a push style audio API.

`raygui.h` (zlib license) is vendored here, v5.0.

## Prerequisites

- An installed and activated [emsdk](https://github.com/emscripten-core/emsdk),
  so `emcc` is on PATH. The Timbre wasm archive is built with
  Emscripten 6.0.6.
- A raylib webassembly build: grab the `raylib-X.X_webassembly` package
  from the [raylib releases](https://github.com/raysan5/raylib/releases)
  and unpack it. Its location is the first argument to `build_web.bat`.
- The Timbre SDK. The build needs its include folder and
  `bin\timbre-wasm32-emscripten.a`, passed as the second and third arguments.

## Assets

The shared `samples\assets` folder holds the sample project's build output:

    ..\assets\sample_project.timbre
    ..\assets\main.timbrebank

Both were built from the SDK's `samples\sample_project`. The web build
embeds the folder into the module, and the sample loads the files with
plain `fopen`.

Both sliders drive float parameters on the Drums event: `Speed` feeds
the playback speed of the drum loop, and `Cutoff` feeds the frequency
of a lowpass Biquad Resonant Filter on it.

## Building

    build_web.bat <raylib dir> <timbre include dir> <timbre archive>

For example, against an unpacked SDK:

    build_web.bat C:\raylib_webassembly C:\timbre-sdk\include C:\timbre-sdk\bin\timbre-wasm32-emscripten.a

The output is `build\index.html` plus the wasm and JS beside it.
Browsers refuse wasm from `file://`, so serve the folder:

    python -m http.server -d build

and open http://localhost:8000/. Click Play. The first click is also
what unlocks audio, since browsers keep sound suspended until user input.

## Desktop

`main.c` is portable: without `__EMSCRIPTEN__` it runs an ordinary
`while (!WindowShouldClose())` loop, so it also builds against desktop
raylib and the regular Timbre library (`Timbre.lib` / `libTimbre.so`).
Run it with the shared `samples\assets` folder as the working directory
so the plain file paths resolve. No desktop build script is provided
here.
