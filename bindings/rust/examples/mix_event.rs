use byprod_sys::*;
use std::ffi::{CStr, CString, c_char, c_int, c_void};
use std::path::PathBuf;
use std::{mem::MaybeUninit, ptr};

unsafe extern "C" fn print_message(message: *const c_char, _: PrintType, _: *mut c_void) {
    use std::io::Write;
    let _ = writeln!(
        std::io::stderr().lock(),
        "{}",
        unsafe { CStr::from_ptr(message) }.to_string_lossy()
    );
}

unsafe extern "C" fn get_bank(
    name: *const c_char,
    out: *mut SoundBankData,
    user: *mut c_void,
) -> c_int {
    // The SDK supplies the bank name and one writable output record.
    if unsafe { CStr::from_ptr(name) } != c"main" {
        return 0;
    }
    unsafe {
        let bank = &*user.cast::<Vec<u8>>();
        out.write(SoundBankData {
            bytes: bank.as_ptr().cast(),
            length: bank.len() as u32,
            copy_data: 0,
        });
    }
    1
}

unsafe extern "C" fn release_bank(_: *const c_char, _: *const SoundBankData, _: *mut c_void) {
    // The caller keeps the bank alive until the manager is destroyed.
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut args = std::env::args_os().skip(1);
    let project_path = PathBuf::from(
        args.next()
            .ok_or("usage: mix_event PROJECT.byprod EVENT_PATH")?,
    );
    let event = CString::new(
        args.next()
            .and_then(|arg| arg.into_string().ok())
            .ok_or("expected UTF-8 event path")?,
    )?;
    let project = std::fs::read(&project_path)?;
    let bank = std::fs::read(project_path.with_file_name("main.bybank"))?;
    u32::try_from(bank.len())?;
    // All runtime calls use one thread. The manager owns the loaded project
    // and outlives both the description and its instance.
    unsafe {
        if bpdVersion() != VERSION {
            return Err("byProd runtime version mismatch".into());
        }
        let mut settings = MaybeUninit::uninit();
        bpdSetPrint(Some(print_message), ptr::null_mut());
        bpdSoundManagerSettingsInit(settings.as_mut_ptr());
        let mut settings = settings.assume_init();
        settings.flags |= SOUND_MANAGER_HOST_MIXED;
        settings.sample_rate = 48_000;
        let manager = bpdSoundManagerCreate(&settings);
        if manager.is_null() {
            return Err("could not create the sound manager".into());
        }
        let result = mix_event(manager, &project, &bank, &event);
        bpdSoundManagerDestroy(manager);
        Ok(result?)
    }
}

unsafe fn mix_event(
    manager: *mut SoundManager,
    project: &[u8],
    bank: &Vec<u8>,
    event: &CStr,
) -> Result<(), &'static str> {
    unsafe {
        bpdSoundManagerSetSoundBankCallbacks(
            manager,
            Some(get_bank),
            Some(release_bank),
            ptr::from_ref(bank).cast_mut().cast(),
        );
        if bpdSoundManagerLoadProject(manager, project.as_ptr().cast(), project.len()) == 0 {
            return Err("could not load the sample project");
        }
        let description = bpdSoundManagerGetEventDescription(manager, event.as_ptr());
        if description.is_null() {
            return Err("event missing");
        }
        let instance = bpdEventDescriptionCreateInstance(description);
        if instance.is_null() {
            return Err("could not create the event instance");
        }
        bpdEventInstanceStart(instance);
        let mut stereo = [0.0_f32; 960];
        let mut peak = 0.0_f32;
        for _ in 0..100 {
            bpdSoundManagerUpdate(manager);
            bpdSoundManagerMix(manager, stereo.as_mut_ptr(), (stereo.len() / 2) as u32);
            for sample in stereo {
                peak = peak.max(sample.abs());
            }
        }
        bpdEventInstanceRelease(instance);
        if peak == 0.0 {
            return Err("the event produced only silence");
        }
        println!("Mixed 48,000 stereo frames, peak amplitude {peak:.3}");
    }
    Ok(())
}
