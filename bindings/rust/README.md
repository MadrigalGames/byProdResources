# byprod-sys

Dependency-free, `no_std` Rust FFI for byProd 0.5.5. Functions keep their
`bpd` names from the C API. The SDK header `byprod.h` defines the native API.
Add the crate to your application's Cargo.toml, adjusting the path to your checkout.

```toml
[dependencies]
byprod-sys = { path = "../byProdResources/bindings/rust" }
```

Use the matching SDK runtime for your target architecture. On Windows the
crate links directly to `byProd.dll`. Put the SDK's `bin` directory on
`PATH` or copy the DLL beside your executable. On Linux set
`RUSTFLAGS="-L native=/path/to/sdk/bin"` for linking and add the same
directory to `LD_LIBRARY_PATH` when running.

Run the example from the repository root with a project exported for SDK
0.5.5 (project data version 15), its adjacent `main.bybank`, and an event
path from that project. It mixes one second into a stereo buffer without an
audio device and prints the peak amplitude. The repository's bundled
`sample_project.byprod` uses the older project data version 14.

```sh
cargo run --manifest-path bindings/rust/Cargo.toml --example mix_event -- path/to/project.byprod event:/Drums
```

Check `bpdVersion()` against `VERSION` before initialization. Initialize
settings with `bpdSoundManagerSettingsInit` and serialize runtime calls.
Keep callbacks and their user data alive while registered. A borrowed sound
bank buffer must remain valid until its release callback runs. Event
descriptions belong to the loaded project. Release each instance once, or
transfer it back to the runtime for automatic release.
