const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const library = b.option(
        std.builtin.LinkMode,
        "library",
        "Build an exportable C library.",
    );

    const build_zig_zon = b.createModule(.{
        .root_source_file = b.path("build.zig.zon"),
        .target = target,
        .optimize = optimize,
    });

    const mod = b.addModule("drivercom", .{
        .root_source_file = b.path("src/drivercom.zig"),
        .target = target,
        .optimize = optimize,
    });
    mod.addImport("build.zig.zon", build_zig_zon);

    const mod_unit_tests = b.addTest(.{ .root_module = mod });
    const run_mod_unit_tests = b.addRunArtifact(mod_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_mod_unit_tests.step);

    if (library) |l| {
        // Library Artifact
        {
            const lib = if (l == .static) b.addStaticLibrary(.{
                .name = "drivercom",
                .root_source_file = b.path("src/library.zig"),
                .target = target,
                .optimize = optimize,
            }) else b.addSharedLibrary(.{
                .name = "drivercom",
                .root_source_file = b.path("src/library.zig"),
                .target = target,
                .optimize = optimize,
            });
            lib.root_module.addImport("drivercom", mod);
            b.installArtifact(lib);
        }

        // Library Tests
        {
            const lib_unit_tests = b.addTest(.{
                .root_source_file = b.path("src/library.zig"),
                .target = target,
                .optimize = optimize,
            });
            lib_unit_tests.root_module.addImport("drivercom", mod);
            const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
            test_step.dependOn(&run_lib_unit_tests.step);
        }
    }
}
