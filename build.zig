const std = @import("std");
const raylib_build = @import("libs/raylib/src/build.zig");
const fnl_build = @import("libs/FastNoiseLite/build.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "terrain-gen",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    // add raylib
    const raylib = raylib_build.addRaylib(b, target, optimize, .{});
    exe.addIncludePath(.{ .path = "libs/raylib/src" });
    exe.linkLibrary(raylib);

    // add fastnoiselite
    const fnl = fnl_build.addFastNoiseLite(b, target, optimize);
    exe.addIncludePath(.{ .path = "libs/FastNoiseLite/src" });
    exe.linkLibrary(fnl);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
