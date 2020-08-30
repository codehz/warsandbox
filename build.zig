const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    b.setPreferredReleaseMode(.ReleaseFast);
    const mode = b.standardReleaseOptions();
    const target = std.zig.CrossTarget.parse(.{
        .arch_os_abi = "wasm32-freestanding"
    }) catch unreachable;
    const lib = b.addStaticLibrary("engine", "src/main.zig");
    lib.setTarget(target);
    lib.setBuildMode(mode);
    lib.setOutputDir("web/native");
    lib.install();
}