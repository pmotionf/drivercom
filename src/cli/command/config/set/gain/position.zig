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
    .full_text = "Set driver position gain.",
    .usage_summary = "[--file] <axis> <denominator>",

    .option_docs = .{
        .file = "set position gain in configuration file",
    },
};

pub fn help(_: @This()) !void {
    const stdout = std.io.getStdOut().writer();
    try args.printHelp(
        @This(),
        "drivercom [--port] [--timeout] config.set.gain.position",
        stdout,
    );
}

pub fn execute(self: @This()) !void {
    if (cli.port == null and self.file == null) {
        std.log.err("serial port or file must be provided", .{});
        return;
    }

    if (cli.positionals.len != 2) {
        std.log.err(
            "axis and denominator must be provided",
            .{},
        );
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

            axis.position_gain = config.calcPositionGain(
                axis_index,
                denominator,
            );
        }

        try file.seekTo(0);
        try std.json.stringify(
            config,
            .{ .whitespace = .indent_2 },
            file.writer(),
        );
    }

    if (cli.port) |_| {
        var config: drivercom.Config = undefined;

        var sequence: u16 = 0;
        for (axes) |axis_index| {
            sequence += 1;
            var msg = drivercom.Message.init(
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
            msg = drivercom.Message.init(
                .get_velocity_gain_denominator,
                sequence,
                axis_index,
            );
            while (true) {
                try command.sendMessage(&msg);
                const rsp = try command.readMessage();
                if (rsp.kind == .set_velocity_gain_denominator and
                    rsp.sequence == sequence)
                {
                    const payload = rsp.payload(
                        .set_velocity_gain_denominator,
                    );
                    config.axes[axis_index].velocity_gain.denominator =
                        payload.denominator;
                    break;
                }
            }
        }

        for (axes) |axis_index| {
            const axis = &config.axes[axis_index];
            axis.position_gain = config.calcPositionGain(
                axis_index,
                denominator,
            );
        }

        for (axes) |axis_index| {
            const axis = &config.axes[axis_index];
            sequence += 1;
            var msg = drivercom.Message.init(
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
