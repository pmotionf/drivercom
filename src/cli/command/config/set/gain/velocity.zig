const std = @import("std");
const command = @import("../../../../command.zig");
const cli = @import("../../../../../cli.zig");
const args = @import("args");
const drivercom = @import("drivercom");
const yaml = @import("yaml");

file: ?[]const u8 = null,

pub const shorthands = .{
    .f = "file",
};

pub const meta = .{
    .full_text = "Set driver velocity gain.",
    .usage_summary = "[--file] <axis> <denominator> <denominator_pi>",

    .option_docs = .{
        .file = "set velocity gain in configuration file",
    },
};

pub fn help(_: @This()) !void {
    const stdout = std.io.getStdOut().writer();
    try args.printHelp(
        @This(),
        "drivercom [--port] [--timeout] config.set.gain.velocity",
        stdout,
    );
}

pub fn execute(self: @This()) !void {
    if (cli.port == null and self.file == null) {
        std.log.err("serial port or file must be provided", .{});
        return;
    }

    if (cli.positionals.len != 3) {
        std.log.err(
            "axis, denominator, and denominator_pi must be provided",
            .{},
        );
        return;
    }

    const denominator = try std.fmt.parseUnsigned(u32, cli.positionals[1], 10);
    const denominator_pi =
        try std.fmt.parseUnsigned(u32, cli.positionals[2], 10);

    var axes_buf: [3]u16 = undefined;
    var axes: []u16 = &.{};
    var axes_str = std.mem.splitScalar(u8, cli.positionals[0], ',');
    while (axes_str.next()) |axis_str| {
        const axis_id = try std.fmt.parseUnsigned(u16, axis_str, 10);
        if (axis_id == 0 or axis_id > drivercom.Config.MAX_AXES) {
            std.log.err(
                "axis {} must be between 1 and {}",
                .{ axis_id, drivercom.Config.MAX_AXES },
            );
            return;
        }
        axes_buf[axes.len] = axis_id - 1;
        axes = axes_buf[0 .. axes.len + 1];
    }

    if (self.file) |name| {
        var file = try std.fs.cwd().openFile(name, .{ .mode = .read_write });
        defer file.close();

        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        const file_str = try file.readToEndAlloc(allocator, 1_024_000_000);
        defer allocator.free(file_str);
        var untyped = try yaml.Yaml.load(
            allocator,
            file_str,
        );
        defer untyped.deinit();
        var config = try untyped.parse(drivercom.Config);

        for (axes) |axis_index| {
            const axis = &config.axes[axis_index];

            axis.velocity_gain = config.calcVelocityGain(
                axis_index,
                denominator,
                denominator_pi,
            );
            axis.position_gain = config.calcPositionGain(
                axis_index,
                axis.position_gain.denominator,
            );
        }

        try file.seekTo(0);
        try yaml.stringify(allocator, config, file.writer());
    }

    if (cli.port) |_| {
        var config: drivercom.Config = undefined;

        var sequence: u16 = 0;
        var msg = drivercom.Message.init(.get_magnet, sequence, {});
        while (true) {
            try command.sendMessage(&msg);
            const rsp = try command.readMessage();
            if (rsp.kind == .set_magnet and rsp.sequence == sequence) {
                const payload = rsp.payload(.set_magnet);
                config.magnet.pitch = payload.pitch;
                config.magnet.length = payload.length;
                break;
            }
        }

        sequence += 1;
        msg = drivercom.Message.init(.get_vehicle_mass, sequence, {});
        while (true) {
            try command.sendMessage(&msg);
            const rsp = try command.readMessage();
            if (rsp.kind == .set_vehicle_mass and rsp.sequence == sequence) {
                const payload = rsp.payload(.set_vehicle_mass);
                config.vehicle_mass = payload;
                break;
            }
        }

        for (axes) |axis_index| {
            sequence += 1;
            msg = drivercom.Message.init(
                .get_current_gain_denominator,
                sequence,
                axis_index,
            );
            while (true) {
                try command.sendMessage(&msg);
                const rsp = try command.readMessage();
                if (rsp.kind == .set_current_gain_denominator and
                    rsp.sequence == sequence)
                {
                    const payload = rsp.payload(.set_current_gain_denominator);
                    config.axes[axis_index].current_gain.denominator =
                        payload.denominator;
                    break;
                }
            }

            sequence += 1;
            msg = drivercom.Message.init(.get_kf, sequence, axis_index);
            while (true) {
                try command.sendMessage(&msg);
                const rsp = try command.readMessage();
                if (rsp.kind == .set_kf and rsp.sequence == sequence) {
                    const payload = rsp.payload(.set_kf);
                    if (payload.axis != axis_index) continue;
                    config.axes[axis_index].kf = payload.kf;
                    break;
                }
            }

            sequence += 1;
            msg = drivercom.Message.init(
                .get_position_gain_denominator,
                sequence,
                axis_index,
            );
            while (true) {
                try command.sendMessage(&msg);
                const rsp = try command.readMessage();
                if (rsp.kind == .set_position_gain_denominator and
                    rsp.sequence == sequence)
                {
                    const payload = rsp.payload(
                        .set_position_gain_denominator,
                    );
                    if (payload.axis != axis_index) continue;
                    config.axes[axis_index].position_gain.denominator =
                        payload.denominator;
                    break;
                }
            }
        }

        for (axes) |axis_index| {
            const axis = &config.axes[axis_index];
            axis.velocity_gain = config.calcVelocityGain(
                axis_index,
                denominator,
                denominator_pi,
            );
            axis.position_gain = config.calcPositionGain(
                axis_index,
                axis.position_gain.denominator,
            );
        }

        for (axes) |axis_index| {
            const axis = &config.axes[axis_index];
            sequence += 1;
            msg = drivercom.Message.init(
                .set_velocity_gain_p,
                sequence,
                .{ .axis = axis_index, .p = axis.velocity_gain.p },
            );
            try command.sendMessage(&msg);

            sequence += 1;
            msg = drivercom.Message.init(
                .set_velocity_gain_i,
                sequence,
                .{ .axis = axis_index, .i = axis.velocity_gain.i },
            );
            try command.sendMessage(&msg);

            sequence += 1;
            msg = drivercom.Message.init(
                .set_velocity_gain_denominator,
                sequence,
                .{
                    .axis = axis_index,
                    .denominator = axis.velocity_gain.denominator,
                },
            );
            try command.sendMessage(&msg);

            sequence += 1;
            msg = drivercom.Message.init(
                .set_velocity_gain_denominator_pi,
                sequence,
                .{
                    .axis = axis_index,
                    .denominator = axis.velocity_gain.denominator_pi,
                },
            );
            try command.sendMessage(&msg);

            sequence += 1;
            msg = drivercom.Message.init(
                .set_position_gain_p,
                sequence,
                .{ .axis = axis_index, .p = axis.position_gain.p },
            );
            try command.sendMessage(&msg);

            sequence += 1;
            msg = drivercom.Message.init(
                .set_position_gain_denominator,
                sequence,
                .{
                    .axis = axis_index,
                    .denominator = axis.position_gain.denominator,
                },
            );
            try command.sendMessage(&msg);

            sequence += 1;
            msg = drivercom.Message.init(.save_config, sequence, {});
            try command.sendMessage(&msg);
        }
    }
}
