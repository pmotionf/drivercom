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
    .full_text = "Retrieve PMF Smart Driver logs.",
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

    const file: ?std.fs.File = if (self.file) |f|
        try std.fs.cwd().createFile(f, .{})
    else
        null;
    defer if (file) |f| f.close();

    if (file) |f| {
        if (params.config.cycle) {
            try f.writeAll("cycle,");
        }
        if (params.config.cycle_time) {
            try f.writeAll("cycle_time,");
        }
        if (params.config.vdc) {
            try f.writeAll("vdc,");
        }

        try f.writeAll("\n");
    }

    const stdout = std.io.getStdOut().writer();

    if (params.config.cycle) {
        try stdout.writeAll("cycle,");
    }
    if (params.config.cycle_time) {
        try stdout.writeAll("cycle_time,");
    }
    if (params.config.vdc) {
        try stdout.writeAll("vdc,");
    }
    try stdout.writeAll("\n");

    for (0..cycles_completed) |i| {
        if (params.config.cycle) {
            sequence += 1;
            msg = drivercom.Message.init(.log_get, sequence, .{
                .cycle = @intCast(i),
                .axis = 0,
                .tag = .{
                    .value = .cycle,
                },
            });
            retry: while (true) {
                try command.sendMessage(&msg);
                const req = try command.readMessage();
                if (req.kind == .log_get and req.sequence == sequence) {
                    const payload = req.payload(.log_get);
                    std.log.debug("{any}", .{payload});
                    if (payload.tag.value == .cycle) {
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
        if (params.config.cycle_time) {
            sequence += 1;
            msg = drivercom.Message.init(.log_get, sequence, .{
                .cycle = @intCast(i),
                .axis = 0,
                .tag = .{
                    .value = .cycle_time,
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
        if (params.config.vdc) {
            sequence += 1;
            msg = drivercom.Message.init(.log_get, sequence, .{
                .cycle = @intCast(i),
                .axis = 0,
                .tag = .{
                    .value = .vdc,
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

        try stdout.writeAll("\n");
        if (file) |f| {
            try f.writeAll("\n");
        }
    }
}
