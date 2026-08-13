// Builds the Zig sample against a Timbre SDK.

// (timbre-sdk: unpacked SDK folder, the one holding bin and lib)
//     zig build -Dtimbre-sdk=C:\path\to\timbre-sdk

// The executable gets placed in zig-out\bin. Copy Timbre.dll (Windows)
// or libTimbre.so (Linux) beside it from the SDK's bin folder, and run it
// from the shared samples\assets folder in this repository, since the
// sample loads its data files from the working directory.

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "play_event_zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = target,
            .optimize = optimize,

            // The Timbre runtime is a C library, and the sample uses the
            // libc allocator for the sound bank buffers.
            .link_libc = true,
        }),
    });

    // The Timbre bindings, from this repository's bindings folder.
    exe.root_module.addImport("timbre", b.createModule(.{
        .root_source_file = .{ .cwd_relative = "../../bindings/zig/timbre.zig" },
    }));

    const sdk = b.option([]const u8, "timbre-sdk", "The Timbre SDK folder, holding bin and lib.") orelse @panic("pass -Dtimbre-sdk, the path to the unpacked Timbre SDK");

    // Where the SDK keeps the libraries: Windows links the import library
    // from lib, Linux links libTimbre.so straight from bin.
    exe.root_module.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "lib" }) });
    exe.root_module.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "bin" }) });
    exe.root_module.linkSystemLibrary("Timbre", .{});

    // So the exe finds a libTimbre.so copied next to it.
    if (target.result.os.tag != .windows) {
        exe.root_module.addRPathSpecial("$ORIGIN");
    }

    b.installArtifact(exe);
}
