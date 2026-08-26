// ======================================
// byProd - audio runtime
// Copyright 2026 Madrigal Ltd.
// Bindings released under the MIT license, see LICENSE in the repository root.
// ======================================

// The C symbols behind the ByProd bindings, one to one with byprod.h in the
// byProd SDK. Native.bpdSoundManagerCreate() here is bpdSoundManagerCreate() in C.

#nullable enable

using System;
using System.Runtime.InteropServices;

namespace ByProd
{
    public static class Native
    {
        // The casing matters: Linux resolves this to libbyProd.so exactly.
        public const string Library = "byProd";

        private const CallingConvention Convention = CallingConvention.Cdecl;

        public const uint InvalidParameterIndex = 0xFFFFFFFFu;

        // Flags for bpdSoundManagerCreate, combined bitwise.
        public const uint SoundManagerRightHanded3D = 0x1u;
        public const uint SoundManagerHostMixed = 0x2u;

        // ======================================
        // Callbacks. Strings arrive as NUL terminated UTF-8, see Marshal.PtrToStringUTF8.

        [UnmanagedFunctionPointer(Convention)]
        public delegate IntPtr AllocFn(nuint size, IntPtr user);

        [UnmanagedFunctionPointer(Convention)]
        public delegate void FreeFn(IntPtr ptr, IntPtr user);

        [UnmanagedFunctionPointer(Convention)]
        public delegate void PrintFn(IntPtr message, PrintType type, IntPtr user);

        [UnmanagedFunctionPointer(Convention)]
        public delegate void AssertFn(IntPtr message, IntPtr file, int line, IntPtr user);

        // The work a scheduler is asked to run.
        [UnmanagedFunctionPointer(Convention)]
        public delegate void JobFn(IntPtr jobData);

        // A function which schedules a job to be run. Eg. can be used to hook into the
        // job system of a game engine. The job function arrives as a bare pointer,
        // Marshal.GetDelegateForFunctionPointer<JobFn> turns it into a call.
        [UnmanagedFunctionPointer(Convention)]
        public delegate void ScheduleJobFn(IntPtr jobFn, IntPtr jobData, IntPtr user);

        // A function which waits until every scheduled job has run.
        [UnmanagedFunctionPointer(Convention)]
        public delegate void WaitForJobsFn(IntPtr user);

        [StructLayout(LayoutKind.Sequential)]
        public struct SoundBankData
        {
            public IntPtr Bytes;
            public uint Length;

            // Nonzero when the buffer will not outlive the call, so the runtime has
            // to take its own copy. Zero means the host holds it until the matching
            // release.
            public int CopyData;
        }

        // Fills out and returns nonzero. Returning zero means there is no such bank.
        [UnmanagedFunctionPointer(Convention)]
        public delegate int GetSoundBankDataFn(IntPtr name, ref SoundBankData data, IntPtr user);

        // Called once per get, either when the runtime has finished with the bank or
        // straight after it has copied one it was told not to keep.
        [UnmanagedFunctionPointer(Convention)]
        public delegate void ReleaseSoundBankDataFn(IntPtr name, ref SoundBankData data, IntPtr user);

        // ======================================
        // Structs the friendly layer converts on the way out.

        [StructLayout(LayoutKind.Sequential)]
        public struct BulkAudioAssetInfo
        {
            // Owned by the loaded project. NUL terminated UTF-8.
            public IntPtr Path;

            public uint PathHash;
            public uint AssetID;
            public float Duration;
        }

        // Bpd3DDebugInfo in C, renamed since a C# identifier cannot start with a digit.
        [StructLayout(LayoutKind.Sequential)]
        public struct DebugInfo3D
        {
            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 128)]
            public byte[] EventPath;

            // The instance's EventInstanceState.
            public uint State;

            public float Distance;
            public float ListenerRadialSpeed;
            public float SourceRadialSpeed;
            public float SourceSpeed;
            public float DopplerRatio;
        }

        // ======================================
        // Library version.

        [DllImport(Library, CallingConvention = Convention)]
        public static extern uint bpdVersion();

        // ======================================
        // Host hooks.

        // Replaces the allocator, which has to happen before anything else is called.
        // The callbacks must be thread safe since the audio mixer thread allocates
        // through them too. The second overload takes native function pointers.
        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdSetAllocator(AllocFn? allocFn, FreeFn? freeFn, IntPtr user);

        [DllImport(Library, EntryPoint = "bpdSetAllocator", CallingConvention = Convention)]
        public static extern void bpdSetAllocator(IntPtr allocFn, IntPtr freeFn, IntPtr user);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdSetPrint(PrintFn? printFn, IntPtr user);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdSetAssertHandler(AssertFn? handler, IntPtr user);

        // ======================================
        // String hashing.

        [DllImport(Library, CallingConvention = Convention)]
        public static extern uint bpdHashString([MarshalAs(UnmanagedType.LPUTF8Str)] string str);

        // ======================================
        // Sound manager.

        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdSoundManagerSettingsInit(ref SoundManagerSettings settings);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern IntPtr bpdSoundManagerCreate(ref SoundManagerSettings settings);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdSoundManagerDestroy(IntPtr soundManager);

        // The byte buffer calls come in two forms: an array, and a pinned reference
        // for spans.

        [DllImport(Library, CallingConvention = Convention)]
        public static extern int bpdSoundManagerLoadProject(IntPtr soundManager, byte[] bytes, nuint size);

        [DllImport(Library, EntryPoint = "bpdSoundManagerLoadProject", CallingConvention = Convention)]
        public static extern int bpdSoundManagerLoadProject(IntPtr soundManager, ref byte bytes, nuint size);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern int bpdSoundManagerLoadAdditiveProject(
            IntPtr soundManager, byte[] bytes, nuint size, byte[]? outID, uint outIDSize);

        [DllImport(Library, EntryPoint = "bpdSoundManagerLoadAdditiveProject", CallingConvention = Convention)]
        public static extern int bpdSoundManagerLoadAdditiveProject(
            IntPtr soundManager, ref byte bytes, nuint size, byte[]? outID, uint outIDSize);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern IntPtr bpdSoundManagerGetEventDescription(
            IntPtr soundManager, [MarshalAs(UnmanagedType.LPUTF8Str)] string path);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdSoundManagerUpdate(IntPtr soundManager);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdSoundManagerMix(
            IntPtr soundManager, [Out] float[] interleavedStereo, uint frameCount);

        [DllImport(Library, EntryPoint = "bpdSoundManagerMix", CallingConvention = Convention)]
        public static extern void bpdSoundManagerMix(
            IntPtr soundManager, ref float interleavedStereo, uint frameCount);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdSoundManagerSetTickLevel(IntPtr soundManager, TickLevel tickLevel);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdSoundManagerSetGlobalVolume(IntPtr soundManager, float volume);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern float bpdSoundManagerGetGlobalVolume(IntPtr soundManager);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdSoundManagerSetListenerTransform(
            IntPtr soundManager,
            float positionX, float positionY, float positionZ,
            float forwardX, float forwardY, float forwardZ,
            float upX, float upY, float upZ);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdSoundManagerSetJobScheduler(
            IntPtr soundManager, ScheduleJobFn? scheduleFn, WaitForJobsFn? waitFn, IntPtr user);

        // ======================================
        // Sound banks.

        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdSoundManagerSetSoundBankCallbacks(
            IntPtr soundManager, GetSoundBankDataFn? getFn, ReleaseSoundBankDataFn? releaseFn, IntPtr user);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern int bpdSoundManagerPreloadSoundBank(
            IntPtr soundManager, [MarshalAs(UnmanagedType.LPUTF8Str)] string name);

        // ======================================
        // Bulk audio.

        [DllImport(Library, CallingConvention = Convention)]
        public static extern int bpdSoundManagerGetBulkAudioAsset(
            IntPtr soundManager, [MarshalAs(UnmanagedType.LPUTF8Str)] string path,
            out float outDuration, out uint outAssetID);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern int bpdSoundManagerGetBulkAudioAssetByHash(
            IntPtr soundManager, uint pathHash, out float outDuration, out uint outAssetID);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern uint bpdSoundManagerGetBulkAudioAssetCount(IntPtr soundManager);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern uint bpdSoundManagerGetBulkAudioAssets(
            IntPtr soundManager, [Out] BulkAudioAssetInfo[] outInfos, uint maxCount);

        // ======================================
        // Debug statistics.

        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdSoundManagerGetDebugStats(IntPtr soundManager, out DebugStats outStats);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdSoundManagerResetDebugStats(IntPtr soundManager);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern uint bpdSoundManagerGetRecentDecodes(
            IntPtr soundManager, [Out] DecodeRecord[] outRecords, uint maxCount);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern uint bpdSoundManagerGetInFlightDecodes(
            IntPtr soundManager, [Out] InFlightDecode[] outDecodes, uint maxCount);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdSoundManagerGetListenerDebugInfo(
            IntPtr soundManager, out ListenerDebugInfo outInfo);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern uint bpdSoundManagerGet3DDebugInfo(
            IntPtr soundManager, [Out] DebugInfo3D[] outInfos, uint maxCount);

        // ======================================
        // Group buses.

        [DllImport(Library, CallingConvention = Convention)]
        public static extern IntPtr bpdSoundManagerGetMasterGroupBus(IntPtr soundManager);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern IntPtr bpdSoundManagerGetGroupBus(
            IntPtr soundManager, [MarshalAs(UnmanagedType.LPUTF8Str)] string path);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern float bpdGroupBusGetVolume(IntPtr groupBus);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdGroupBusSetVolume(IntPtr groupBus, float volume);

        // ======================================
        // Event descriptions.

        [DllImport(Library, CallingConvention = Convention)]
        public static extern uint bpdEventDescriptionGetParameterIndex(
            IntPtr description, [MarshalAs(UnmanagedType.LPUTF8Str)] string name);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern uint bpdEventDescriptionGetParameterCount(IntPtr description);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern uint bpdEventDescriptionGetParameterType(IntPtr description, uint index);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern float bpdEventDescriptionGetLength(IntPtr description);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern IntPtr bpdEventDescriptionCreateInstance(IntPtr description);

        // ======================================
        // Event instances.

        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdEventInstanceStart(IntPtr instance);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdEventInstanceStop(IntPtr instance);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdEventInstancePause(IntPtr instance);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdEventInstanceUnpause(IntPtr instance);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdEventInstanceRelease(IntPtr instance);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdEventInstanceReleaseWhenFinished(IntPtr instance);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdEventInstanceFadeIn(IntPtr instance, float duration);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdEventInstanceReleaseAfterFadeOut(IntPtr instance, float duration);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern EventInstanceState bpdEventInstanceGetState(IntPtr instance);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern float bpdEventInstanceGetTime(IntPtr instance);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdEventInstanceSetParameterByIndex(IntPtr instance, uint index, float value);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdEventInstanceSetParameterByName(
            IntPtr instance, [MarshalAs(UnmanagedType.LPUTF8Str)] string name, float value);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern float bpdEventInstanceGetParameterByIndex(IntPtr instance, uint index);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdEventInstanceSendSignal(
            IntPtr instance, [MarshalAs(UnmanagedType.LPUTF8Str)] string signal);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdEventInstanceSetVolumeMultiplier(IntPtr instance, float volume);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern float bpdEventInstanceGetVolumeMultiplier(IntPtr instance);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdEventInstanceSetAutoPause(IntPtr instance, int enabled, TickLevel level);

        [DllImport(Library, CallingConvention = Convention)]
        public static extern void bpdEventInstanceSet3DAttributes(
            IntPtr instance,
            float positionX, float positionY, float positionZ,
            float velocityX, float velocityY, float velocityZ);
    }
}
