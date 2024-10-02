const std = @import("std");
const cli = @import("../../../cli.zig");
const command = @import("../../command.zig");
const args = @import("args");
const drivercom = @import("drivercom");
const Log = drivercom.Log;

file: ?[]const u8 = null,
chunk: u32 = 1000,

pub const shorthands = .{
    .f = "file",
    .c = "chunk",
};

pub const meta = .{
    .full_text = "Retrieve driver logs.",
    .usage_summary = "[--file] [--chunk]",

    .option_docs = .{
        .file = "save retrieved driver logs to file",
        .chunk = "number of cycles to retrieve per log data chunk",
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
    var params: Log = undefined;

    var cycles_completed: u32 = 0;
    var sequence: u16 = 0;
    {
        const payload = try command.transceiveMessage(
            .log_status,
            .log_status,
            .{
                .sequence = sequence,
                .payload = .{ .status = .stopped, .cycles_completed = 0 },
            },
        );
        switch (payload.status) {
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
            },
        }
    }
    {
        sequence += 1;
        const payload = try command.transceiveMessage(
            .log_get_conf,
            .log_set_conf,
            .{ .sequence = sequence, .payload = {} },
        );
        params.config = payload;
    }
    {
        sequence += 1;
        const payload = try command.transceiveMessage(
            .log_get_axis,
            .log_set_axis,
            .{ .sequence = sequence, .payload = {} },
        );
        params.axes[0] = payload.axis1;
        params.axes[1] = payload.axis2;
        params.axes[2] = payload.axis3;
    }
    {
        sequence += 1;
        const payload = try command.transceiveMessage(
            .log_get_vehicles,
            .log_set_vehicles,
            .{ .sequence = sequence, .payload = {} },
        );
        for (0..4) |i| params.vehicles[i] = @intCast(payload[i]);
    }
    {
        sequence += 1;
        const payload = try command.transceiveMessage(
            .log_get_sensors,
            .log_set_sensors,
            .{ .sequence = sequence, .payload = {} },
        );
        params.hall_sensors[0] = payload.sensor1;
        params.hall_sensors[1] = payload.sensor2;
        params.hall_sensors[2] = payload.sensor3;
        params.hall_sensors[3] = payload.sensor4;
        params.hall_sensors[4] = payload.sensor5;
        params.hall_sensors[5] = payload.sensor6;
    }

    const file: ?std.fs.File = if (self.file) |f|
        try std.fs.cwd().createFile(f, .{})
    else
        null;
    defer if (file) |f| f.close();

    const flags: u32 = @bitCast(params.config);
    const tags = @typeInfo(Log.Tag).@"enum".fields;
    const stdout = std.io.getStdOut().writer();
    var total_tag_bytes: usize = 0;
    inline for (0..tags.len) |i| {
        if ((flags >> @intCast(i)) & 1 == 1) {
            const tag: Log.Tag = @enumFromInt(i);
            const tag_size = Log.tagSize(tag);

            switch (Log.tagKind(tag)) {
                .none => {
                    total_tag_bytes += tag_size;
                    if (file) |f| {
                        try f.writeAll(tags[i].name ++ ",");
                    }
                    try stdout.writeAll(tags[i].name ++ ",");
                },
                .axis => {
                    for (params.axes, 1..) |axis, id| {
                        if (!axis) continue;
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
                        total_tag_bytes += tag_size;
                    }
                },
                .sensor => {
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
                        total_tag_bytes += tag_size;
                    }
                },
                .vehicle => {
                    for (params.vehicles) |id| {
                        if (id == 0) continue;
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
                        total_tag_bytes += tag_size;
                    }
                },
            }
        }
    }
    if (file) |f| {
        try f.writer().writeByte('\n');
    }
    try stdout.writeByte('\n');

    const reader = cli.port.?.reader();

    // Split into chunks.
    const max_chunk_size = self.chunk;
    var buf = try std.heap.page_allocator.alloc(
        u8,
        max_chunk_size * total_tag_bytes,
    );
    defer std.heap.page_allocator.free(buf);

    var cycle: u32 = 0;
    while (cycle < cycles_completed) {
        var chunk_size: u32 = max_chunk_size;
        chunk_size = @min(max_chunk_size, cycles_completed - cycle);
        defer cycle += chunk_size;

        var buf_ind: usize = 0;

        const config: u32 = @bitCast(params.config);
        const ti = @typeInfo(Log.Tag).@"enum";
        for (0..ti.fields.len) |i| {
            if ((config >> @intCast(i)) & 1 == 0) continue;
            const tag: Log.Tag = @enumFromInt(i);
            const tag_size = Log.tagSize(tag);
            const chunk_byte_size = chunk_size * tag_size;
            switch (Log.tagKind(tag)) {
                .none => {
                    sequence += 1;
                    const msg = drivercom.Message.init(.log_get, sequence, .{
                        .cycle = @intCast(cycle),
                        .data = tag,
                        .id = 0,
                        .cycles = chunk_size,
                    });
                    try command.sendMessage(&msg);

                    var rcv_size: usize = 0;
                    while (rcv_size < chunk_byte_size) {
                        const start = buf_ind + rcv_size;
                        const len = chunk_byte_size - rcv_size;
                        rcv_size += try reader.readAll(buf[start..][0..len]);
                    }
                    buf_ind += chunk_byte_size;
                },
                .axis => {
                    for (params.axes, 1..) |axis, id| {
                        if (!axis) continue;
                        sequence += 1;
                        const msg = drivercom.Message.init(
                            .log_get,
                            sequence,
                            .{
                                .cycle = @intCast(cycle),
                                .data = tag,
                                .id = @intCast(id),
                                .cycles = chunk_size,
                            },
                        );
                        try command.sendMessage(&msg);

                        var rcv_size: usize = 0;
                        while (rcv_size < chunk_byte_size) {
                            const start = buf_ind + rcv_size;
                            const len = chunk_byte_size - rcv_size;
                            rcv_size += try reader.readAll(
                                buf[start..][0..len],
                            );
                        }
                        buf_ind += chunk_byte_size;
                    }
                },
                .sensor => {
                    for (params.hall_sensors, 1..) |sensor, id| {
                        if (!sensor) continue;
                        sequence += 1;
                        const msg = drivercom.Message.init(
                            .log_get,
                            sequence,
                            .{
                                .cycle = @intCast(cycle),
                                .data = tag,
                                .id = @intCast(id),
                                .cycles = chunk_size,
                            },
                        );
                        try command.sendMessage(&msg);

                        var rcv_size: usize = 0;
                        while (rcv_size < chunk_byte_size) {
                            const start = buf_ind + rcv_size;
                            const len = chunk_byte_size - rcv_size;
                            rcv_size += try reader.readAll(
                                buf[start..][0..len],
                            );
                        }
                        buf_ind += chunk_byte_size;
                    }
                },
                .vehicle => {},
            }
        }

        for (0..chunk_size) |i| {
            buf_ind = 0;

            inline for (0..ti.fields.len) |j| {
                if ((config >> @intCast(j)) & 1 == 1) {
                    const tag: Log.Tag = @enumFromInt(j);
                    const tag_size: u3 = Log.tagSize(tag);
                    const chunk_byte_size = chunk_size * tag_size;
                    const ValueType: type = Log.TagType(tag);

                    switch (Log.tagKind(tag)) {
                        .none => {
                            const chunk_offset = buf_ind + i * tag_size;
                            const value: ValueType = Log.tagParse(
                                tag,
                                buf[chunk_offset..][0..tag_size],
                            );
                            try writeValue(file, value);
                            buf_ind += chunk_byte_size;
                        },
                        .axis => {
                            for (params.axes) |axis| {
                                if (!axis) continue;
                                const chunk_offset = buf_ind + i * tag_size;
                                const value: ValueType = Log.tagParse(
                                    tag,
                                    buf[chunk_offset..][0..tag_size],
                                );
                                try writeValue(file, value);
                                buf_ind += chunk_size * tag_size;
                            }
                        },
                        .sensor => {
                            for (params.hall_sensors) |sensor| {
                                if (!sensor) continue;
                                const chunk_offset = buf_ind + i * tag_size;
                                const value: ValueType = Log.tagParse(
                                    tag,
                                    buf[chunk_offset..][0..tag_size],
                                );
                                try writeValue(file, value);
                                buf_ind += chunk_size * tag_size;
                            }
                        },
                        .vehicle => {},
                    }
                }
            }
            if (file) |f| {
                try f.writer().writeByte('\n');
            }
            try stdout.writeByte('\n');
        }
    }
}

fn writeValue(file: ?std.fs.File, value: anytype) !void {
    const stdout = std.io.getStdOut().writer();
    if (comptime @TypeOf(value) == f32) {
        if (file) |f| {
            try f.writer().print("{d},", .{value});
        }
        try stdout.print("{d},", .{value});
    } else {
        if (file) |f| {
            try f.writer().print("{},", .{value});
        }
        try stdout.print("{},", .{value});
    }
}
