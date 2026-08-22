// play_event_zig - A minimal sample showing how to initialize the runtime,
// load a project, play an event and adjust its playback speed using a
// float parameter. The byProd bindings come from bindings\zig in this
// repository, wired up as a module in build.zig.

const std = @import("std");
const byprod = @import("byprod");

// The path to the main runtime project file. You can find a copy in this
// repository's samples\assets folder along with the sound bank file(s)
// (.bybank). You, as the programmer, load the .byprod file. The
// runtime decides when to load the .bybank file(s) using the sound
// bank callbacks (see below).
const PROJECT_FILE = "sample_project.byprod";

// The path to the event we want to play, inside the project.
const EVENT_PATH = "event:/Drums";

// The name of the float parameter we use to adjust the playback speed
// of the drum loop.
const PARAM_NAME = "Speed";

// We adjust the the playback speed using a sine wave.
const PARAM_MIN: f32 = 0.8;
const PARAM_MAX: f32 = 1.2;
const SWEEP_PERIOD_SECONDS: f64 = 4.0;

// How much to sleep between sample program updates.
const STEP_MILLISECONDS: i64 = 10;

var gIo: std.Io = undefined;

// Helper function for reading the contents of a file into memory.
// The libc allocator is used for the buffers, mirroring the C sample's malloc/free.
fn readWholeFile(path: []const u8) ?[]u8 {
    const file = std.Io.Dir.cwd().openFile(gIo, path, .{}) catch return null;
    defer file.close(gIo);

    const end = file.length(gIo) catch return null;
    if (end == 0) {
        return null;
    }

    const size: usize = @intCast(end);
    const buffer = std.heap.c_allocator.alloc(u8, size) catch return null;

    const bytesRead = file.readPositionalAll(gIo, buffer, 0) catch 0;
    if (bytesRead != size) {
        std.heap.c_allocator.free(buffer);
        return null;
    }

    return buffer;
}

// This function is installed as the print hook for the runtime. Whenever
// the byProd runtime prints something, it uses this function to do it.
fn printHook(message: [*:0]const u8, printType: byprod.PrintType, user: ?*anyopaque) callconv(.c) void {
    _ = user;

    const prefix = switch (printType) {
        .warning => "warning",
        .err => "error",
        else => "info",
    };

    std.debug.print("[byProd {s}] {s}\n", .{ prefix, message });
}

// This function gets called by the byProd runtime when it wants to read a
// sound bank. We read the whole file into memory and keep it loaded for
// as long as byProd needs it. Thus, we tell byProd not to create an
// internal copy (copyData = 0).
fn getSoundBankData(name: [*:0]const u8, out: *byprod.SoundBankData, user: ?*anyopaque) callconv(.c) c_int {
    _ = user;

    var pathBuffer: [1024]u8 = undefined;
    const path = std.fmt.bufPrint(&pathBuffer, "{s}.bybank", .{name}) catch return 0;

    const bytes = readWholeFile(path) orelse return 0;

    out.bytes = bytes.ptr;
    out.length = @intCast(bytes.len);
    out.copyData = 0;

    return 1;
}

// This is called when byProd no longer needs the data for a given sound bank.
// We simply free the data allocated in getSoundBankData() above.
fn releaseSoundBankData(name: [*:0]const u8, data: *const byprod.SoundBankData, user: ?*anyopaque) callconv(.c) void {
    _ = name;
    _ = user;

    const bytes: [*]const u8 = @ptrCast(data.bytes.?);
    std.heap.c_allocator.free(bytes[0..data.length]);
}

pub fn main(init: std.process.Init) !void {
    gIo = init.io;

    // You should always check the byProd version reported by the dynamic library
    // and make sure it matches the version your app was built against.
    if (byprod.version() != byprod.VERSION) {
        std.debug.print(
            "Library version 0x{x:0>8} does not match binding version 0x{x:0>8}.\n",
            .{ byprod.version(), byprod.VERSION },
        );
        return error.VersionMismatch;
    }

    // Install the print hook. The second parameter is anything you want the user
    // parameter to hold.
    byprod.setPrint(printHook, null);

    // Create the byProd sound manager. This is the main "object" of the byProd
    // runtime in a game, and needs to outlive any other resources created/loaded
    // by the runtime. The settings start from byProd's defaults via the init
    // call (the app environment, no flags, the device's own sample rate);
    // adjust members before create when they are not what you want.
    var settings: byprod.SoundManagerSettings = undefined;
    byprod.soundManagerSettingsInit(&settings);

    const soundManager = byprod.soundManagerCreate(&settings) orelse {
        std.debug.print("soundManagerCreate failed.\n", .{});
        return error.CreateFailed;
    };

    // Install the sound bank callbacks, so byProd knows what to call when it wants
    // to load/unload a sound bank. As with setPrint(), the last parameter is
    // anything you want the user parameter to hold.
    byprod.soundManagerSetSoundBankCallbacks(soundManager, getSoundBankData, releaseSoundBankData, null);

    const projectBytes = readWholeFile(PROJECT_FILE) orelse {
        std.debug.print("Could not read \"{s}\".\n", .{PROJECT_FILE});
        return error.ProjectReadFailed;
    };

    // Load the project into memory. The bytes are always copied during load, so
    // we can free the data immediately afterwards.
    const loaded = byprod.soundManagerLoadProject(soundManager, projectBytes.ptr, projectBytes.len);
    std.heap.c_allocator.free(projectBytes);

    if (loaded == 0) {
        std.debug.print("Loading \"{s}\" failed.\n", .{PROJECT_FILE});
        return error.ProjectLoadFailed;
    }

    // Get a pointer to the event description for our sample event, found at EVENT_PATH.
    // Event descriptions are created when the project loads and they stay alive until
    // the project is unloaded.
    const description = byprod.soundManagerGetEventDescription(soundManager, EVENT_PATH) orelse {
        std.debug.print("The project has no event \"{s}\".\n", .{EVENT_PATH});
        return error.EventNotFound;
    };

    // An event can have multiple parameters that can be set from the game code at runtime.
    // Parameter indices can be queried up-front, using the parameter name. This way
    // we can use the parameter index to actually set the parameter later, which is faster
    // than setting it by name.
    const paramIndex = byprod.eventDescriptionGetParameterIndex(description, PARAM_NAME);

    if (paramIndex == byprod.INVALID_PARAMETER_INDEX) {
        std.debug.print("The event has no parameter \"{s}\".\n", .{PARAM_NAME});
        return error.ParameterNotFound;
    }

    // You can create any number of instances of an event. For this you need the event
    // description pointer. Event instances need to be manually freed later, but you
    // can ask the runtime to automatically free an event after it has finished, after
    // a fade-out etc.
    const instance = byprod.eventDescriptionCreateInstance(description) orelse {
        std.debug.print("Creating an instance of \"{s}\" failed.\n", .{EVENT_PATH});
        return error.InstanceCreateFailed;
    };

    std.debug.print(
        "Playing \"{s}\", sweeping \"{s}\" between {d} and {d}.\n",
        .{ EVENT_PATH, PARAM_NAME, PARAM_MIN, PARAM_MAX },
    );

    // Instances start in the stopped-state, so let's start it!
    byprod.eventInstanceStart(instance);

    var elapsedSeconds: f64 = 0.0;
    var step: u32 = 0;

    // This loop runs while the instance is playing.
    while (byprod.eventInstanceGetState(instance) == .playing) {
        // Update the sound manager. You'll want to do this once per game update / frame.
        // The sound manager tracks time internally, so you don't need to pass delta time here.
        byprod.soundManagerUpdate(soundManager);

        // Modulate the playback speed over time using a sine wave. Print out the value every 20th step.
        const phase = elapsedSeconds * (std.math.tau / SWEEP_PERIOD_SECONDS);
        const normalized: f32 = @floatCast(0.5 + 0.5 * @sin(phase));
        const value = PARAM_MIN + (PARAM_MAX - PARAM_MIN) * normalized;
        if (step % 20 == 0) {
            std.debug.print("Speed: {d:.2}\n", .{value});
        }

        // Update the parameter value for the playing instance.
        byprod.eventInstanceSetParameterByIndex(instance, paramIndex, value);

        gIo.sleep(.fromMilliseconds(STEP_MILLISECONDS), .awake) catch {};
        elapsedSeconds += @as(f64, @floatFromInt(STEP_MILLISECONDS)) / 1000.0;
        step += 1;
    }

    std.debug.print("Done.\n", .{});

    // Release the instance.
    byprod.eventInstanceRelease(instance);

    // Shut down the sound manager.
    byprod.soundManagerDestroy(soundManager);
}
