// ======================================
// byProd - audio runtime
// Copyright 2026 Madrigal Ltd.
// Bindings released under the MIT license, see LICENSE in the repository root.
// ======================================

// C# bindings over the byProd C API. These bindings are not the official
// authoritative API. That is byprod.h in the byProd SDK.

// The bpd prefix is stripped so soundManager.Update() here is
// bpdSoundManagerUpdate() in C. The C declarations themselves are in ByProd.Native.cs.

// Threading: The public API of byProd is supposed to be called from only
// one thread at a time. The library uses threads internally for mixing,
// and can be hooked into a host-provided job system for async wave data
// decoding. See SoundManager.JobScheduler for more information. A sound
// manager created with SoundManagerFlags.HostMixed runs no internal
// threads at all. The host pulls the mixed audio with SoundManager.Mix().

#nullable enable

using System;
using System.Collections.Generic;
using System.Numerics;
using System.Runtime.InteropServices;
using System.Text;

namespace ByProd
{
    // ======================================
    // Enums.

    public enum PrintType
    {
        Info = 0,
        Warning = 1,
        Error = 2,
    }

    public enum RuntimeEnvironment
    {
        App = 0,
        PreviewInEditor = 1,
    }

    // How much of the world is being simulated, as three levels of "pausedness".
    // A host with no use for it passes None (Paused) and Full (Unpaused) only.
    public enum TickLevel
    {
        None = 0,
        Partial = 1,
        Full = 2,
    }

    // Flags for creating a sound manager, combined bitwise.
    [Flags]
    public enum SoundManagerFlags : uint
    {
        None = 0,

        // byProd positions 3D audio in a left-handed coordinate system by default.
        // This flag switches the sound manager to a right-handed one.
        RightHanded3D = Native.SoundManagerRightHanded3D,

        // byProd opens no audio device and runs no thread of its own, and renders
        // audio only when the host calls SoundManager.Mix(). For hosts that own
        // their audio pipeline, eg. web games. Requires a real sample rate at creation.
        HostMixed = Native.SoundManagerHostMixed,
    }

    public enum EventInstanceState
    {
        Stopped = 0,
        Playing = 1,
        Paused = 2,

        // Reached an End node, or ran out of anything left to do.
        Finished = 3,
    }

    public enum WaveAssetLoadState
    {
        Pending = 0,
        Decoding = 1,
        Ready = 2,
        Failed = 3,
    }

    // Data type IDs shared with the editor. The low numbers are what Solmu uses
    // to identify types. byProd's block starts at 300 (= invalid) so the first
    // real type is 301.
    public enum DataType : uint
    {
        Invalid = 0,
        Float = 1,
        Double = 2,
        Int8 = 3,
        UInt8 = 4,
        Int16 = 5,
        UInt16 = 6,
        Int32 = 7,
        UInt32 = 8,
        Int64 = 9,
        UInt64 = 10,
        Bool = 11,
        String = 12,
        Vec2 = 14,
        Vec3 = 15,
        Vec4 = 16,
        AnyValue = 31,
        VecVariant = 32,
        Execution = 201,

        WaveAsset = 301,
        AudioSource = 302,
        AudioFilter = 303,
    }

    // ======================================
    // Library version and host hooks.

    public delegate void PrintHandler(PrintType type, string message);

    public delegate void AssertHandler(string message, string file, int line);

    public static class Runtime
    {
        public const uint VersionMajor = 0;
        public const uint VersionMinor = 5;
        public const uint VersionPatch = 2;

        public const uint Version = (VersionMajor << 16) | (VersionMinor << 8) | VersionPatch;

        // Returns the version the library was built as. Compare against Version
        // from the bindings you compiled against before using anything else.
        public static uint LibraryVersion => Native.bpdVersion();

        // MurmurHash3, x86 32 bit variant, seeded zero, over the bytes of the string
        // without its trailing null. The x86 and x64 variants of MurmurHash3 disagree,
        // so a host reimplementing this rather than calling it wants the x86 one.
        public static uint HashString(string str) => Native.bpdHashString(str);

        private static PrintHandler? s_printHandler;
        private static AssertHandler? s_assertHandler;

        private static readonly Native.PrintFn s_printTrampoline = OnPrint;
        private static readonly Native.AssertFn s_assertTrampoline = OnAssert;

        public static PrintHandler? PrintHandler
        {
            get => s_printHandler;
            set
            {
                s_printHandler = value;
                Native.bpdSetPrint(value != null ? s_printTrampoline : null, IntPtr.Zero);
            }
        }

        // Replaces what runs when a runtime assertion fails. Without a handler the
        // message goes to the print hook and the process aborts. A handler that
        // returns instead of aborting makes the runtime continue past the failure
        // (usually with an early-out or another way to handle the error).
        public static AssertHandler? AssertHandler
        {
            get => s_assertHandler;
            set
            {
                s_assertHandler = value;
                Native.bpdSetAssertHandler(value != null ? s_assertTrampoline : null, IntPtr.Zero);
            }
        }

        // Exceptions never cross into the runtime: callbacks catch and report here.
        internal static void ReportCallbackException(Exception exception)
        {
            try
            {
                s_printHandler?.Invoke(PrintType.Error, "byProd: a managed callback threw: " + exception);
            }
            catch
            {
            }
        }

        internal static string StringFromUtf8(IntPtr utf8)
        {
            return utf8 != IntPtr.Zero ? Marshal.PtrToStringUTF8(utf8) ?? string.Empty : string.Empty;
        }

        internal static string StringFromUtf8(byte[] buffer)
        {
            int length = Array.IndexOf(buffer, (byte)0);
            return Encoding.UTF8.GetString(buffer, 0, length < 0 ? buffer.Length : length);
        }

        private static void OnPrint(IntPtr message, PrintType type, IntPtr user)
        {
            try
            {
                s_printHandler?.Invoke(type, StringFromUtf8(message));
            }
            catch
            {
            }
        }

        private static void OnAssert(IntPtr message, IntPtr file, int line, IntPtr user)
        {
            try
            {
                s_assertHandler?.Invoke(StringFromUtf8(message), StringFromUtf8(file), line);
            }
            catch (Exception exception)
            {
                ReportCallbackException(exception);
            }
        }
    }

    // ======================================
    // Sound manager.

    // Everything a sound manager is created with. Start from Default, then adjust what you need.
    [StructLayout(LayoutKind.Sequential)]
    public struct SoundManagerSettings
    {
        public RuntimeEnvironment Environment;

        // Combination of the SoundManagerFlags.
        public SoundManagerFlags Flags;

        // The mixing rate in Hz. Zero lets the audio device decide, which is the default.
        // HostMixed has no device to ask, so it needs a real rate here.
        public uint SampleRate;

        // Scales the whole mix once, on top of everything else. This is a fixed compensation
        // set at creation, not the global volume which can be adjusted later. Certain SoLoud
        // backends pull the mix down a little, and this compensates for that.
        public float GlobalVolumeMultiplier;

        // SoLoud's scaler for the mix after clipping.
        public float PostClipScaler;

        // How many voices can be audible at once. Voices beyond this still advance,
        // they just can't be heard.
        public uint MaxActiveVoiceCount;

        // The settings filled with the defaults. It's recommended to always start from
        // this even if you override parameters before creating the sound manager. That
        // way new parameters can be added in later versions and have reasonable default values.
        public static SoundManagerSettings Default
        {
            get
            {
                var settings = new SoundManagerSettings();
                Native.bpdSoundManagerSettingsInit(ref settings);
                return settings;
            }
        }
    }

    // Returns the bytes of the named sound bank, or null when there is no such
    // bank. The array is pinned and handed over without a copy, and unpinned
    // once the runtime is done with it. Returning the same array twice is fine.
    public delegate byte[]? SoundBankLoader(string name);

    // One piece of decoding work handed to a scheduler.
    public readonly struct Job
    {
        private readonly IntPtr _function;
        private readonly IntPtr _data;

        internal Job(IntPtr function, IntPtr data)
        {
            _function = function;
            _data = data;
        }

        // Runs the job, on whatever thread the scheduler chose.
        public void Run() => Marshal.GetDelegateForFunctionPointer<Native.JobFn>(_function)(_data);
    }

    // Hooks wave decoding into the job system of a game engine. Schedule returns
    // without running the job, WaitForAll blocks until every scheduled job has run.
    public interface IJobScheduler
    {
        void Schedule(Job job);

        void WaitForAll();
    }

    public sealed class SoundManager : IDisposable
    {
        private IntPtr _handle;
        private GCHandle _self;

        private SoundBankLoader? _soundBankLoader;
        private IJobScheduler? _jobScheduler;

        private struct PinnedBank
        {
            public GCHandle Handle;
            public int Count;
        }

        private readonly Dictionary<IntPtr, PinnedBank> _pinnedBanks = new Dictionary<IntPtr, PinnedBank>();

        private static readonly Native.GetSoundBankDataFn s_getSoundBank = OnGetSoundBank;
        private static readonly Native.ReleaseSoundBankDataFn s_releaseSoundBank = OnReleaseSoundBank;
        private static readonly Native.ScheduleJobFn s_scheduleJob = OnScheduleJob;
        private static readonly Native.WaitForJobsFn s_waitForJobs = OnWaitForJobs;

        private SoundManager(IntPtr handle)
        {
            _handle = handle;
            _self = GCHandle.Alloc(this);
        }

        // Creates the sound manager with the given settings. Returns null and prints
        // an error if creation fails. The settings struct is copied and doesn't need
        // to be held onto.
        public static SoundManager? Create(SoundManagerSettings settings)
        {
            IntPtr handle = Native.bpdSoundManagerCreate(ref settings);
            return handle != IntPtr.Zero ? new SoundManager(handle) : null;
        }

        public static SoundManager? Create() => Create(SoundManagerSettings.Default);

        public void Dispose()
        {
            if (_handle == IntPtr.Zero)
            {
                return;
            }

            Native.bpdSoundManagerDestroy(_handle);
            _handle = IntPtr.Zero;
            _self.Free();

            lock (_pinnedBanks)
            {
                foreach (PinnedBank bank in _pinnedBanks.Values)
                {
                    bank.Handle.Free();
                }

                _pinnedBanks.Clear();
            }
        }

        public IntPtr Handle => _handle;

        // Loads a built project from a .byprod file. The bytes are copied, so the
        // caller's buffer is not referenced afterwards.
        public bool LoadProject(ReadOnlySpan<byte> bytes)
        {
            if (bytes.IsEmpty)
            {
                return false;
            }

            return Native.bpdSoundManagerLoadProject(
                _handle, ref MemoryMarshal.GetReference(bytes), (nuint)bytes.Length) != 0;
        }

        // Loads an additive project, adding its data to the already loaded main
        // project. The bytes are copied, as above. Refused, with nothing kept, when
        // the data will not parse, when it is a main project rather than an additive
        // one, or when a project with the same ID is already loaded.
        
        // Returns the project's own ID in projectID. Needed because the additive
        // project's soundbanks are named "[projectID]bankName".
        public bool LoadAdditiveProject(ReadOnlySpan<byte> bytes, out string projectID)
        {
            projectID = string.Empty;

            if (bytes.IsEmpty)
            {
                return false;
            }

            var idBuffer = new byte[256];

            int loaded = Native.bpdSoundManagerLoadAdditiveProject(
                _handle, ref MemoryMarshal.GetReference(bytes), (nuint)bytes.Length,
                idBuffer, (uint)idBuffer.Length);

            if (loaded == 0)
            {
                return false;
            }

            projectID = Runtime.StringFromUtf8(idBuffer);
            return true;
        }

        // Looks an event up by its authored path, such as "event:/Music/MainMenu".
        // Null when the project has no such event.
        public EventDescription? GetEventDescription(string path)
        {
            IntPtr handle = Native.bpdSoundManagerGetEventDescription(_handle, path);
            return handle != IntPtr.Zero ? new EventDescription(handle) : (EventDescription?)null;
        }

        // Updates the sound manager and advances every playing event instance.
        public void Update() => Native.bpdSoundManagerUpdate(_handle);

        // Renders the next frames as interleaved stereo float samples, so a buffer
        // of frameCount * 2 floats receives frameCount frames. Only for a sound
        // manager created with HostMixed. Any other manager fills silence and
        // reports an error once. Any frame count works, the chunking happens inside.
        
        // In host mixed mode this call is also the clock. Mixed frames are elapsed
        // time, ie. mixing one second of audio advances events by one second, applied
        // at the next Update(). So mix only what your audio output actually plays,
        // and event time stays in step with what you hear.
        public void Mix(Span<float> interleavedStereo)
        {
            int frameCount = interleavedStereo.Length / 2;

            if (frameCount > 0)
            {
                Native.bpdSoundManagerMix(_handle, ref MemoryMarshal.GetReference(interleavedStereo), (uint)frameCount);
            }
        }

        // How much of the world is running. Pauses and resumes the instances that
        // opted into following it, and leaves the rest playing. Full by default.
        public void SetTickLevel(TickLevel tickLevel) => Native.bpdSoundManagerSetTickLevel(_handle, tickLevel);

        // Scales everything, on top of each event's own volume. This is the master
        // bus, which is what a host means by a global volume. One by default.
        public float GlobalVolume
        {
            get => Native.bpdSoundManagerGetGlobalVolume(_handle);
            set => Native.bpdSoundManagerSetGlobalVolume(_handle, value);
        }

        // Where the listener is and which way it faces, in world units. Forward and
        // up are the transform's Z and Y axes. Default: identity.
        public void SetListenerTransform(
            float positionX, float positionY, float positionZ,
            float forwardX, float forwardY, float forwardZ,
            float upX, float upY, float upZ)
        {
            Native.bpdSoundManagerSetListenerTransform(
                _handle, positionX, positionY, positionZ, forwardX, forwardY, forwardZ, upX, upY, upZ);
        }

        public void SetListenerTransform(Vector3 position, Vector3 forward, Vector3 up)
        {
            SetListenerTransform(position.X, position.Y, position.Z, forward.X, forward.Y, forward.Z, up.X, up.Y, up.Z);
        }

        // ======================================
        // Sound banks.

        // The runtime never opens a file. It asks the loader for a bank by name and
        // gives the bytes back when the last thing using them is done, so audio can
        // live in whatever the host already stores files in.
        public SoundBankLoader? SoundBankLoader
        {
            get => _soundBankLoader;
            set
            {
                _soundBankLoader = value;

                if (value != null)
                {
                    Native.bpdSoundManagerSetSoundBankCallbacks(
                        _handle, s_getSoundBank, s_releaseSoundBank, GCHandle.ToIntPtr(_self));
                }
                else
                {
                    Native.bpdSoundManagerSetSoundBankCallbacks(_handle, null, null, IntPtr.Zero);
                }
            }
        }

        // Fetches a bank now and keeps it, instead of leaving it to arrive when the
        // first event that needs it plays. Eg. a game can preload the bank its common
        // sounds live in, so that the first gunshot of a level does not wait on the
        // host reading a file.
        //
        // The bank stays resident until the project is replaced or the sound manager
        // is disposed, either of which gives the reference back. False when the host
        // has no such bank.
        //
        // Call after loading a project: loading one drops every bank it had.
        public bool PreloadSoundBank(string name) => Native.bpdSoundManagerPreloadSoundBank(_handle, name) != 0;

        // Used to hook wave decoding jobs into the job system of a game engine, or some
        // other multithreading solution. Default: null, which means that the decoding
        // is done on the main thread.
        public IJobScheduler? JobScheduler
        {
            get => _jobScheduler;
            set
            {
                _jobScheduler = value;

                if (value != null)
                {
                    Native.bpdSoundManagerSetJobScheduler(
                        _handle, s_scheduleJob, s_waitForJobs, GCHandle.ToIntPtr(_self));
                }
                else
                {
                    Native.bpdSoundManagerSetJobScheduler(_handle, null, null, IntPtr.Zero);
                }
            }
        }

        // ======================================
        // Group buses.

        // Master bus, always present, and the default.
        // Its volume is the same one GlobalVolume sets.
        public GroupBus MasterGroupBus => new GroupBus(Native.bpdSoundManagerGetMasterGroupBus(_handle));

        // By authored path, such as "groupbus:/Buses/Music".
        // Null when the project declares no such bus.
        public GroupBus? GetGroupBus(string path)
        {
            IntPtr handle = Native.bpdSoundManagerGetGroupBus(_handle, path);
            return handle != IntPtr.Zero ? new GroupBus(handle) : (GroupBus?)null;
        }

        // ======================================
        // Bulk audio.

        // Audio brought in wholesale by folder rather than authored one asset at a
        // time, eg. dialogue lines.

        // Both fill the two outputs and return true. False means the project declares
        // no such entry.

        public bool TryGetBulkAudioAsset(string path, out uint assetID, out float duration)
        {
            return Native.bpdSoundManagerGetBulkAudioAsset(_handle, path, out duration, out assetID) != 0;
        }

        public bool TryGetBulkAudioAssetByHash(uint pathHash, out uint assetID, out float duration)
        {
            return Native.bpdSoundManagerGetBulkAudioAssetByHash(_handle, pathHash, out duration, out assetID) != 0;
        }

        // How many entries every loaded project declares between them, which is what
        // to size a buffer by.
        public int BulkAudioAssetCount => (int)Native.bpdSoundManagerGetBulkAudioAssetCount(_handle);

        // Fills as many entries as fit and returns how many were written.
        public int GetBulkAudioAssets(BulkAudioAssetInfo[] buffer)
        {
            var scratch = new Native.BulkAudioAssetInfo[buffer.Length];
            int count = (int)Native.bpdSoundManagerGetBulkAudioAssets(_handle, scratch, (uint)scratch.Length);

            for (int i = 0; i < count; ++i)
            {
                buffer[i].Path = Runtime.StringFromUtf8(scratch[i].Path);
                buffer[i].PathHash = scratch[i].PathHash;
                buffer[i].AssetID = scratch[i].AssetID;
                buffer[i].Duration = scratch[i].Duration;
            }

            return count;
        }

        // ======================================
        // Debug statistics.

        public DebugStats GetDebugStats()
        {
            Native.bpdSoundManagerGetDebugStats(_handle, out DebugStats stats);
            return stats;
        }

        // Zeroes the running totals.
        public void ResetDebugStats() => Native.bpdSoundManagerResetDebugStats(_handle);

        // Both fill as many entries as fit and return how many were written.

        public int GetRecentDecodes(DecodeRecord[] buffer)
        {
            return (int)Native.bpdSoundManagerGetRecentDecodes(_handle, buffer, (uint)buffer.Length);
        }

        public int GetInFlightDecodes(InFlightDecode[] buffer)
        {
            return (int)Native.bpdSoundManagerGetInFlightDecodes(_handle, buffer, (uint)buffer.Length);
        }

        // Fills as many entries as fit, one per registered 3D event instance, and
        // returns how many were written.
        public int Get3DDebugInfo(DebugInfo3D[] buffer)
        {
            var scratch = new Native.DebugInfo3D[buffer.Length];
            int count = (int)Native.bpdSoundManagerGet3DDebugInfo(_handle, scratch, (uint)scratch.Length);

            for (int i = 0; i < count; ++i)
            {
                buffer[i].EventPath = Runtime.StringFromUtf8(scratch[i].EventPath);
                buffer[i].State = (EventInstanceState)scratch[i].State;
                buffer[i].Distance = scratch[i].Distance;
                buffer[i].ListenerRadialSpeed = scratch[i].ListenerRadialSpeed;
                buffer[i].SourceRadialSpeed = scratch[i].SourceRadialSpeed;
                buffer[i].SourceSpeed = scratch[i].SourceSpeed;
                buffer[i].DopplerRatio = scratch[i].DopplerRatio;
            }

            return count;
        }

        // The listener as the mixer currently sees it.
        public ListenerDebugInfo GetListenerDebugInfo()
        {
            Native.bpdSoundManagerGetListenerDebugInfo(_handle, out ListenerDebugInfo info);
            return info;
        }

        // ======================================
        // Callbacks.

        private static SoundManager FromUser(IntPtr user) => (SoundManager)GCHandle.FromIntPtr(user).Target!;

        // Pinned banks are keyed by address, with a count so the same array
        // handed out twice is pinned once and unpinned once.
        private IntPtr PinBank(byte[] bytes)
        {
            lock (_pinnedBanks)
            {
                GCHandle handle = GCHandle.Alloc(bytes, GCHandleType.Pinned);
                IntPtr address = handle.AddrOfPinnedObject();

                if (_pinnedBanks.TryGetValue(address, out PinnedBank existing))
                {
                    handle.Free();
                    existing.Count++;
                    _pinnedBanks[address] = existing;
                }
                else
                {
                    _pinnedBanks[address] = new PinnedBank { Handle = handle, Count = 1 };
                }

                return address;
            }
        }

        private void UnpinBank(IntPtr address)
        {
            lock (_pinnedBanks)
            {
                if (!_pinnedBanks.TryGetValue(address, out PinnedBank bank))
                {
                    return;
                }

                if (--bank.Count > 0)
                {
                    _pinnedBanks[address] = bank;
                    return;
                }

                bank.Handle.Free();
                _pinnedBanks.Remove(address);
            }
        }

        private static int OnGetSoundBank(IntPtr name, ref Native.SoundBankData data, IntPtr user)
        {
            try
            {
                SoundManager manager = FromUser(user);
                byte[]? bytes = manager._soundBankLoader?.Invoke(Runtime.StringFromUtf8(name));

                if (bytes == null || bytes.Length == 0)
                {
                    return 0;
                }

                data.Bytes = manager.PinBank(bytes);
                data.Length = (uint)bytes.Length;
                data.CopyData = 0;

                return 1;
            }
            catch (Exception exception)
            {
                Runtime.ReportCallbackException(exception);
                return 0;
            }
        }

        private static void OnReleaseSoundBank(IntPtr name, ref Native.SoundBankData data, IntPtr user)
        {
            try
            {
                FromUser(user).UnpinBank(data.Bytes);
            }
            catch (Exception exception)
            {
                Runtime.ReportCallbackException(exception);
            }
        }

        private static void OnScheduleJob(IntPtr jobFn, IntPtr jobData, IntPtr user)
        {
            try
            {
                var job = new Job(jobFn, jobData);
                IJobScheduler? scheduler = FromUser(user)._jobScheduler;

                if (scheduler != null)
                {
                    scheduler.Schedule(job);
                }
                else
                {
                    job.Run();
                }
            }
            catch (Exception exception)
            {
                Runtime.ReportCallbackException(exception);
            }
        }

        private static void OnWaitForJobs(IntPtr user)
        {
            try
            {
                FromUser(user)._jobScheduler?.WaitForAll();
            }
            catch (Exception exception)
            {
                Runtime.ReportCallbackException(exception);
            }
        }
    }

    // ======================================
    // Group buses.

    // The mixing points an event's voices play into.
    public readonly struct GroupBus
    {
        public GroupBus(IntPtr handle) => Handle = handle;

        public IntPtr Handle { get; }

        public float Volume
        {
            get => Native.bpdGroupBusGetVolume(Handle);
            set => Native.bpdGroupBusSetVolume(Handle, value);
        }
    }

    // ======================================
    // Event descriptions.

    public readonly struct EventDescription
    {
        public const uint InvalidParameterIndex = Native.InvalidParameterIndex;

        public EventDescription(IntPtr handle) => Handle = handle;

        public IntPtr Handle { get; }

        public uint GetParameterIndex(string name) => Native.bpdEventDescriptionGetParameterIndex(Handle, name);

        public uint ParameterCount => Native.bpdEventDescriptionGetParameterCount(Handle);

        // One of the DataType values, or Invalid for a bad index.
        public DataType GetParameterType(uint index) => (DataType)Native.bpdEventDescriptionGetParameterType(Handle, index);

        // Seconds, negative when the event's length was never determined.
        public float Length => Native.bpdEventDescriptionGetLength(Handle);

        // Null when the graph could not be built, which is reported through the
        // print hook.
        public EventInstance? CreateInstance()
        {
            IntPtr handle = Native.bpdEventDescriptionCreateInstance(Handle);
            return handle != IntPtr.Zero ? new EventInstance(handle) : (EventInstance?)null;
        }
    }

    // ======================================
    // Event instances.

    public readonly struct EventInstance
    {
        public EventInstance(IntPtr handle) => Handle = handle;

        public IntPtr Handle { get; }

        public void Start() => Native.bpdEventInstanceStart(Handle);
        public void Stop() => Native.bpdEventInstanceStop(Handle);
        public void Pause() => Native.bpdEventInstancePause(Handle);
        public void Unpause() => Native.bpdEventInstanceUnpause(Handle);

        // Hands the instance back to the sound manager, which destroys it. The
        // handle is dead afterwards.
        public void Release() => Native.bpdEventInstanceRelease(Handle);

        // Hands it back on its own, the next update after it finishes. For a sound
        // started and then forgotten about, where there is nobody left to release it.
        // The handle is dead from that point.
        public void ReleaseWhenFinished() => Native.bpdEventInstanceReleaseWhenFinished(Handle);

        // Ramps the instance up from silence over the duration in seconds. Ignored
        // while another fade is already running. Scales on top of the volume
        // multiplier rather than replacing it, so a host can set both.
        public void FadeIn(float duration) => Native.bpdEventInstanceFadeIn(Handle, duration);

        // Ramps down to silence over the duration in seconds and then hands the
        // instance back, as ReleaseWhenFinished does. Asking twice does not restart
        // the fade. An instance that stops or finishes partway through is released
        // there and then. The handle is dead once the fade completes.
        public void ReleaseAfterFadeOut(float duration) => Native.bpdEventInstanceReleaseAfterFadeOut(Handle, duration);

        public EventInstanceState State => Native.bpdEventInstanceGetState(Handle);

        // Seconds since the instance started, which is what an Event Time node
        // reads and what a preview displays.
        public float Time => Native.bpdEventInstanceGetTime(Handle);

        // Float/int parameters are clamped to the range the parameter was authored with.
        public void SetParameter(uint index, float value) => Native.bpdEventInstanceSetParameterByIndex(Handle, index, value);
        public void SetParameter(string name, float value) => Native.bpdEventInstanceSetParameterByName(Handle, name, value);
        public float GetParameter(uint index) => Native.bpdEventInstanceGetParameterByIndex(Handle, index);

        public void SendSignal(string signal) => Native.bpdEventInstanceSendSignal(Handle, signal);

        // Scales everything this instance plays, on top of the event's own volume
        // and whatever its graph asks for. One by default.
        public float VolumeMultiplier
        {
            get => Native.bpdEventInstanceGetVolumeMultiplier(Handle);
            set => Native.bpdEventInstanceSetVolumeMultiplier(Handle, value);
        }

        // Pauses this instance whenever the tick level drops to the given one or
        // below, and resumes it when the level rises again. Off by default, which
        // means that the event keeps playing regardless of tick level.
        public void SetAutoPause(bool enabled, TickLevel level) => Native.bpdEventInstanceSetAutoPause(Handle, enabled ? 1 : 0, level);

        // Where the event is and how fast it is moving, in world units and units
        // per second. Ignored by an event that was not authored as 3D.
        public void Set3DAttributes(
            float positionX, float positionY, float positionZ,
            float velocityX, float velocityY, float velocityZ)
        {
            Native.bpdEventInstanceSet3DAttributes(Handle, positionX, positionY, positionZ, velocityX, velocityY, velocityZ);
        }

        public void Set3DAttributes(Vector3 position, Vector3 velocity)
        {
            Set3DAttributes(position.X, position.Y, position.Z, velocity.X, velocity.Y, velocity.Z);
        }
    }

    // ======================================
    // Bulk audio.

    public struct BulkAudioAssetInfo
    {
        public string Path;
        public uint PathHash;
        public uint AssetID;
        public float Duration;
    }

    // ======================================
    // Debug/profiling.

    [StructLayout(LayoutKind.Sequential)]
    public struct DebugStats
    {
        private int _decodeInBackground;

        public uint WaveAssetRefCount;
        public uint LoadedWaveAssetCount;
        public ulong LoadedDecodedBytes;

        public uint InFlightDecodeCount;
        public uint SoundBankCount;
        public uint ActiveVoiceCount;

        // Since startup, or since the last reset.
        public ulong DecodesStarted;
        public ulong DecodesCompleted;
        public ulong DecodesFailed;
        public ulong DecodesCancelled;
        public uint PeakInFlightDecodes;

        // True when a scheduler is installed, so decoding is done on a background thread.
        public bool DecodeInBackground => _decodeInBackground != 0;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DecodeRecord
    {
        public uint AssetID;

        // Ready or Failed.
        public WaveAssetLoadState Outcome;

        public float DecodeSeconds;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct InFlightDecode
    {
        public uint AssetID;
        public WaveAssetLoadState State;

        // How long since the decode was asked for, which is not the same as how
        // long it has been running, since the scheduler may not have started it yet.
        public float ElapsedSeconds;
    }

    // The listener as the mixer currently sees it.
    [StructLayout(LayoutKind.Sequential)]
    public struct ListenerDebugInfo
    {
        public Vector3 Position;
        public Vector3 Velocity;
        public float Speed;
    }

    // One 3D event instance's spatial debug view, computed with the same formula
    // as the mixer. The radial speeds are the projections on the listener-to-source
    // line. Both positive and equal means source and listener co-moving, which is a
    // ratio of one.
    public struct DebugInfo3D
    {
        public string EventPath;

        // A stopped or paused instance still gets a row, since it still holds 3D
        // attributes, but no audible voice is applying them.
        public EventInstanceState State;

        public float Distance;

        // Listener speed along the line, positive when closing on the source.
        public float ListenerRadialSpeed;

        // Source speed along the line, positive when pulling away.
        public float SourceRadialSpeed;

        public float SourceSpeed;
        public float DopplerRatio;
    }
}
