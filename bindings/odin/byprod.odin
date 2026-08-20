// ======================================
// byProd - audio runtime
// Copyright 2026 Madrigal Ltd.
// Bindings released under the MIT license, see LICENSE in the repository root.
// ======================================

// Odin bindings over the byProd C API. These bindings are not the official
// authoritative API. That is byprod.h in the byProd SDK.

// The foreign imports expect the SDK libraries beside this file:
// byProd.lib on Windows, libbyProd.so on Linux, and for the web
// byProd-wasm32-wasi.a renamed to byProd-wasm32-wasi.o, since Odin's
// wasm target only hands .o files to its linker while wasm-ld
// identifies inputs by content.

// Threading: The public API of byProd is supposed to be called from only
// one thread at a time. The library uses threads internally for mixing,
// and can be hooked into a host-provided job system for async wave data
// decoding. See SoundManagerSetJobScheduler() for more information. A
// sound manager created with SOUND_MANAGER_HOST_MIXED runs no internal
// threads at all. The host pulls the mixed audio with SoundManagerMix().

package byprod

when ODIN_OS == .Windows {
	foreign import lib {
		"byProd.lib"
	}
} else when ODIN_OS == .Linux {
	foreign import lib {
		"libbyProd.so"
	}
} else when ODIN_OS == .JS {
	foreign import lib {
		"byProd-wasm32-wasi.o"
	}
}

// ======================================
// Library version.

VERSION_MAJOR :: 0
VERSION_MINOR :: 5
VERSION_PATCH :: 0

VERSION: u32 : (VERSION_MAJOR << 16) | (VERSION_MINOR << 8) | VERSION_PATCH

@(default_calling_convention="c", link_prefix="bpd")
foreign lib {
	// Returns the version the library was built as. Compare against VERSION
	// from the bindings you compiled against before using anything else.
	Version :: proc() -> u32 ---
}

// ======================================
// Host hooks.

AllocFn :: proc "c" (size: uint, user: rawptr) -> rawptr
FreeFn  :: proc "c" (ptr: rawptr, user: rawptr)

PrintType :: enum i32 {
	INFO    = 0,
	WARNING = 1,
	ERROR   = 2,
}

PrintFn :: proc "c" (message: cstring, type: PrintType, user: rawptr)

AssertFn :: proc "c" (message: cstring, file: cstring, line: i32, user: rawptr)

// The work a scheduler is asked to run.
JobFn :: proc "c" (jobData: rawptr)

// A function which schedules a job to be run. Eg. can be used to hook into
// the job system of a game engine.
ScheduleJobFn :: proc "c" (jobFn: JobFn, jobData: rawptr, user: rawptr)

// A function which waits until every scheduled job has run.
WaitForJobsFn :: proc "c" (user: rawptr)

@(default_calling_convention="c", link_prefix="bpd")
foreign lib {
	// Replaces the allocator, which has to happen before anything else is
	// called. The callbacks must be thread safe since the audio mixer thread
	// allocates through them too.
	SetAllocator :: proc(allocFn: AllocFn, freeFn: FreeFn, user: rawptr) ---

	SetPrint :: proc(printFn: PrintFn, user: rawptr) ---

	// Replaces what runs when a runtime assertion fails. Without a handler
	// the message goes to the print hook and the process aborts. A handler
	// that returns instead of aborting makes the runtime continue past the
	// failure (usually with an early-out or another way to handle the error).
	SetAssertHandler :: proc(handler: AssertFn, user: rawptr) ---
}

// ======================================
// Environment.

RuntimeEnvironment :: enum i32 {
	APP               = 0,
	PREVIEW_IN_EDITOR = 1,
}

// How much of the world is being simulated, as three levels of "pausedness".
// A host with no use for it passes None (Paused) and Full (Unpaused) only.
TickLevel :: enum i32 {
	NONE    = 0,
	PARTIAL = 1,
	FULL    = 2,
}

// ======================================
// Data type IDs shared with the editor.

// The low numbers are what Solmu uses to identify types.
TYPE_INVALID    :: 0
TYPE_FLOAT      :: 1
TYPE_DOUBLE     :: 2
TYPE_INT8       :: 3
TYPE_UINT8      :: 4
TYPE_INT16      :: 5
TYPE_UINT16     :: 6
TYPE_INT32      :: 7
TYPE_UINT32     :: 8
TYPE_INT64      :: 9
TYPE_UINT64     :: 10
TYPE_BOOL       :: 11
TYPE_STRING     :: 12
TYPE_VEC2       :: 14
TYPE_VEC3       :: 15
TYPE_VEC4       :: 16
TYPE_ANY_VALUE  :: 31
TYPE_VECVARIANT :: 32
TYPE_EXECUTION  :: 201

// byProd's block starts at 300 (= invalid) so the first real type is 301.
TYPE_WAVE_ASSET   :: 301
TYPE_AUDIO_SOURCE :: 302
TYPE_AUDIO_FILTER :: 303

// ======================================
// String hashing.

@(default_calling_convention="c", link_prefix="bpd")
foreign lib {
	// MurmurHash3, x86 32 bit variant, seeded zero, over the bytes of the
	// string without its trailing null. The x86 and x64 variants of
	// MurmurHash3 disagree, so a host reimplementing this rather than
	// calling it wants the x86 one.
	HashString :: proc(str: cstring) -> u32 ---
}

// ======================================
// Sound manager.

SoundManager     :: struct {}
EventDescription :: struct {}
EventInstance    :: struct {}

// Flags for SoundManagerCreate, combined bitwise.

// byProd positions 3D audio in a left-handed coordinate system by default.
// This flag switches the sound manager to a right-handed one.
SOUND_MANAGER_RIGHT_HANDED_3D :: 0x1

// byProd opens no audio device and runs no thread of its own, and renders
// audio only when the host calls SoundManagerMix(). For hosts that own
// their audio pipeline, eg. web games. Requires a real sample rate at
// creation.
SOUND_MANAGER_HOST_MIXED :: 0x2

@(default_calling_convention="c", link_prefix="bpd")
foreign lib {
	// The sample rate is the mixing rate in Hz. If you are creating the
	// sound manager with the SOUND_MANAGER_HOST_MIXED flag you should pass a
	// sample rate, otherwise leave it at 0 which makes the audio device
	// decide.
	SoundManagerCreate :: proc(environment: RuntimeEnvironment, flags: u32, sampleRate: u32) -> ^SoundManager ---

	SoundManagerDestroy :: proc(soundManager: ^SoundManager) ---

	// Loads a built project from a .byprod file. The bytes are copied, so
	// the caller's buffer is not referenced afterwards. Returns nonzero on
	// success.
	SoundManagerLoadProject :: proc(soundManager: ^SoundManager, bytes: rawptr, size: uint) -> b32 ---

	// Loads an additive project, adding its data to the already loaded main
	// project. The bytes are copied, as above. Refused, with nothing kept,
	// when the data will not parse, when it is a main project rather than an
	// additive one, or when a project with the same ID is already loaded.
	// Returns nonzero on success.
	//
	// Writes the project's own ID, null-terminated, into outID. Needed
	// because the additive project's soundbanks are named
	// "[projectID]bankName".
	SoundManagerLoadAdditiveProject :: proc(soundManager: ^SoundManager, bytes: rawptr, size: uint, outID: [^]u8, outIDSize: u32) -> b32 ---

	// Looks an event up by its authored path, such as "event:/Music/MainMenu".
	// Null when the project has no such event.
	SoundManagerGetEventDescription :: proc(soundManager: ^SoundManager, path: cstring) -> ^EventDescription ---

	// Updates the sound mananger and advances every playing event instance.
	SoundManagerUpdate :: proc(soundManager: ^SoundManager) ---

	// Renders the next frameCount frames as interleaved stereo float
	// samples, so the buffer holds frameCount * 2 floats. Only for a sound
	// manager created with SOUND_MANAGER_HOST_MIXED. Any other manager fills
	// silence and reports an error once. Any frame count works, the chunking
	// happens inside.
	//
	// In host mixed mode this call is also the clock. Mixed frames are
	// elapsed time: mixing one second of audio advances events by one
	// second, applied at the next SoundManagerUpdate(). So mix only what
	// your audio output actually plays, and event time stays in step with
	// what you hear.
	SoundManagerMix :: proc(soundManager: ^SoundManager, interleavedStereo: [^]f32, frameCount: u32) ---

	// How much of the world is running. Pauses and resumes the instances
	// that opted into following it, and leaves the rest playing. Full by
	// default.
	SoundManagerSetTickLevel :: proc(soundManager: ^SoundManager, tickLevel: TickLevel) ---

	// Scales everything, on top of each event's own volume. This is the
	// master bus, which is what a host means by a global volume. One by
	// default.
	SoundManagerSetGlobalVolume :: proc(soundManager: ^SoundManager, volume: f32) ---
	SoundManagerGetGlobalVolume :: proc(soundManager: ^SoundManager) -> f32 ---

	// Where the listener is and which way it faces, in world units. Forward
	// and up are the transform's Z and Y axes. Default: identity.
	SoundManagerSetListenerTransform :: proc(soundManager: ^SoundManager, positionX: f32, positionY: f32, positionZ: f32, forwardX: f32, forwardY: f32, forwardZ: f32, upX: f32, upY: f32, upZ: f32) ---

	// Roughly how loud one output channel is right now, for a meter. Only
	// meaningful on a sound manager created as
	// RuntimeEnvironment.PREVIEW_IN_EDITOR, which is the only one that
	// measures it, since it costs mixing work a game should not pay for.
	// Zero otherwise.
	SoundManagerGetApproximateVolume :: proc(soundManager: ^SoundManager, channel: u32) -> f32 ---

	// Used to hook wave decoding jobs into the job system of a game engine,
	// or some other multithreading solution. Default: null, which means that
	// the decoding is done on the main thread.
	SoundManagerSetJobScheduler :: proc(soundManager: ^SoundManager, scheduleFn: ScheduleJobFn, waitFn: WaitForJobsFn, user: rawptr) ---
}

// ======================================
// Sound banks.

// The runtime never opens a file. It asks the host for a bank by name and
// gives the bytes back when the last thing using them is done, so audio can
// live in whatever the host already stores files in.

SoundBankData :: struct {
	bytes:  rawptr,
	length: u32,

	// Nonzero when the buffer will not outlive the call, so the runtime has
	// to take its own copy. Zero means the host holds it until the matching
	// release.
	copyData: b32,
}

// Fills out and returns nonzero. Returning zero means there is no such bank.
GetSoundBankDataFn :: proc "c" (name: cstring, out: ^SoundBankData, user: rawptr) -> b32

// Called once per get, either when the runtime has finished with the bank or
// straight after it has copied one it was told not to keep.
ReleaseSoundBankDataFn :: proc "c" (name: cstring, data: ^SoundBankData, user: rawptr)

@(default_calling_convention="c", link_prefix="bpd")
foreign lib {
	SoundManagerSetSoundBankCallbacks :: proc(soundManager: ^SoundManager, getFn: GetSoundBankDataFn, releaseFn: ReleaseSoundBankDataFn, user: rawptr) ---

	// Fetches a bank now and keeps it, instead of leaving it to arrive when
	// the first event that needs it plays. The bank stays resident until the
	// project is replaced or the sound manager is destroyed. Returns nonzero
	// on success, zero when the host has no such bank. Call after loading a
	// project: loading one drops every bank it had.
	SoundManagerPreloadSoundBank :: proc(soundManager: ^SoundManager, name: cstring) -> b32 ---
}

// ======================================
// Bulk audio.

// Audio brought in wholesale by folder rather than authored one asset at a
// time, eg. dialogue lines.

BulkAudioAssetInfo :: struct {
	// Borrowed from the loaded project, never null, and valid only until the
	// next project load or unload. Copy it if you intend to keep it.
	path: cstring,

	pathHash: u32,
	assetID:  u32,
	duration: f32,
}

@(default_calling_convention="c", link_prefix="bpd")
foreign lib {
	// Fills whichever of the two outputs are given and returns nonzero. Zero
	// means the project declares no such entry.
	SoundManagerGetBulkAudioAsset       :: proc(soundManager: ^SoundManager, path: cstring, outDuration: ^f32, outAssetID: ^u32) -> b32 ---
	SoundManagerGetBulkAudioAssetByHash :: proc(soundManager: ^SoundManager, pathHash: u32, outDuration: ^f32, outAssetID: ^u32) -> b32 ---

	// How many entries every loaded project declares between them, which is
	// what to size a buffer by.
	SoundManagerGetBulkAudioAssetCount :: proc(soundManager: ^SoundManager) -> u32 ---

	// Fills up to maxCount entries and returns how many were written.
	SoundManagerGetBulkAudioAssets :: proc(soundManager: ^SoundManager, out: [^]BulkAudioAssetInfo, maxCount: u32) -> u32 ---
}

// ======================================
// Debug statistics.

WaveAssetLoadState :: enum i32 {
	PENDING  = 0,
	DECODING = 1,
	READY    = 2,
	FAILED   = 3,
}

DebugStats :: struct {
	// Nonzero when a scheduler is installed, so decoding is done on a
	// background thread.
	decodeInBackground: b32,

	waveAssetRefCount:    u32,
	loadedWaveAssetCount: u32,
	loadedDecodedBytes:   u64,

	inFlightDecodeCount: u32,
	soundBankCount:      u32,
	activeVoiceCount:    u32,

	// Since startup, or since the last reset.
	decodesStarted:      u64,
	decodesCompleted:    u64,
	decodesFailed:       u64,
	decodesCancelled:    u64,
	peakInFlightDecodes: u32,
}

DecodeRecord :: struct {
	assetID: u32,

	// Ready or Failed, as a WaveAssetLoadState.
	outcome: WaveAssetLoadState,

	decodeSeconds: f32,
}

InFlightDecode :: struct {
	assetID: u32,
	state:   WaveAssetLoadState,

	// How long since the decode was asked for, which is not the same as how
	// long it has been running, since the scheduler may not have started it
	// yet.
	elapsedSeconds: f32,
}

// The listener as the mixer currently sees it.
ListenerDebugInfo :: struct {
	position: [3]f32,
	velocity: [3]f32,
	speed:    f32,
}

// One 3D event instance's spatial debug view, computed with the same formula
// as the mixer. The radial speeds are the projections on the
// listener-to-source line. Both positive and equal means source and listener
// co-moving, which is a ratio of one.
DebugInfo3D :: struct {
	eventPath: [128]u8,

	// The instance's EventInstanceState. A stopped or paused instance still
	// gets a row, since it still holds 3D attributes, but no audible voice
	// is applying them.
	state: EventInstanceState,

	distance: f32,

	// Listener speed along the line, positive when closing on the source.
	listenerRadialSpeed: f32,

	// Source speed along the line, positive when pulling away.
	sourceRadialSpeed: f32,

	sourceSpeed:  f32,
	dopplerRatio: f32,
}

@(default_calling_convention="c", link_prefix="bpd")
foreign lib {
	SoundManagerGetDebugStats :: proc(soundManager: ^SoundManager, out: ^DebugStats) ---

	// Zeroes the running totals.
	SoundManagerResetDebugStats :: proc(soundManager: ^SoundManager) ---

	// Both fill up to maxCount entries and return how many were written.
	SoundManagerGetRecentDecodes   :: proc(soundManager: ^SoundManager, out: [^]DecodeRecord, maxCount: u32) -> u32 ---
	SoundManagerGetInFlightDecodes :: proc(soundManager: ^SoundManager, out: [^]InFlightDecode, maxCount: u32) -> u32 ---

	SoundManagerGetListenerDebugInfo :: proc(soundManager: ^SoundManager, out: ^ListenerDebugInfo) ---

	// Fills up to maxCount entries, one per registered 3D event instance,
	// and returns how many were written.
	SoundManagerGet3DDebugInfo :: proc(soundManager: ^SoundManager, out: [^]DebugInfo3D, maxCount: u32) -> u32 ---
}

// ======================================
// Group buses.

// The mixing points an event's voices play into.

GroupBus :: struct {}

@(default_calling_convention="c", link_prefix="bpd")
foreign lib {
	// Master bus, always present, and the default.
	// Its volume is the same one SoundManagerSetGlobalVolume sets.
	SoundManagerGetMasterGroupBus :: proc(soundManager: ^SoundManager) -> ^GroupBus ---

	// By authored path, such as "groupbus:/Buses/Music".
	// Null when the project declares no such bus.
	SoundManagerGetGroupBus :: proc(soundManager: ^SoundManager, path: cstring) -> ^GroupBus ---

	GroupBusGetVolume :: proc(groupBus: ^GroupBus) -> f32 ---
	GroupBusSetVolume :: proc(groupBus: ^GroupBus, volume: f32) ---
}

// ======================================
// Event descriptions.

INVALID_PARAMETER_INDEX :: 0xFFFFFFFF

@(default_calling_convention="c", link_prefix="bpd")
foreign lib {
	EventDescriptionGetParameterIndex :: proc(description: ^EventDescription, name: cstring) -> u32 ---
	EventDescriptionGetParameterCount :: proc(description: ^EventDescription) -> u32 ---

	// One of the TYPE_* values, or invalid for a bad index.
	EventDescriptionGetParameterType :: proc(description: ^EventDescription, index: u32) -> u32 ---

	// Seconds, negative when the event's length was never determined.
	EventDescriptionGetLength :: proc(description: ^EventDescription) -> f32 ---

	// Null when the graph could not be built, which is reported through the
	// print hook.
	EventDescriptionCreateInstance :: proc(description: ^EventDescription) -> ^EventInstance ---
}

// ======================================
// Event instances.

EventInstanceState :: enum i32 {
	STOPPED = 0,
	PLAYING = 1,
	PAUSED  = 2,

	// Reached an End node, or ran out of anything left to do.
	FINISHED = 3,
}

@(default_calling_convention="c", link_prefix="bpd")
foreign lib {
	EventInstanceStart   :: proc(instance: ^EventInstance) ---
	EventInstanceStop    :: proc(instance: ^EventInstance) ---
	EventInstancePause   :: proc(instance: ^EventInstance) ---
	EventInstanceUnpause :: proc(instance: ^EventInstance) ---

	// Hands the instance back to the sound manager, which destroys it. The
	// handle is dead afterwards.
	EventInstanceRelease :: proc(instance: ^EventInstance) ---

	// Hands it back on its own, the next update after it finishes. For a
	// sound started and then forgotten about, where there is nobody left to
	// release it. The handle is dead from that point.
	EventInstanceReleaseWhenFinished :: proc(instance: ^EventInstance) ---

	// Ramps the instance up from silence over the duration in seconds.
	// Ignored while another fade is already running. Scales on top of the
	// volume multiplier rather than replacing it, so a host can set both.
	EventInstanceFadeIn :: proc(instance: ^EventInstance, duration: f32) ---

	// Ramps down to silence over the duration in seconds and then hands the
	// instance back, as ReleaseWhenFinished does. Asking twice does not
	// restart the fade. An instance that stops or finishes partway through
	// is released there and then. The handle is dead once the fade
	// completes.
	EventInstanceReleaseAfterFadeOut :: proc(instance: ^EventInstance, duration: f32) ---

	EventInstanceGetState :: proc(instance: ^EventInstance) -> EventInstanceState ---

	// Seconds since the instance started, which is what an Event Time node
	// reads and what a preview displays.
	EventInstanceGetTime :: proc(instance: ^EventInstance) -> f32 ---

	// Float/int parameters are clamped to the range the parameter was
	// authored with.
	EventInstanceSetParameterByIndex :: proc(instance: ^EventInstance, index: u32, value: f32) ---
	EventInstanceSetParameterByName  :: proc(instance: ^EventInstance, name: cstring, value: f32) ---
	EventInstanceGetParameterByIndex :: proc(instance: ^EventInstance, index: u32) -> f32 ---

	EventInstanceSendSignal :: proc(instance: ^EventInstance, signal: cstring) ---

	// Scales everything this instance plays, on top of the event's own
	// volume and whatever its graph asks for. One by default.
	EventInstanceSetVolumeMultiplier :: proc(instance: ^EventInstance, volume: f32) ---
	EventInstanceGetVolumeMultiplier :: proc(instance: ^EventInstance) -> f32 ---

	// Pauses this instance whenever the tick level drops to the given one or
	// below, and resumes it when the level rises again. Off by default,
	// which means that the event keeps playing regardless of tick level.
	EventInstanceSetAutoPause :: proc(instance: ^EventInstance, enabled: b32, level: TickLevel) ---

	// Where the event is and how fast it is moving, in world units and units
	// per second. Ignored by an event that was not authored as 3D.
	EventInstanceSet3DAttributes :: proc(instance: ^EventInstance, positionX: f32, positionY: f32, positionZ: f32, velocityX: f32, velocityY: f32, velocityZ: f32) ---
}
