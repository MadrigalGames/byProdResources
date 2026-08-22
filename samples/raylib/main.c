// raylib sample - Plays an event through raylib and raygui, with play and
// stop buttons and two sliders adjusting event parameters. Builds for the
// web with Emscripten, and on the desktop as an ordinary raylib app.

// The sound manager runs in host mixed mode: byProd opens no audio device
// and runs no threads. raylib owns the speakers, and every frame the mixed
// audio is pulled out of byProd and pushed into a raylib AudioStream.

// Include the byProd header. The entire runtime API is found here.
#include <byprod/byprod.h>

#include "raylib.h"

#define RAYGUI_IMPLEMENTATION
#include "raygui.h"

#include <stdio.h>
#include <stdlib.h>

#if defined(__EMSCRIPTEN__)
    #include <emscripten/emscripten.h>
#endif

#define PROJECT_FILE "sample_project.byprod"

// The path to the event we want to play, and the names of the two float
// parameters the sliders drive.
#define EVENT_PATH "event:/Drums"
#define SPEED_PARAM "Speed"
#define CUTOFF_PARAM "Cutoff"

// The rate the sound manager mixes at, which is also the rate the raylib stream plays at.
#define SAMPLE_RATE 44100u

// Frames pulled per bpdSoundManagerMix() call, and the size of each of
// the stream's two buffers.
#define MIX_CHUNK_FRAMES 2048u

// Everything lives in globals because the browser main loop is a plain
// callback (see emscripten_set_main_loop below).
static BpdSoundManager* soundManager;
static BpdEventInstance* instance;
static uint32_t speedParam = BPD_INVALID_PARAMETER_INDEX;
static uint32_t cutoffParam = BPD_INVALID_PARAMETER_INDEX;

static AudioStream stream;
static float mixBuffer[MIX_CHUNK_FRAMES * 2];

static float speed = 1.0f;
static float cutoff = 10000.0f;

// Helper function for reading the contents of a file into memory.
static void* readWholeFile(const char* path, size_t* outSize)
{
    FILE* file = fopen(path, "rb");

    if (file == NULL)
    {
        return NULL;
    }

    fseek(file, 0, SEEK_END);
    long size = ftell(file);
    fseek(file, 0, SEEK_SET);

    if (size <= 0)
    {
        fclose(file);
        return NULL;
    }

    void* buffer = malloc((size_t)size);

    if (buffer == NULL)
    {
        fclose(file);
        return NULL;
    }

    size_t bytesRead = fread(buffer, 1, (size_t)size, file);
    fclose(file);

    if (bytesRead != (size_t)size)
    {
        free(buffer);
        return NULL;
    }

    *outSize = (size_t)size;
    return buffer;
}

// This function is installed as the print hook for the runtime. Whenever
// the byProd runtime prints something, it uses this function to do it. In
// the browser the output lands in the developer console.
static void printHook(const char* message, BpdPrintType type, void* user)
{
    (void)user;

    const char* prefix = "info";

    if (type == BPD_PRINT_WARNING)
    {
        prefix = "warning";
    }
    else if (type == BPD_PRINT_ERROR)
    {
        prefix = "error";
    }

    printf("[byprod %s] %s\n", prefix, message);
}

// This function gets called by the byProd runtime when it wants to read a
// sound bank. We read the whole file into memory and keep it loaded for
// as long as byProd needs it. Thus, we tell byProd not to create an
// internal copy (copyData = 0).
static int getSoundBankData(const char* name, BpdSoundBankData* out, void* user)
{
    (void)user;

    char path[1024];
    snprintf(path, sizeof(path), "%s.bybank", name);

    size_t size = 0;
    void* bytes = readWholeFile(path, &size);

    if (bytes == NULL)
    {
        return 0;
    }

    out->bytes = bytes;
    out->length = (uint32_t)size;
    out->copyData = 0;

    return 1;
}

// This is called when byProd no longer needs the data for a given sound bank.
// We simply free the data allocated in getSoundBankData() above.
static void releaseSoundBankData(const char* name, const BpdSoundBankData* data, void* user)
{
    (void)name;
    (void)user;

    free((void*)data->bytes);
}

static const char* stateName(BpdEventInstanceState state)
{
    switch (state)
    {
        case BPD_EVENT_STOPPED:  return "stopped";
        case BPD_EVENT_PLAYING:  return "playing";
        case BPD_EVENT_PAUSED:   return "paused";
        case BPD_EVENT_FINISHED: return "finished";
        default:                    return "?";
    }
}

// Feeds the raylib stream. Whenever the stream has room for another
// buffer, one chunk of mixed audio is pulled out of byProd and pushed
// in. Browsers keep audio suspended until the user first interacts with
// the page, so until that click the stream consumes nothing and this
// function has nothing to do.
static void pumpAudio(void)
{
    while (IsAudioStreamProcessed(stream))
    {
        bpdSoundManagerMix(soundManager, mixBuffer, MIX_CHUNK_FRAMES);
        UpdateAudioStream(stream, mixBuffer, MIX_CHUNK_FRAMES);
    }
}

// One frame of the sample: pump the audio, then draw the controls.
static void frame(void)
{
    // Update the sound manager once per frame. In host mixed mode it times
    // itself by the frames mixed below.
    bpdSoundManagerUpdate(soundManager);

    pumpAudio();

    BeginDrawing();
    ClearBackground(RAYWHITE);

    GuiLabel((Rectangle){ 20, 12, 560, 24 },
        "byProd raylib sample: " EVENT_PATH);

    if (GuiButton((Rectangle){ 20, 52, 120, 32 }, "Play"))
    {
        bpdEventInstanceStart(instance);
    }

    if (GuiButton((Rectangle){ 156, 52, 120, 32 }, "Stop"))
    {
        bpdEventInstanceStop(instance);
    }

    GuiLabel((Rectangle){ 300, 52, 260, 32 },
        TextFormat("State: %s", stateName(bpdEventInstanceGetState(instance))));

    GuiSlider((Rectangle){ 90, 120, 380, 24 },
        SPEED_PARAM, TextFormat("%.2f x", (double)speed),
        &speed, 0.25f, 4.0f);

    bpdEventInstanceSetParameterByIndex(instance, speedParam, speed);

    GuiSlider((Rectangle){ 90, 160, 380, 24 },
        CUTOFF_PARAM, TextFormat("%.0f Hz", (double)cutoff),
        &cutoff, 500.0f, 10000.0f);

    bpdEventInstanceSetParameterByIndex(instance, cutoffParam, cutoff);

    EndDrawing();
}

int main(void)
{
    // You should always check the byProd version reported by the library
    // and make sure it matches the version your app was built against.
    if (bpdVersion() != BPD_VERSION)
    {
        fprintf(stderr, "Library version 0x%08x does not match header version 0x%08x.\n",
            bpdVersion(), BPD_VERSION);
        return 1;
    }

    // Install the print hook. The second parameter is anything you want the
    // user parameter to hold.
    bpdSetPrint(printHook, NULL);

    // Create the byProd sound manager, here in host mixed mode: no audio
    // device, no threads, audio only moves when bpdSoundManagerMix() is
    // called. The sample rate is the mixing rate and must be real in this
    // mode. The settings start from byProd's defaults and only what
    // differs is set.
    BpdSoundManagerSettings settings;
    bpdSoundManagerSettingsInit(&settings);

    settings.flags = BPD_SOUND_MANAGER_HOST_MIXED;
    settings.sampleRate = SAMPLE_RATE;

    soundManager = bpdSoundManagerCreate(&settings);

    if (soundManager == NULL)
    {
        fprintf(stderr, "bpdSoundManagerCreate failed.\n");
        return 1;
    }

    // Install the sound bank callbacks, so byProd knows what to call when
    // it wants to load/unload a sound bank.
    bpdSoundManagerSetSoundBankCallbacks(
        soundManager, getSoundBankData, releaseSoundBankData, NULL);

    size_t projectSize = 0;
    void* projectBytes = readWholeFile(PROJECT_FILE, &projectSize);

    if (projectBytes == NULL)
    {
        fprintf(stderr, "Could not read \"%s\".\n", PROJECT_FILE);
        return 1;
    }

    // Load the project into memory. The bytes are always copied during
    // load, so we can free the data immediately afterwards.
    int loaded = bpdSoundManagerLoadProject(soundManager, projectBytes, projectSize);
    free(projectBytes);

    if (!loaded)
    {
        fprintf(stderr, "Loading \"%s\" failed.\n", PROJECT_FILE);
        return 1;
    }

    // Get a pointer to the event description for our sample event. Event
    // descriptions are created when the project loads and stay alive until
    // the project is unloaded.
    BpdEventDescription* description =
        bpdSoundManagerGetEventDescription(soundManager, EVENT_PATH);

    if (description == NULL)
    {
        fprintf(stderr, "The project has no event \"%s\".\n", EVENT_PATH);
        return 1;
    }

    // Create one instance of the event. Instances need to be manually
    // released later.
    instance = bpdEventDescriptionCreateInstance(description);

    if (instance == NULL)
    {
        fprintf(stderr, "Creating an instance of \"%s\" failed.\n", EVENT_PATH);
        return 1;
    }

    // Parameter indices can be queried up-front, using the parameter name.
    // This way we can use the index to set the parameter later, which is
    // faster than setting it by name.
    speedParam = bpdEventDescriptionGetParameterIndex(description, SPEED_PARAM);
    cutoffParam = bpdEventDescriptionGetParameterIndex(description, CUTOFF_PARAM);

    if (speedParam == BPD_INVALID_PARAMETER_INDEX
        || cutoffParam == BPD_INVALID_PARAMETER_INDEX)
    {
        fprintf(stderr, "The event is missing the \"%s\" or \"%s\" parameter.\n",
            SPEED_PARAM, CUTOFF_PARAM);
        return 1;
    }

    InitWindow(600, 340, "byProd raylib sample");
    InitAudioDevice();

    // Each of the stream's two buffers holds exactly one mix chunk.
    SetAudioStreamBufferSizeDefault((int)MIX_CHUNK_FRAMES);

    // 32 bit samples are floats to raylib, matching what the mix produces.
    stream = LoadAudioStream(SAMPLE_RATE, 32, 2);
    PlayAudioStream(stream);

    // Prime both halves, so playback never begins on an empty stream.
    pumpAudio();

    SetTargetFPS(60);

#if defined(__EMSCRIPTEN__)
    // The browser owns the loop: frame() runs once per display refresh and
    // this call does not return.
    emscripten_set_main_loop(frame, 0, 1);
#else
    while (!WindowShouldClose())
    {
        frame();
    }
#endif

    // Desktop teardown. The web build never gets here.
    UnloadAudioStream(stream);
    CloseAudioDevice();
    CloseWindow();

    bpdEventInstanceRelease(instance);
    bpdSoundManagerDestroy(soundManager);

    return 0;
}
