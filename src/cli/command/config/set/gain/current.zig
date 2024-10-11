const std = @import("std");
const command = @import("../../../../command.zig");
const cli = @import("../../../../../cli.zig");
const args = @import("args");
const drivercom = @import("drivercom");

file: ?[]const u8 = null,

pub const shorthands = .{
    .f = "file",
};

pub const meta = .{
    .full_text = "Set driver current gain.",
    .usage_summary = "[--file] <axis> <denominator>",

    .option_docs = .{
        .file = "set current gain in configuration file",
    },
};

pub fn help(_: @This()) !void {
    const stdout = std.io.getStdOut().writer();
    try args.printHelp(
        @This(),
        "drivercom [--port] [--timeout] config.set.gain.current",
        stdout,
    );
}

pub fn execute(self: @This()) !void {
    if (cli.port == null and self.file == null) {
        std.log.err("serial port or file must be provided", .{});
        return;
    }

    if (cli.positionals.len != 2) {
        std.log.err("axis and denominator must be provided", .{});
        return;
    }

    const denominator =
        try std.fmt.parseUnsigned(u32, cli.positionals[1], 10);

    var axes_buf: [3]u2 = undefined;
    const axes = try command.parseAxis(cli.positionals[0], &axes_buf);

    if (self.file) |name| {
        var file = try std.fs.cwd().openFile(name, .{ .mode = .read_write });
        defer file.close();

        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        const file_str = try file.readToEndAlloc(allocator, 1_024_000_000);
        defer allocator.free(file_str);
        var untyped = try std.json.parseFromSlice(
            drivercom.Config,
            allocator,
            file_str,
            .{},
        );
        defer untyped.deinit();
        var config = untyped.value;

        for (axes) |axis_index| {
            const axis = &config.axes[axis_index];
            axis.current_gain = config.calcCurrentGain(
                axis_index,
                denominator,
            );
            axis.velocity_gain = config.calcVelocityGain(
                axis_index,
                axis.velocity_gain.denominator,
                axis.velocity_gain.denominator_pi,
            );
            axis.position_gain = config.calcPositionGain(
                axis_index,
                axis.position_gain.denominator,
            );
        }

        try command.writeConfigFile(file, config);
    }

    if (cli.port) |_| {
        var config: drivercom.Config = undefined;

        var sequence: u16 = 0;
        {
            const payload = try command.transceiveMessage(
                .get_magnet,
                .set_magnet,
                .{ .sequence = sequence, .payload = {} },
            );
            config.magnet.pitch = payload.pitch;
            config.magnet.length = payload.length;
        }
        {
            sequence += 1;
            const payload = try command.transceiveMessage(
                .get_vehicle_mass,
                .set_vehicle_mass,
                .{ .sequence = sequence, .payload = {} },
            );
            config.vehicle_mass = payload;
        }
        {
            sequence += 1;
            const payload = try command.transceiveMessage(
                .get_ls,
                .set_ls,
                .{ .sequence = sequence, .payload = {} },
            );
            config.motor.ls = payload;
        }
        {
            sequence += 1;
            const payload = try command.transceiveMessage(
                .get_rs,
                .set_rs,
                .{ .sequence = sequence, .payload = {} },
            );
            config.motor.rs = payload;
        }
        {
            sequence += 1;
            const payload = try command.transceiveMessage(
                .get_kf,
                .set_kf,
                .{ .sequence = sequence, .payload = {} },
            );
            config.motor.kf = payload;
        }

        for (axes) |i| {
            {
                sequence += 1;
                const payload = try command.transceiveMessage(
                    .get_velocity_gain_denominator,
                    .set_velocity_gain_denominator,
                    .{ .sequence = sequence, .payload = i },
                );
                config.axes[i].velocity_gain.denominator = payload.denominator;
            }
            {
                sequence += 1;
                const payload = try command.transceiveMessage(
                    .get_velocity_gain_denominator_pi,
                    .set_velocity_gain_denominator_pi,
                    .{ .sequence = sequence, .payload = i },
                );
                config.axes[i].velocity_gain.denominator_pi =
                    payload.denominator;
            }
            {
                sequence += 1;
                const payload = try command.transceiveMessage(
                    .get_position_gain_denominator,
                    .set_position_gain_denominator,
                    .{ .sequence = sequence, .payload = i },
                );
                config.axes[i].position_gain.denominator = payload.denominator;
            }
        }

        for (axes) |axis_index| {
            const axis = &config.axes[axis_index];
            axis.current_gain = config.calcCurrentGain(
                axis_index,
                denominator,
            );
            axis.velocity_gain = config.calcVelocityGain(
                axis_index,
                axis.velocity_gain.denominator,
                axis.velocity_gain.denominator_pi,
            );
            axis.position_gain = config.calcPositionGain(
                axis_index,
                axis.position_gain.denominator,
            );
        }

        for (axes) |axis_index| {
            const axis = &config.axes[axis_index];
            sequence += 1;
            var msg = drivercom.Message.init(
                .set_current_gain_p,
                sequence,
                .{ .axis = axis_index, .p = axis.current_gain.p },
            );
            try command.sendMessage(&msg);

            sequence += 1;
            msg = drivercom.Message.init(
                .set_current_gain_i,
                sequence,
                .{ .axis = axis_index, .i = axis.current_gain.i },
            );
            try command.sendMessage(&msg);

            sequence += 1;
            msg = drivercom.Message.init(
                .set_current_gain_denominator,
                sequence,
                .{
                    .axis = axis_index,
                    .denominator = axis.current_gain.denominator,
                },
            );
            try command.sendMessage(&msg);

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
