//! Raw bindings to the byProd 0.5.5 interactive audio runtime.
//!
//! Compare `bpdVersion()` with [VERSION] before using the API. Serialize public
//! runtime calls. Keep handles, callback data and borrowed buffers valid for
//! their SDK-defined lifetimes. Rust callbacks must not unwind across the ABI.

#![no_std]

use core::ffi::{c_char, c_int, c_void};

pub const VERSION_MAJOR: u32 = 0;
pub const VERSION_MINOR: u32 = 5;
pub const VERSION_PATCH: u32 = 5;
pub const fn make_version(major: u32, minor: u32, patch: u32) -> u32 {
    (major << 16) | (minor << 8) | patch
}
pub const VERSION: u32 = make_version(VERSION_MAJOR, VERSION_MINOR, VERSION_PATCH);

pub type AllocFn = unsafe extern "C" fn(size: usize, user: *mut c_void) -> *mut c_void;

pub type FreeFn = unsafe extern "C" fn(ptr: *mut c_void, user: *mut c_void);

#[repr(transparent)]
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct PrintType(pub c_int);
impl PrintType {
    pub const INFO: Self = Self(0);
    pub const WARNING: Self = Self(1);
    pub const ERROR: Self = Self(2);
}

pub type PrintFn =
    unsafe extern "C" fn(message: *const c_char, print_type: PrintType, user: *mut c_void);

pub type AssertFn = unsafe extern "C" fn(
    message: *const c_char,
    file: *const c_char,
    line: c_int,
    user: *mut c_void,
);

pub type JobFn = unsafe extern "C" fn(job_data: *mut c_void);

pub type ScheduleJobFn =
    unsafe extern "C" fn(job_fn: JobFn, job_data: *mut c_void, user: *mut c_void);

pub type WaitForJobsFn = unsafe extern "C" fn(user: *mut c_void);

#[repr(transparent)]
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct RuntimeEnvironment(pub c_int);
impl RuntimeEnvironment {
    pub const APP: Self = Self(0);
    pub const PREVIEW_IN_EDITOR: Self = Self(1);
}

#[repr(transparent)]
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct TickLevel(pub c_int);
impl TickLevel {
    pub const NONE: Self = Self(0);
    pub const PARTIAL: Self = Self(1);
    pub const FULL: Self = Self(2);
}

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
pub const TYPE_WAVE_ASSET: u32 = 301;
pub const TYPE_AUDIO_SOURCE: u32 = 302;
pub const TYPE_AUDIO_FILTER: u32 = 303;
#[repr(C)]
pub struct SoundManager {
    _private: [u8; 0],
}

#[repr(C)]
pub struct EventDescription {
    _private: [u8; 0],
}

#[repr(C)]
pub struct EventInstance {
    _private: [u8; 0],
}

pub const SOUND_MANAGER_RIGHT_HANDED_3D: u32 = 0x1;
pub const SOUND_MANAGER_HOST_MIXED: u32 = 0x2;
#[repr(C)]
pub struct SoundManagerSettings {
    pub environment: RuntimeEnvironment,
    pub flags: u32,
    pub sample_rate: u32,
    pub global_volume_multiplier: f32,
    pub post_clip_scaler: f32,
    pub max_active_voice_count: u32,
}

#[repr(C)]
pub struct SoundBankData {
    pub bytes: *const c_void,
    pub length: u32,
    pub copy_data: c_int,
}

pub type GetSoundBankDataFn =
    unsafe extern "C" fn(name: *const c_char, out: *mut SoundBankData, user: *mut c_void) -> c_int;

pub type ReleaseSoundBankDataFn =
    unsafe extern "C" fn(name: *const c_char, data: *const SoundBankData, user: *mut c_void);

#[repr(C)]
pub struct BulkAudioAssetInfo {
    pub path: *const c_char,
    pub path_hash: u32,
    pub asset_id: u32,
    pub duration: f32,
}

#[repr(transparent)]
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct WaveAssetLoadState(pub c_int);
impl WaveAssetLoadState {
    pub const PENDING: Self = Self(0);
    pub const DECODING: Self = Self(1);
    pub const READY: Self = Self(2);
    pub const FAILED: Self = Self(3);
}

#[repr(C)]
pub struct DebugStats {
    pub decode_in_background: c_int,
    pub wave_asset_ref_count: u32,
    pub loaded_wave_asset_count: u32,
    pub loaded_decoded_bytes: u64,
    pub in_flight_decode_count: u32,
    pub sound_bank_count: u32,
    pub active_voice_count: u32,
    pub decodes_started: u64,
    pub decodes_completed: u64,
    pub decodes_failed: u64,
    pub decodes_cancelled: u64,
    pub peak_in_flight_decodes: u32,
}

#[repr(C)]
pub struct DecodeRecord {
    pub asset_id: u32,
    pub outcome: u32,
    pub decode_seconds: f32,
}

#[repr(C)]
pub struct InFlightDecode {
    pub asset_id: u32,
    pub state: u32,
    pub elapsed_seconds: f32,
}

#[repr(C)]
pub struct ListenerDebugInfo {
    pub position: [f32; 3],
    pub velocity: [f32; 3],
    pub speed: f32,
}

#[repr(C)]
pub struct DebugInfo3D {
    pub event_path: [u8; 128],
    pub state: u32,
    pub distance: f32,
    pub listener_radial_speed: f32,
    pub source_radial_speed: f32,
    pub source_speed: f32,
    pub doppler_ratio: f32,
}

#[repr(C)]
pub struct GroupBus {
    _private: [u8; 0],
}

pub const INVALID_PARAMETER_INDEX: u32 = 0xFFFFFFFF;
#[repr(transparent)]
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct EventInstanceState(pub c_int);
impl EventInstanceState {
    pub const STOPPED: Self = Self(0);
    pub const PLAYING: Self = Self(1);
    pub const PAUSED: Self = Self(2);
    pub const FINISHED: Self = Self(3);
}

#[cfg_attr(windows, link(name = "byProd", kind = "raw-dylib"))]
#[cfg_attr(
    target_arch = "wasm32",
    link(
        name = "byProd-wasm32-wasi.a",
        kind = "static",
        modifiers = "+verbatim"
    )
)]
#[cfg_attr(not(any(windows, target_arch = "wasm32")), link(name = "byProd"))]
unsafe extern "C" {
    pub fn bpdVersion() -> u32;
    pub fn bpdSetAllocator(alloc_fn: Option<AllocFn>, free_fn: Option<FreeFn>, user: *mut c_void);
    pub fn bpdSetPrint(print_fn: Option<PrintFn>, user: *mut c_void);
    pub fn bpdSetAssertHandler(handler: Option<AssertFn>, user: *mut c_void);
    pub fn bpdHashString(str: *const c_char) -> u32;
    pub fn bpdSoundManagerSettingsInit(settings: *mut SoundManagerSettings);
    pub fn bpdSoundManagerCreate(settings: *const SoundManagerSettings) -> *mut SoundManager;
    pub fn bpdSoundManagerDestroy(sound_manager: *mut SoundManager);
    pub fn bpdSoundManagerLoadProject(
        sound_manager: *mut SoundManager,
        bytes: *const c_void,
        size: usize,
    ) -> c_int;
    pub fn bpdSoundManagerLoadAdditiveProject(
        sound_manager: *mut SoundManager,
        bytes: *const c_void,
        size: usize,
        out_id: *mut c_char,
        out_id_size: u32,
    ) -> c_int;
    pub fn bpdSoundManagerGetEventDescription(
        sound_manager: *mut SoundManager,
        path: *const c_char,
    ) -> *mut EventDescription;
    pub fn bpdSoundManagerUpdate(sound_manager: *mut SoundManager);
    pub fn bpdSoundManagerMix(
        sound_manager: *mut SoundManager,
        interleaved_stereo: *mut f32,
        frame_count: u32,
    );
    pub fn bpdSoundManagerSetTickLevel(sound_manager: *mut SoundManager, tick_level: TickLevel);
    pub fn bpdSoundManagerSetGlobalVolume(sound_manager: *mut SoundManager, volume: f32);
    pub fn bpdSoundManagerGetGlobalVolume(sound_manager: *mut SoundManager) -> f32;
    pub fn bpdSoundManagerSetListenerTransform(
        sound_manager: *mut SoundManager,
        position_x: f32,
        position_y: f32,
        position_z: f32,
        forward_x: f32,
        forward_y: f32,
        forward_z: f32,
        up_x: f32,
        up_y: f32,
        up_z: f32,
    );
    pub fn bpdSoundManagerSetJobScheduler(
        sound_manager: *mut SoundManager,
        schedule_fn: Option<ScheduleJobFn>,
        wait_fn: Option<WaitForJobsFn>,
        user: *mut c_void,
    );
    pub fn bpdSoundManagerSetSoundBankCallbacks(
        sound_manager: *mut SoundManager,
        get_fn: Option<GetSoundBankDataFn>,
        release_fn: Option<ReleaseSoundBankDataFn>,
        user: *mut c_void,
    );
    pub fn bpdSoundManagerPreloadSoundBank(
        sound_manager: *mut SoundManager,
        name: *const c_char,
    ) -> c_int;
    pub fn bpdSoundManagerGetBulkAudioAsset(
        sound_manager: *mut SoundManager,
        path: *const c_char,
        out_duration: *mut f32,
        out_asset_id: *mut u32,
    ) -> c_int;
    pub fn bpdSoundManagerGetBulkAudioAssetByHash(
        sound_manager: *mut SoundManager,
        path_hash: u32,
        out_duration: *mut f32,
        out_asset_id: *mut u32,
    ) -> c_int;
    pub fn bpdSoundManagerGetBulkAudioAssetCount(sound_manager: *mut SoundManager) -> u32;
    pub fn bpdSoundManagerGetBulkAudioAssets(
        sound_manager: *mut SoundManager,
        out: *mut BulkAudioAssetInfo,
        max_count: u32,
    ) -> u32;
    pub fn bpdSoundManagerGetDebugStats(sound_manager: *mut SoundManager, out: *mut DebugStats);
    pub fn bpdSoundManagerResetDebugStats(sound_manager: *mut SoundManager);
    pub fn bpdSoundManagerGetRecentDecodes(
        sound_manager: *mut SoundManager,
        out: *mut DecodeRecord,
        max_count: u32,
    ) -> u32;
    pub fn bpdSoundManagerGetInFlightDecodes(
        sound_manager: *mut SoundManager,
        out: *mut InFlightDecode,
        max_count: u32,
    ) -> u32;
    pub fn bpdSoundManagerGetListenerDebugInfo(
        sound_manager: *mut SoundManager,
        out: *mut ListenerDebugInfo,
    );
    pub fn bpdSoundManagerGet3DDebugInfo(
        sound_manager: *mut SoundManager,
        out: *mut DebugInfo3D,
        max_count: u32,
    ) -> u32;
    pub fn bpdSoundManagerGetMasterGroupBus(sound_manager: *mut SoundManager) -> *mut GroupBus;
    pub fn bpdSoundManagerGetGroupBus(
        sound_manager: *mut SoundManager,
        path: *const c_char,
    ) -> *mut GroupBus;
    pub fn bpdGroupBusGetVolume(group_bus: *const GroupBus) -> f32;
    pub fn bpdGroupBusSetVolume(group_bus: *mut GroupBus, volume: f32);
    pub fn bpdEventDescriptionGetParameterIndex(
        description: *const EventDescription,
        name: *const c_char,
    ) -> u32;
    pub fn bpdEventDescriptionGetParameterCount(description: *const EventDescription) -> u32;
    pub fn bpdEventDescriptionGetParameterType(
        description: *const EventDescription,
        index: u32,
    ) -> u32;
    pub fn bpdEventDescriptionGetLength(description: *const EventDescription) -> f32;
    pub fn bpdEventDescriptionCreateInstance(
        description: *mut EventDescription,
    ) -> *mut EventInstance;
    pub fn bpdEventInstanceStart(instance: *mut EventInstance);
    pub fn bpdEventInstanceStop(instance: *mut EventInstance);
    pub fn bpdEventInstancePause(instance: *mut EventInstance);
    pub fn bpdEventInstanceUnpause(instance: *mut EventInstance);
    pub fn bpdEventInstanceRelease(instance: *mut EventInstance);
    pub fn bpdEventInstanceReleaseWhenFinished(instance: *mut EventInstance);
    pub fn bpdEventInstanceFadeIn(instance: *mut EventInstance, duration: f32);
    pub fn bpdEventInstanceReleaseAfterFadeOut(instance: *mut EventInstance, duration: f32);
    pub fn bpdEventInstanceGetState(instance: *const EventInstance) -> EventInstanceState;
    pub fn bpdEventInstanceGetTime(instance: *const EventInstance) -> f32;
    pub fn bpdEventInstanceSetParameterByIndex(
        instance: *mut EventInstance,
        index: u32,
        value: f32,
    );
    pub fn bpdEventInstanceSetParameterByName(
        instance: *mut EventInstance,
        name: *const c_char,
        value: f32,
    );
    pub fn bpdEventInstanceGetParameterByIndex(instance: *const EventInstance, index: u32) -> f32;
    pub fn bpdEventInstanceSendSignal(instance: *mut EventInstance, signal: *const c_char);
    pub fn bpdEventInstanceSetVolumeMultiplier(instance: *mut EventInstance, volume: f32);
    pub fn bpdEventInstanceGetVolumeMultiplier(instance: *const EventInstance) -> f32;
    pub fn bpdEventInstanceSetAutoPause(
        instance: *mut EventInstance,
        enabled: c_int,
        level: TickLevel,
    );
    pub fn bpdEventInstanceSet3DAttributes(
        instance: *mut EventInstance,
        position_x: f32,
        position_y: f32,
        position_z: f32,
        velocity_x: f32,
        velocity_y: f32,
        velocity_z: f32,
    );
}
