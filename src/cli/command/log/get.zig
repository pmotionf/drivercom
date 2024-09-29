const std = @import("std");
const cli = @import("../../../cli.zig");
const command = @import("../../command.zig");
const args = @import("args");
const drivercom = @import("drivercom");

file: ?[]const u8 = null,

pub const shorthands = .{
    .f = "file",
};

pub const meta = .{
    .full_text = "Retrieve driver logs.",
    .usage_summary = "[--file]",

    .option_docs = .{
        .file = "save retrieved driver logs to file",
    },
};

pub fn help(_: @This()) !void {
    const stdout = std.io.getStdOut().writer();
    try args.printHelp(
        @This(),
        "drivercom [--port] [--timeout] log.get",
        stdout,
    );
}

pub fn execute(self: @This()) !void {
    if (cli.port == null) {
        std.log.err("serial port must be provided", .{});
        return;
    }
    var params: drivercom.Log = undefined;

    var cycles_completed: u32 = 0;
    var sequence: u16 = 0;
    var msg = drivercom.Message.init(
        .log_status,
        sequence,
        .{ .status = .{ .value = .stopped }, .cycles_completed = 0 },
    );
    while (true) {
        try command.sendMessage(&msg);
        const req = try command.readMessage();
        if (req.kind == .log_status and req.sequence == sequence) {
            const payload = req.payload(.log_status);
            switch (payload.status.value) {
                .started => {
                    std.log.err("logging in progress", .{});
                    return;
                },
                .waiting => {
                    std.log.err("log waiting for start conditions", .{});
                    return;
                },
                .invalid => {
                    std.log.err("invalid log parameters", .{});
                    return;
                },
                .stopped => {
                    cycles_completed = payload.cycles_completed;
                    break;
                },
            }
        }
    }

    sequence += 1;
    msg = drivercom.Message.init(.log_get_conf, sequence, {});
    while (true) {
        try command.sendMessage(&msg);
        const req = try command.readMessage();
        if (req.kind == .log_set_conf and req.sequence == sequence) {
            const payload = req.payload(.log_set_conf);
            params.config = payload;
            break;
        }
    }

    sequence += 1;
    msg = drivercom.Message.init(.log_get_axis, sequence, {});
    while (true) {
        try command.sendMessage(&msg);
        const req = try command.readMessage();
        if (req.kind == .log_set_axis and req.sequence == sequence) {
            const payload = req.payload(.log_set_axis);
            params.axes[0] = payload.axis1;
            params.axes[1] = payload.axis2;
            params.axes[2] = payload.axis3;
            break;
        }
    }

    sequence += 1;
    msg = drivercom.Message.init(.log_get_vehicles, sequence, {});
    while (true) {
        try command.sendMessage(&msg);
        const req = try command.readMessage();
        if (req.kind == .log_set_vehicles and req.sequence == sequence) {
            const payload = req.payload(.log_set_vehicles);
            for (0..4) |i| {
                params.vehicles[i] = @intCast(payload[i]);
            }
            break;
        }
    }

    sequence += 1;
    msg = drivercom.Message.init(.log_get_sensors, sequence, {});
    while (true) {
        try command.sendMessage(&msg);
        const req = try command.readMessage();
        if (req.kind == .log_set_sensors and req.sequence == sequence) {
            const payload = req.payload(.log_set_sensors);
            params.hall_sensors[0] = payload.sensor1;
            params.hall_sensors[1] = payload.sensor2;
            params.hall_sensors[2] = payload.sensor3;
            params.hall_sensors[3] = payload.sensor4;
            params.hall_sensors[4] = payload.sensor5;
            params.hall_sensors[5] = payload.sensor6;
            break;
        }
    }

    const file: ?std.fs.File = if (self.file) |f|
        try std.fs.cwd().createFile(f, .{})
    else
        null;
    defer if (file) |f| f.close();

    const flags: u32 = @bitCast(params.config);
    const tags = @typeInfo(drivercom.Log.Tag).@"enum".fields;
    const stdout = std.io.getStdOut().writer();
    inline for (0..tags.len) |i| {
        if ((flags >> @intCast(i)) & 1 == 1) {
            const start_sensor: usize =
                comptime @intFromEnum(drivercom.Log.Tag.sensor_alarm);
            const end_sensor =
                start_sensor + @bitSizeOf(@TypeOf(params.config.sensor));

            if (i >= start_sensor and i < end_sensor) {
                for (params.hall_sensors, 1..) |sensor, id| {
                    if (!sensor) continue;
                    if (file) |f| {
                        try f.writer().print(
                            "{d}_{s},",
                            .{ id, tags[i].name },
                        );
                    }
                    try stdout.print(
                        "{d}_{s},",
                        .{ id, tags[i].name },
                    );
                }
            } else {
                if (file) |f| {
                    try f.writeAll(tags[i].name ++ ",");
                }
                try stdout.writeAll(tags[i].name ++ ",");
            }
        }
    }
    if (file) |f| {
        try f.writer().writeByte('\n');
    }
    try stdout.writeByte('\n');

    for (0..cycles_completed) |i| {
        if (params.config.driver.cycle) {
            sequence += 1;
            msg = drivercom.Message.init(.log_get, sequence, .{
                .cycle = @intCast(i),
                .id = 0,
                .tag = .{
                    .value = .driver_cycle,
                },
            });
            retry: while (true) {
                try command.sendMessage(&msg);
                const req = try command.readMessage();
                if (req.kind == .log_get and req.sequence == sequence) {
                    const payload = req.payload(.log_get);
                    std.log.debug("{any}", .{payload});
                    if (payload.tag.value == .driver_cycle) {
                        const cycle = payload.cycle & 0xFFFF;
                        if (file) |f| {
                            try f.writer().print("{d},", .{cycle});
                        }
                        try stdout.print("{d},", .{cycle});
                    }
                    break :retry;
                }
            }
        }
        if (params.config.driver.cycle_time) {
            sequence += 1;
            msg = drivercom.Message.init(.log_get, sequence, .{
                .cycle = @intCast(i),
                .id = 0,
                .tag = .{
                    .value = .driver_cycle_time,
                },
            });
            retry: while (true) {
                try command.sendMessage(&msg);
                const req = try command.readMessage();
                if (req.kind == .log_get and req.sequence == sequence) {
                    const payload = req.payload(.log_get);
                    const cycle_time = payload.cycle & 0xFFFF;
                    if (file) |f| {
                        try f.writer().print("{d},", .{cycle_time});
                    }
                    try stdout.print("{d},", .{cycle_time});
                    break :retry;
                }
            }
        }
        if (params.config.driver.vdc) {
            sequence += 1;
            msg = drivercom.Message.init(.log_get, sequence, .{
                .cycle = @intCast(i),
                .id = 0,
                .tag = .{
                    .value = .driver_vdc,
                },
            });
            retry: while (true) {
                try command.sendMessage(&msg);
                const req = try command.readMessage();
                if (req.kind == .log_get and req.sequence == sequence) {
                    const payload = req.payload(.log_get);
                    var vdc: f32 = @floatFromInt(payload.cycle);
                    vdc /= 100.0;
                    if (file) |f| {
                        try f.writer().print("{d:.2},", .{vdc});
                    }
                    try stdout.print("{d:.2},", .{vdc});
                    break :retry;
                }
            }
        }

        if (params.config.sensor.alarm) {
            for (params.hall_sensors, 1..) |sensor, id| {
                if (!sensor) continue;
                sequence += 1;
                msg = drivercom.Message.init(.log_get, sequence, .{
                    .cycle = @intCast(i),
                    .id = @intCast(id),
                    .tag = .{
                        .value = .sensor_alarm,
                    },
                });
                retry: while (true) {
                    try command.sendMessage(&msg);
                    const req = try command.readMessage();
                    if (req.kind == .log_get and req.sequence == sequence) {
                        const payload = req.payload(.log_get);
                        const alarm: bool = payload.cycle != 0;
                        if (file) |f| {
                            try f.writer().print("{},", .{alarm});
                        }
                        try stdout.print("{},", .{alarm});
                        break :retry;
                    }
                }
            }
        }

        if (params.config.sensor.angle) {
            for (params.hall_sensors, 1..) |sensor, id| {
                if (!sensor) continue;
                sequence += 1;
                msg = drivercom.Message.init(.log_get, sequence, .{
                    .cycle = @intCast(i),
                    .id = @intCast(id),
                    .tag = .{
                        .value = .sensor_angle,
                    },
                });
                retry: while (true) {
                    try command.sendMessage(&msg);
                    const req = try command.readMessage();
                    if (req.kind == .log_get and req.sequence == sequence) {
                        const payload = req.payload(.log_get);
                        const angle: f32 = @bitCast(payload.cycle);
                        if (file) |f| {
                            try f.writer().print("{},", .{angle});
                        }
                        try stdout.print("{},", .{angle});
                        break :retry;
                    }
                }
            }
        }

        if (params.config.sensor.unwrapped_angle) {
            for (params.hall_sensors, 1..) |sensor, id| {
                if (!sensor) continue;
                sequence += 1;
                msg = drivercom.Message.init(.log_get, sequence, .{
                    .cycle = @intCast(i),
                    .id = @intCast(id),
                    .tag = .{
                        .value = .sensor_unwrapped_angle,
                    },
                });
                retry: while (true) {
                    try command.sendMessage(&msg);
                    const req = try command.readMessage();
                    if (req.kind == .log_get and req.sequence == sequence) {
                        const payload = req.payload(.log_get);
                        const angle: f32 = @bitCast(payload.cycle);
                        if (file) |f| {
                            try f.writer().print("{},", .{angle});
                        }
                        try stdout.print("{},", .{angle});
                        break :retry;
                    }
                }
            }
        }

        if (params.config.sensor.distance) {
            for (params.hall_sensors, 1..) |sensor, id| {
                if (!sensor) continue;
                sequence += 1;
                msg = drivercom.Message.init(.log_get, sequence, .{
                    .cycle = @intCast(i),
                    .id = @intCast(id),
                    .tag = .{
                        .value = .sensor_distance,
                    },
                });
                retry: while (true) {
                    try command.sendMessage(&msg);
                    const req = try command.readMessage();
                    if (req.kind == .log_get and req.sequence == sequence) {
                        const payload = req.payload(.log_get);
                        const distance: f32 = @bitCast(payload.cycle);
                        if (file) |f| {
                            try f.writer().print("{},", .{distance});
                        }
                        try stdout.print("{},", .{distance});
                        break :retry;
                    }
                }
            }
        }

        try stdout.writeAll("\n");
        if (file) |f| {
            try f.writeAll("\n");
        }
    }
}
