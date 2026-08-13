// ======================================
// Timbre - audio runtime
// Copyright 2026 Madrigal Ltd.
// ======================================

// Zig bindings over the Timbre C API, covering all of timbre.h. Link
// the Timbre library from the SDK beside these.

// The module name is the namespace, so the timbre prefix is stripped:
// timbre.soundManagerCreate() here is timbreSoundManagerCreate() in C.
// The public interface below is the whole API. The extern declarations
// of the C symbol names and signatures can be found in their own section
// at the bottom.

// Threading: The public API of Timbre is supposed to be called from only
// one thread at a time. The library uses threads internally for mixing,
// and can be hooked into a host-provided job system for async wave data
// decoding. See soundManagerSetJobScheduler() for more information.
// A sound manager created with SOUND_MANAGER_HOST_MIXED runs no internal
// threads at all. The host pulls the mixed audio with soundManagerMix().

// ======================================
// Library version.

pub const VERSION_MAJOR = 2;
pub const VERSION_MINOR = 0;
pub const VERSION_PATCH = 1;

pub fn makeVersion(major: u32, minor: u32, patch: u32) u32 {
    return (major << 16) | (minor << 8) | patch;
}

pub const VERSION: u32 = makeVersion(VERSION_MAJOR, VERSION_MINOR, VERSION_PATCH);

// Returns the version the library was built as. Compare against VERSION
// from the bindings you compiled against before using anything else.
pub const version = timbreVersion;

// ======================================
// Host hooks.

pub const AllocFn = *const fn (size: usize, user: ?*anyopaque) callconv(.c) ?*anyopaque;

pub const FreeFn = *const fn (ptr: ?*anyopaque, user: ?*anyopaque) callconv(.c) void;

// Replaces the allocator, which has to happen before anything else is called.
// The callbacks must be thread safe since the audio mixer thread allocates
// through them too.
pub const setAllocator = timbreSetAllocator;

// Non-exhaustive, so a print type added to the runtime later maps to the
// else branch instead of being undefined behavior.
pub const PrintType = enum(c_int) {
    info = 0,
    warning = 1,
    err = 2,
    _,
};

pub const PrintFn = *const fn (message: [*:0]const u8, printType: PrintType, user: ?*anyopaque) callconv(.c) void;

pub const setPrint = timbreSetPrint;

pub const AssertFn = *const fn (message: [*:0]const u8, file: [*:0]const u8, line: c_int, user: ?*anyopaque) callconv(.c) void;

// Replaces what runs when a runtime assertion fails. Without a handler the
// message goes to the print hook and the process aborts. A handler that
// returns instead of aborting makes the runtime continue past the failure
// (usually with an early-out or another way to handle the error).
pub const setAssertHandler = timbreSetAssertHandler;

// The work a scheduler is asked to run.
pub const JobFn = *const fn (jobData: ?*anyopaque) callconv(.c) void;

// A function which schedules a job to be run. Eg. can be used to hook into the job system of a game engine.
pub const ScheduleJobFn = *const fn (jobFn: JobFn, jobData: ?*anyopaque, user: ?*anyopaque) callconv(.c) void;

// A function which waits until every scheduled job has run.
pub const WaitForJobsFn = *const fn (user: ?*anyopaque) callconv(.c) void;

// ======================================
// Environment.

pub const RuntimeEnvironment = enum(c_int) {
    app = 0,
    preview_in_editor = 1,
};

// How much of the world is being simulated, as three levels of "pausedness".
// A host with no use for it passes None (Paused) and Full (Unpaused) only.
pub const TickLevel = enum(c_int) {
    none = 0,
    partial = 1,
    full = 2,
};

// ======================================
// Data type IDs shared with the editor.

// The low numbers are what Solmu uses to identify types.
pub const TYPE_INVALID: u32 = 0;
pub const TYPE_FLOAT: u32 = 1;
pub const TYPE_DOUBLE: u32 = 2;
pub const TYPE_INT8: u32 = 3;
pub const TYPE_UINT8: u32 = 4;
pub const TYPE_INT16: u32 = 5;
pub const TYPE_UINT16: u32 = 6;
pub const TYPE_INT32: u32 = 7;
pub const TYPE_UINT32: u32 = 8;
pub const TYPE_INT64: u32 = 9;
pub const TYPE_UINT64: u32 = 10;
pub const TYPE_BOOL: u32 = 11;
pub const TYPE_STRING: u32 = 12;
pub const TYPE_VEC2: u32 = 14;
pub const TYPE_VEC3: u32 = 15;
pub const TYPE_VEC4: u32 = 16;
pub const TYPE_ANY_VALUE: u32 = 31;
pub const TYPE_VECVARIANT: u32 = 32;
pub const TYPE_EXECUTION: u32 = 201;

// Timbre's block starts at 300 (= invalid) so the first real type is 301.
pub const TYPE_WAVE_ASSET: u32 = 301;
pub const TYPE_AUDIO_SOURCE: u32 = 302;
pub const TYPE_AUDIO_FILTER: u32 = 303;

// ======================================
// String hashing.

// MurmurHash3, x86 32 bit variant, seeded zero, over the bytes of the string
// without its trailing null. The x86 and x64 variants of MurmurHash3 disagree,
// so a host reimplementing this rather than calling it wants the x86 one.
pub const hashString = timbreHashString;

// ======================================
// Sound manager.

pub const SoundManager = opaque {};
pub const EventDescription = opaque {};
pub const EventInstance = opaque {};

// Flags for soundManagerCreate, combined bitwise.

// Timbre positions 3D audio in a left-handed coordinate system by default.
// This flag switches the sound manager to a right-handed one.
pub const SOUND_MANAGER_RIGHT_HANDED_3D: u32 = 0x1;

// Timbre opens no audio device and runs no thread of its own, and renders
// audio only when the host calls soundManagerMix(). For hosts that own
// their audio pipeline, eg. web games. Requires a real sample rate at creation.
pub const SOUND_MANAGER_HOST_MIXED: u32 = 0x2;

// The sample rate is the mixing rate in Hz. If you are creating the sound
// manager with the SOUND_MANAGER_HOST_MIXED flag you should pass a sample
// rate, otherwise leave it at 0 which makes the audio device decide.
pub const soundManagerCreate = timbreSoundManagerCreate;

pub const soundManagerDestroy = timbreSoundManagerDestroy;

// Loads a built project from a .timbre file. The bytes are copied, so the
// caller's buffer is not referenced afterwards. Returns nonzero on success.
pub const soundManagerLoadProject = timbreSoundManagerLoadProject;

// Loads an additive project, adding its data to the already loaded main
// project. The bytes are copied, as above. Refused, with nothing kept, when
// the data will not parse, when it is a main project rather than an additive
// one, or when a project with the same ID is already loaded. Returns nonzero
// on success.
//
// Writes the project's own ID, null-terminated, into outID. Needed because
// the additive project's soundbanks are named "[projectID]bankName".
pub const soundManagerLoadAdditiveProject = timbreSoundManagerLoadAdditiveProject;

// Looks an event up by its authored path, such as "event:/Music/MainMenu".
// Null when the project has no such event.
pub const soundManagerGetEventDescription = timbreSoundManagerGetEventDescription;

// Updates the sound mananger and advances every playing event instance.
pub const soundManagerUpdate = timbreSoundManagerUpdate;

// Renders the next frameCount frames as interleaved stereo float samples,
// so the buffer holds frameCount * 2 floats. Only for a sound manager
// created with SOUND_MANAGER_HOST_MIXED. Any other manager fills silence
// and reports an error once. Any frame count works, the chunking happens
// inside.
//
// In host mixed mode this call is also the clock. The update measures its
// delta time as the frames mixed since the previous update, so game time
// and audio time cannot drift.
pub const soundManagerMix = timbreSoundManagerMix;

// How much of the world is running. Pauses and resumes the instances that
// opted into following it, and leaves the rest playing. Full by default.
pub const soundManagerSetTickLevel = timbreSoundManagerSetTickLevel;

// Scales everything, on top of each event's own volume. This is the master
// bus, which is what a host means by a global volume. One by default.
pub const soundManagerSetGlobalVolume = timbreSoundManagerSetGlobalVolume;

pub const soundManagerGetGlobalVolume = timbreSoundManagerGetGlobalVolume;

// Where the listener is and which way it faces, in world units. Forward and
// up are the transform's Z and Y axes. Default: identity.
pub const soundManagerSetListenerTransform = timbreSoundManagerSetListenerTransform;

// Roughly how loud one output channel is right now, for a meter. Only
// meaningful on a sound manager created as RuntimeEnvironment.preview_in_editor,
// which is the only one that measures it, since it costs mixing work a game
// should not pay for. Zero otherwise.
pub const soundManagerGetApproximateVolume = timbreSoundManagerGetApproximateVolume;

// Used to hook wave decoding jobs into the job system of a game engine, or
// some other multithreading solution. Default: null, which means that the
// decoding is done on the main thread.
pub const soundManagerSetJobScheduler = timbreSoundManagerSetJobScheduler;

// ======================================
// Sound banks.

// The runtime never opens a file. It asks the host for a bank by name and
// gives the bytes back when the last thing using them is done, so audio can
// live in whatever the host already stores files in.

pub const SoundBankData = extern struct {
    bytes: ?*const anyopaque,
    length: u32,

    // Nonzero when the buffer will not outlive the call, so the runtime has
    // to take its own copy. Zero means the host holds it until the matching
    // release.
    copyData: c_int,
};

// Fills out and returns nonzero. Returning zero means there is no such bank.
pub const GetSoundBankDataFn = *const fn (name: [*:0]const u8, out: *SoundBankData, user: ?*anyopaque) callconv(.c) c_int;

// Called once per get, either when the runtime has finished with the bank or
// straight after it has copied one it was told not to keep.
pub const ReleaseSoundBankDataFn = *const fn (name: [*:0]const u8, data: *const SoundBankData, user: ?*anyopaque) callconv(.c) void;

pub const soundManagerSetSoundBankCallbacks = timbreSoundManagerSetSoundBankCallbacks;

// Fetches a bank now and keeps it, instead of leaving it to arrive when the
// first event that needs it plays. The bank stays resident until the project
// is replaced or the sound manager is destroyed. Returns nonzero on success,
// zero when the host has no such bank. Call after loading a project: loading
// one drops every bank it had.
pub const soundManagerPreloadSoundBank = timbreSoundManagerPreloadSoundBank;

// Only to be called from the Timbre editor.
pub const previewSetSoundBank = timbrePreviewSetSoundBank;

// Only to be called from the Timbre editor.
pub const previewClearSoundBanks = timbrePreviewClearSoundBanks;

// ======================================
// Bulk audio.

// Audio brought in wholesale by folder rather than authored one asset at a
// time, eg. dialogue lines.

// Fills whichever of the two outputs are given and returns nonzero. Zero
// means the project declares no such entry.

pub const soundManagerGetBulkAudioAsset = timbreSoundManagerGetBulkAudioAsset;

pub const soundManagerGetBulkAudioAssetByHash = timbreSoundManagerGetBulkAudioAssetByHash;

pub const BulkAudioAssetInfo = extern struct {
    // Borrowed from the loaded project, never null, and valid only until the
    // next project load or unload. Copy it if you intend to keep it.
    path: [*:0]const u8,

    pathHash: u32,
    assetID: u32,
    duration: f32,
};

// How many entries every loaded project declares between them, which is what to size a buffer by.
pub const soundManagerGetBulkAudioAssetCount = timbreSoundManagerGetBulkAudioAssetCount;

// Fills up to maxCount entries and returns how many were written.
pub const soundManagerGetBulkAudioAssets = timbreSoundManagerGetBulkAudioAssets;

// ======================================
// Debug statistics.

pub const WaveAssetLoadState = enum(c_int) {
    pending = 0,
    decoding = 1,
    ready = 2,
    failed = 3,
    _,
};

pub const DebugStats = extern struct {
    // Nonzero when a scheduler is installed, so decoding is done on a background thread.
    decodeInBackground: c_int,

    waveAssetRefCount: u32,
    loadedWaveAssetCount: u32,
    loadedDecodedBytes: u64,

    inFlightDecodeCount: u32,
    soundBankCount: u32,
    activeVoiceCount: u32,

    // Since startup, or since the last reset.
    decodesStarted: u64,
    decodesCompleted: u64,
    decodesFailed: u64,
    decodesCancelled: u64,
    peakInFlightDecodes: u32,
};

pub const soundManagerGetDebugStats = timbreSoundManagerGetDebugStats;

// Zeroes the running totals.
pub const soundManagerResetDebugStats = timbreSoundManagerResetDebugStats;

pub const DecodeRecord = extern struct {
    assetID: u32,

    // Ready or Failed, as a WaveAssetLoadState.
    outcome: u32,

    decodeSeconds: f32,
};

pub const InFlightDecode = extern struct {
    assetID: u32,
    state: u32,

    // How long since the decode was asked for, which is not the same as how
    // long it has been running, since the scheduler may not have started it
    // yet.
    elapsedSeconds: f32,
};

// Both fill up to maxCount entries and return how many were written.
pub const soundManagerGetRecentDecodes = timbreSoundManagerGetRecentDecodes;

pub const soundManagerGetInFlightDecodes = timbreSoundManagerGetInFlightDecodes;

// The listener as the mixer currently sees it.
pub const ListenerDebugInfo = extern struct {
    position: [3]f32,
    velocity: [3]f32,
    speed: f32,
};

pub const soundManagerGetListenerDebugInfo = timbreSoundManagerGetListenerDebugInfo;

// One 3D event instance's spatial debug view, computed with the same formula
// as the mixer. The radial speeds are the projections on the listener-to-source
// line. Both positive and equal means source and listener co-moving, which is
// a ratio of one. Timbre3DDebugInfo in C, renamed here since a Zig identifier
// cannot start with a digit.
pub const DebugInfo3D = extern struct {
    eventPath: [128]u8,

    // The instance's EventInstanceState. A stopped or paused instance still
    // gets a row, since it still holds 3D attributes, but no audible voice
    // is applying them.
    state: u32,

    distance: f32,

    // Listener speed along the line, positive when closing on the source.
    listenerRadialSpeed: f32,

    // Source speed along the line, positive when pulling away.
    sourceRadialSpeed: f32,

    sourceSpeed: f32,
    dopplerRatio: f32,
};

// Fills up to maxCount entries, one per registered 3D event instance, and
// returns how many were written.
pub const soundManagerGet3DDebugInfo = timbreSoundManagerGet3DDebugInfo;

// ======================================
// Group buses.

// The mixing points an event's voices play into.

pub const GroupBus = opaque {};

// Master bus, always present, and the default.
// Its volume is the same one soundManagerSetGlobalVolume sets.
pub const soundManagerGetMasterGroupBus = timbreSoundManagerGetMasterGroupBus;

// By authored path, such as "groupbus:/Buses/Music".
// Null when the project declares no such bus.
pub const soundManagerGetGroupBus = timbreSoundManagerGetGroupBus;

pub const groupBusGetVolume = timbreGroupBusGetVolume;

pub const groupBusSetVolume = timbreGroupBusSetVolume;

// ======================================
// Event descriptions.

pub const INVALID_PARAMETER_INDEX: u32 = 0xFFFFFFFF;

pub const eventDescriptionGetParameterIndex = timbreEventDescriptionGetParameterIndex;

pub const eventDescriptionGetParameterCount = timbreEventDescriptionGetParameterCount;

// One of the TYPE values, or invalid for a bad index.
pub const eventDescriptionGetParameterType = timbreEventDescriptionGetParameterType;

// Seconds, negative when the event's length was never determined.
pub const eventDescriptionGetLength = timbreEventDescriptionGetLength;

// Null when the graph could not be built, which is reported through the print hook.
pub const eventDescriptionCreateInstance = timbreEventDescriptionCreateInstance;

// ======================================
// Event instances.

pub const EventInstanceState = enum(c_int) {
    stopped = 0,
    playing = 1,
    paused = 2,

    // Reached an End node, or ran out of anything left to do.
    finished = 3,

    _,
};

pub const eventInstanceStart = timbreEventInstanceStart;
pub const eventInstanceStop = timbreEventInstanceStop;
pub const eventInstancePause = timbreEventInstancePause;
pub const eventInstanceUnpause = timbreEventInstanceUnpause;

// Hands the instance back to the sound manager, which destroys it. The
// handle is dead afterwards.
pub const eventInstanceRelease = timbreEventInstanceRelease;

// Hands it back on its own, the next update after it finishes. For a sound
// started and then forgotten about, where there is nobody left to release
// it. The handle is dead from that point.
pub const eventInstanceReleaseWhenFinished = timbreEventInstanceReleaseWhenFinished;

// Ramps the instance up from silence over the duration in seconds. Ignored
// while another fade is already running. Scales on top of the volume
// multiplier rather than replacing it, so a host can set both.
pub const eventInstanceFadeIn = timbreEventInstanceFadeIn;

// Ramps down to silence over the duration in seconds and then hands the
// instance back, as releaseWhenFinished does. Asking twice does not restart
// the fade. An instance that stops or finishes partway through is released
// there and then. The handle is dead once the fade completes.
pub const eventInstanceReleaseAfterFadeOut = timbreEventInstanceReleaseAfterFadeOut;

pub const eventInstanceGetState = timbreEventInstanceGetState;

// Seconds since the instance started, which is what an Event Time node
// reads and what a preview displays.
pub const eventInstanceGetTime = timbreEventInstanceGetTime;

// Float/int parameters are clamped to the range the parameter was authored with.
pub const eventInstanceSetParameterByIndex = timbreEventInstanceSetParameterByIndex;

pub const eventInstanceSetParameterByName = timbreEventInstanceSetParameterByName;

pub const eventInstanceGetParameterByIndex = timbreEventInstanceGetParameterByIndex;

pub const eventInstanceSendSignal = timbreEventInstanceSendSignal;

// Scales everything this instance plays, on top of the event's own volume
// and whatever its graph asks for. One by default.
pub const eventInstanceSetVolumeMultiplier = timbreEventInstanceSetVolumeMultiplier;

pub const eventInstanceGetVolumeMultiplier = timbreEventInstanceGetVolumeMultiplier;

// Pauses this instance whenever the tick level drops to the given one or
// below, and resumes it when the level rises again. Off by default, which
// means that the event keeps playing regardless of tick level.
pub const eventInstanceSetAutoPause = timbreEventInstanceSetAutoPause;

// Where the event is and how fast it is moving, in world units and units
// per second. Ignored by an event that was not authored as 3D.
pub const eventInstanceSet3DAttributes = timbreEventInstanceSet3DAttributes;

// ======================================
// The C symbols behind the public interface.

extern fn timbreVersion() u32;

extern fn timbreSetAllocator(allocFn: ?AllocFn, freeFn: ?FreeFn, user: ?*anyopaque) void;

extern fn timbreSetPrint(printFn: ?PrintFn, user: ?*anyopaque) void;

extern fn timbreSetAssertHandler(handler: ?AssertFn, user: ?*anyopaque) void;

extern fn timbreHashString(str: [*:0]const u8) u32;

extern fn timbreSoundManagerCreate(environment: RuntimeEnvironment, flags: u32, sampleRate: u32) ?*SoundManager;

extern fn timbreSoundManagerDestroy(soundManager: *SoundManager) void;

extern fn timbreSoundManagerLoadProject(soundManager: *SoundManager, bytes: ?*const anyopaque, size: usize) c_int;

extern fn timbreSoundManagerLoadAdditiveProject(soundManager: *SoundManager, bytes: ?*const anyopaque, size: usize, outID: ?[*]u8, outIDSize: u32) c_int;

extern fn timbreSoundManagerGetEventDescription(soundManager: *SoundManager, path: [*:0]const u8) ?*EventDescription;

extern fn timbreSoundManagerUpdate(soundManager: *SoundManager) void;

extern fn timbreSoundManagerMix(soundManager: *SoundManager, interleavedStereo: [*]f32, frameCount: u32) void;

extern fn timbreSoundManagerSetTickLevel(soundManager: *SoundManager, tickLevel: TickLevel) void;

extern fn timbreSoundManagerSetGlobalVolume(soundManager: *SoundManager, volume: f32) void;

extern fn timbreSoundManagerGetGlobalVolume(soundManager: *SoundManager) f32;

extern fn timbreSoundManagerSetListenerTransform(soundManager: *SoundManager, positionX: f32, positionY: f32, positionZ: f32, forwardX: f32, forwardY: f32, forwardZ: f32, upX: f32, upY: f32, upZ: f32) void;

extern fn timbreSoundManagerGetApproximateVolume(soundManager: *SoundManager, channel: u32) f32;

extern fn timbreSoundManagerSetJobScheduler(soundManager: *SoundManager, scheduleFn: ?ScheduleJobFn, waitFn: ?WaitForJobsFn, user: ?*anyopaque) void;

extern fn timbreSoundManagerSetSoundBankCallbacks(soundManager: *SoundManager, getFn: ?GetSoundBankDataFn, releaseFn: ?ReleaseSoundBankDataFn, user: ?*anyopaque) void;

extern fn timbreSoundManagerPreloadSoundBank(soundManager: *SoundManager, name: [*:0]const u8) c_int;

extern fn timbrePreviewSetSoundBank(soundManager: *SoundManager, name: [*:0]const u8, bytes: ?*const anyopaque, size: usize) c_int;

extern fn timbrePreviewClearSoundBanks(soundManager: *SoundManager) void;

extern fn timbreSoundManagerGetBulkAudioAsset(soundManager: *SoundManager, path: [*:0]const u8, outDuration: ?*f32, outAssetID: ?*u32) c_int;

extern fn timbreSoundManagerGetBulkAudioAssetByHash(soundManager: *SoundManager, pathHash: u32, outDuration: ?*f32, outAssetID: ?*u32) c_int;

extern fn timbreSoundManagerGetBulkAudioAssetCount(soundManager: *SoundManager) u32;

extern fn timbreSoundManagerGetBulkAudioAssets(soundManager: *SoundManager, out: [*]BulkAudioAssetInfo, maxCount: u32) u32;

extern fn timbreSoundManagerGetDebugStats(soundManager: *SoundManager, out: *DebugStats) void;

extern fn timbreSoundManagerResetDebugStats(soundManager: *SoundManager) void;

extern fn timbreSoundManagerGetRecentDecodes(soundManager: *SoundManager, out: [*]DecodeRecord, maxCount: u32) u32;

extern fn timbreSoundManagerGetInFlightDecodes(soundManager: *SoundManager, out: [*]InFlightDecode, maxCount: u32) u32;

extern fn timbreSoundManagerGetListenerDebugInfo(soundManager: *SoundManager, out: *ListenerDebugInfo) void;

extern fn timbreSoundManagerGet3DDebugInfo(soundManager: *SoundManager, out: [*]DebugInfo3D, maxCount: u32) u32;

extern fn timbreSoundManagerGetMasterGroupBus(soundManager: *SoundManager) *GroupBus;

extern fn timbreSoundManagerGetGroupBus(soundManager: *SoundManager, path: [*:0]const u8) ?*GroupBus;

extern fn timbreGroupBusGetVolume(groupBus: *const GroupBus) f32;

extern fn timbreGroupBusSetVolume(groupBus: *GroupBus, volume: f32) void;

extern fn timbreEventDescriptionGetParameterIndex(description: *const EventDescription, name: [*:0]const u8) u32;

extern fn timbreEventDescriptionGetParameterCount(description: *const EventDescription) u32;

extern fn timbreEventDescriptionGetParameterType(description: *const EventDescription, index: u32) u32;

extern fn timbreEventDescriptionGetLength(description: *const EventDescription) f32;

extern fn timbreEventDescriptionCreateInstance(description: *EventDescription) ?*EventInstance;

extern fn timbreEventInstanceStart(instance: *EventInstance) void;

extern fn timbreEventInstanceStop(instance: *EventInstance) void;

extern fn timbreEventInstancePause(instance: *EventInstance) void;

extern fn timbreEventInstanceUnpause(instance: *EventInstance) void;

extern fn timbreEventInstanceRelease(instance: *EventInstance) void;

extern fn timbreEventInstanceReleaseWhenFinished(instance: *EventInstance) void;

extern fn timbreEventInstanceFadeIn(instance: *EventInstance, duration: f32) void;

extern fn timbreEventInstanceReleaseAfterFadeOut(instance: *EventInstance, duration: f32) void;

extern fn timbreEventInstanceGetState(instance: *const EventInstance) EventInstanceState;

extern fn timbreEventInstanceGetTime(instance: *const EventInstance) f32;

extern fn timbreEventInstanceSetParameterByIndex(instance: *EventInstance, index: u32, value: f32) void;

extern fn timbreEventInstanceSetParameterByName(instance: *EventInstance, name: [*:0]const u8, value: f32) void;

extern fn timbreEventInstanceGetParameterByIndex(instance: *const EventInstance, index: u32) f32;

extern fn timbreEventInstanceSendSignal(instance: *EventInstance, signal: [*:0]const u8) void;

extern fn timbreEventInstanceSetVolumeMultiplier(instance: *EventInstance, volume: f32) void;

extern fn timbreEventInstanceGetVolumeMultiplier(instance: *const EventInstance) f32;

extern fn timbreEventInstanceSetAutoPause(instance: *EventInstance, enabled: c_int, level: TickLevel) void;

extern fn timbreEventInstanceSet3DAttributes(instance: *EventInstance, positionX: f32, positionY: f32, positionZ: f32, velocityX: f32, velocityY: f32, velocityZ: f32) void;
