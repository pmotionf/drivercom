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
    .full_text = "Set hall sensor ignore distance.",
    .usage_summary = "[--file] <sensor> <forward/backward/all> <distance>",

    .option_docs = .{
        .file = "set hall sensor ignore distance in configuration file",
    },
};

pub fn help(_: @This()) !void {
    const stdout = std.io.getStdOut().writer();
    try args.printHelp(
        @This(),
        "drivercom [--port] [--timeout] config.set.hall_sensor.ignore",
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
            "sensor ID, direction, and distance must be provided",
            .{},
        );
        return;
    }

    var sensors_buf: [drivercom.Config.MAX_AXES * 2]u3 = undefined;
    const sensors = try command.parseSensor(cli.positionals[0], &sensors_buf);
    const dir = try command.parseDirection(cli.positionals[1]);
    const dist = try std.fmt.parseFloat(f32, cli.positionals[2]);

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

        for (sensors) |sensor| {
            switch (dir) {
                'b' => {
                    config.hall_sensors[sensor].ignore_distance.backward =
                        if (dist > 0.0) -dist else dist;
                },
                'f' => {
                    config.hall_sensors[sensor].ignore_distance.forward =
                        if (dist < 0.0) -dist else dist;
                },
                'a' => {
                    config.hall_sensors[sensor].ignore_distance.backward =
                        if (dist > 0.0) -dist else dist;
                    config.hall_sensors[sensor].ignore_distance.forward =
                        if (dist < 0.0) -dist else dist;
                },
                else => unreachable,
            }
        }

        try file.seekTo(0);
        try std.json.stringify(
            config,
            .{ .whitespace = .indent_2 },
            file.writer(),
        );
    }

    if (cli.port) |_| {
        var sequence: u16 = 0;

        for (sensors) |sensor| {
            if (dir == 'b' or dir == 'a') {
                const msg = drivercom.Message.init(
                    .set_ignore_distance_backward,
                    sequence,
                    .{
                        .sensor = sensor,
                        .distance = if (dist > 0.0) -dist else dist,
                    },
                );
                try command.sendMessage(&msg);
                sequence += 1;
            }
            if (dir == 'f' or dir == 'a') {
                const msg = drivercom.Message.init(
                    .set_ignore_distance_forward,
                    sequence,
                    .{
                        .sensor = sensor,
                        .distance = if (dist < 0.0) -dist else dist,
                    },
                );
                try command.sendMessage(&msg);
                sequence += 1;
            }
        }

        const msg = drivercom.Message.init(.save_config, sequence, {});
        try command.sendMessage(&msg);
    }
}
