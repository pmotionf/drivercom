const std = @import("std");

const Import = struct {
    name: []const u8,
    dependency: ?*std.Build.Dependency = null,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

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

    const test_step = b.step("test", "Run unit tests");

    const mod = b.addModule("drivercon", .{
        .root_source_file = b.path("src/drivercon.zig"),
        .target = target,
        .optimize = optimize,
    });

    const mod_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/drivercon.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_mod_unit_tests = b.addRunArtifact(mod_unit_tests);
    test_step.dependOn(&run_mod_unit_tests.step);

    if (library) |l| {
        // Library Artifact
        {
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

        // Library Tests
        {
            const lib_unit_tests = b.addTest(.{
                .root_source_file = b.path("src/library.zig"),
                .target = target,
                .optimize = optimize,
            });
            lib_unit_tests.root_module.addImport("drivercon", mod);
            const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
            test_step.dependOn(&run_lib_unit_tests.step);
        }
    }

    if (cli) {
        var imports = [_]Import{
            .{ .name = "serial" },
            .{ .name = "args" },
        };
        for (&imports) |*import| {
            import.dependency = b.lazyDependency(
                import.name,
                .{ .target = target, .optimize = optimize },
            );
        }

        // CLI Executable
        {
            const exe = b.addExecutable(.{
                .name = "drivercon",
                .root_source_file = b.path("src/cli.zig"),
                .target = target,
                .optimize = optimize,
            });
            exe.root_module.addImport("drivercon", mod);
            for (imports) |import| {
                if (import.dependency) |i| {
                    exe.root_module.addImport(
                        import.name,
                        i.module(import.name),
                    );
                }
            }
            b.installArtifact(exe);

            const run_cmd = b.addRunArtifact(exe);
            run_cmd.step.dependOn(b.getInstallStep());

            if (b.args) |args| {
                run_cmd.addArgs(args);
            }

            const run_step = b.step("run", "Run the app");
            run_step.dependOn(&run_cmd.step);
        }

        // CLI Tests
        {
            const exe_unit_tests = b.addTest(.{
                .root_source_file = b.path("src/cli.zig"),
                .target = target,
                .optimize = optimize,
            });
            exe_unit_tests.root_module.addImport("drivercon", mod);
            for (imports) |import| {
                if (import.dependency) |i| {
                    exe_unit_tests.root_module.addImport(
                        import.name,
                        i.module(import.name),
                    );
                }
            }

            const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
            test_step.dependOn(&run_exe_unit_tests.step);
        }
    }
}
