const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("drivercon", .{
        .root_source_file = b.path("src/drivercon.zig"),
        .target = target,
        .optimize = optimize,
    });

    const library = b.option(
        std.builtin.LinkMode,
        "library",
        "Build an exportable C library.",
    );
    const cli = b.option(
        bool,
        "cli",
        "Build the accompanying CLI utility.",
    ) orelse false;

    if (library) |l| {
        const lib = if (l == .static) b.addStaticLibrary(.{
            .name = "drivercon",
            .root_source_file = b.path("src/library.zig"),
            .target = target,
            .optimize = optimize,
        }) else b.addSharedLibrary(.{
            .name = "drivercon",
            .root_source_file = b.path("src/library.zig"),
            .target = target,
            .optimize = optimize,
        });
        lib.root_module.addImport("drivercon", mod);
        b.installArtifact(lib);
    }

    if (cli) {
        const serial = b.lazyDependency("serial", .{
            .target = target,
            .optimize = optimize,
        });
        const zig_args = b.lazyDependency("args", .{
            .target = target,
            .optimize = optimize,
        });
        const exe = b.addExecutable(.{
            .name = "drivercon",
            .root_source_file = b.path("src/cli.zig"),
            .target = target,
            .optimize = optimize,
        });
        exe.root_module.addImport("drivercon", mod);
        if (serial) |i|
            exe.root_module.addImport("serial", i.module("serial"));
        if (zig_args) |i|
            exe.root_module.addImport("args", i.module("args"));
        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }

    const test_step = b.step("test", "Run unit tests");

    const mod_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/drivercon.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_mod_unit_tests = b.addRunArtifact(mod_unit_tests);
    test_step.dependOn(&run_mod_unit_tests.step);

    if (library != null) {
        const lib_unit_tests = b.addTest(.{
            .root_source_file = b.path("src/library.zig"),
            .target = target,
            .optimize = optimize,
        });
        lib_unit_tests.root_module.addImport("drivercon", mod);
        const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
        test_step.dependOn(&run_lib_unit_tests.step);
    }

    if (cli) {
        const serial = b.lazyDependency("serial", .{});
        const exe_unit_tests = b.addTest(.{
            .root_source_file = b.path("src/cli.zig"),
            .target = target,
            .optimize = optimize,
        });
        exe_unit_tests.root_module.addImport("drivercon", mod);
        if (serial) |s|
            exe_unit_tests.root_module.addImport("serial", s.module("serial"));

        const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
        test_step.dependOn(&run_exe_unit_tests.step);
    }
}
