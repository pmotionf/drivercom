pub const version = @import("command/version.zig");
pub const firmware = @import("command/firmware.zig");
pub const port = @import("command/port.zig");
pub const config = @import("command/config.zig");
pub const log = @import("command/log.zig");

const builtin = @import("builtin");
const std = @import("std");
const drivercom = @import("drivercom");
const serialport = @import("serialport");
const cli = @import("../cli.zig");

pub fn sendMessage(msg: *const drivercom.Message) !void {
    std.debug.assert(cli.port != null);

    const writer = cli.port.?.writer();
    const reader = cli.port.?.reader();

    var retry: usize = 0;
    while (retry < cli.retry) {
        try cli.port.?.flush(.{ .input = true, .output = true });
        try writer.writeAll(std.mem.asBytes(msg));
        std.log.debug("Wrote message {s}: {any}", .{
            @tagName(msg.kind),
            std.mem.asBytes(msg),
        });

        var timer = try std.time.Timer.start();
        var read_buffer: [16]u8 = undefined;
        var read_size: usize = 0;
        while (timer.read() < std.time.ns_per_ms * cli.timeout) {
            if (try cli.port.?.poll()) {
                read_size += try reader.read(read_buffer[read_size..]);
                if (read_size == 16) break;
                timer.reset();
            }
        } else {
            std.log.err("driver response timed out: {}", .{msg.kind});
            try cli.port.?.flush(.{ .input = true, .output = true });
            retry += 1;
            continue;
        }
        std.debug.assert(read_size == 16);

        var rsp = std.mem.bytesToValue(drivercom.Message, &read_buffer);

        if (rsp.kind != .response or
            rsp.sequence != msg.sequence or
            rsp.bcc != rsp.getBcc())
        {
            std.log.err(
                "received invalid message receipt confirmation: {any}",
                .{rsp},
            );
            try cli.port.?.flush(.{ .input = true, .output = true });
            retry += 1;
            continue;
        }
        break;
    } else {
        std.log.err("all retries failed", .{});
        return error.CommunicationTimeout;
    }
    std.log.debug("Received response for {s}", .{@tagName(msg.kind)});
}

pub fn readMessage() !drivercom.Message {
    std.debug.assert(cli.port != null);

    const reader = cli.port.?.reader();

    var timer = try std.time.Timer.start();
    var read_buffer: [16]u8 = undefined;
    var read_size: usize = 0;
    while (timer.read() < std.time.ns_per_ms * cli.timeout) {
        if (try cli.port.?.poll()) {
            read_size += try reader.read(read_buffer[read_size..]);
            if (read_size == 16) break;
            timer.reset();
        }
    } else {
        std.log.err("wait for driver message timed out", .{});
        return error.CommunicationTimeout;
    }
    std.debug.assert(read_size == 16);

    var req = std.mem.bytesToValue(drivercom.Message, &read_buffer);

    if (req.getBcc() == req.bcc) {
        return req;
    } else {
        try cli.port.?.flush(.{ .input = true });
        std.log.err("corrupt driver message read", .{});
        return error.CommunicationFailure;
    }
}

/// Send and receive one message exchange.
pub fn transceiveMessage(
    comptime send: drivercom.Message.Kind,
    comptime receive: drivercom.Message.Kind,
    options: struct {
        sequence: u16,
        payload: drivercom.Message.PayloadType(send),
        retry: enum(usize) { infinite, once, _ } = .once,
    },
) !drivercom.Message.PayloadType(receive) {
    const msg = drivercom.Message.init(
        send,
        options.sequence,
        options.payload,
    );
    switch (options.retry) {
        .infinite => {
            while (true) {
                try sendMessage(&msg);
                const rsp = readMessage() catch |e| switch (e) {
                    error.CommunicationTimeout => continue,
                    else => return e,
                };

                if (rsp.kind == receive and
                    rsp.sequence == options.sequence)
                {
                    return rsp.payload(receive);
                }
            }
        },
        .once => {
            try sendMessage(&msg);
            const rsp = try readMessage();

            if (rsp.kind == receive and
                rsp.sequence == options.sequence)
            {
                return rsp.payload(receive);
            } else {
                std.log.err(
                    "{s}:{d} expected {s}:{d} but got {s}:{d}",
                    .{
                        @tagName(send),
                        options.sequence,
                        @tagName(receive),
                        options.sequence,
                        @tagName(rsp.kind),
                        rsp.sequence,
                    },
                );
                return error.CommunicationFailure;
            }
        },
        _ => {
            const retry = @intFromEnum(options.retry);
            for (0..retry) |_| {
                try sendMessage(&msg);
                const rsp = readMessage() catch |e| switch (e) {
                    error.CommunicationTimeout => {
                        std.log.err("message read timed out", .{});
                        continue;
                    },
                    else => return e,
                };

                if (rsp.kind == receive and
                    rsp.sequence == options.sequence)
                {
                    return rsp.payload(receive);
                } else {
                    std.log.err(
                        "{s}:{d} expected {s}:{d} but got {s}:{d}",
                        .{
                            @tagName(send),
                            options.sequence,
                            @tagName(receive),
                            options.sequence,
                            @tagName(rsp.kind),
                            rsp.sequence,
                        },
                    );
                }
            } else {
                std.log.err("retry {d}/{d} failed", .{ retry, retry });
                return error.CommunicationFailure;
            }
        },
    }
}

/// Parse CLI axis input into a slice of axis indices.
pub fn parseAxis(str: []const u8, axes_buf: []u2) ![]u2 {
    std.debug.assert(axes_buf.len >= drivercom.Config.MAX_AXES);
    var axes: []u2 = &.{};

    var axes_str = std.mem.splitScalar(u8, str, ',');
    while (axes_str.next()) |axis_str| {
        if (axis_str.len == 0) continue;
        const axis_id = try std.fmt.parseUnsigned(u16, axis_str, 10);
        if (axis_id == 0 or axis_id > drivercom.Config.MAX_AXES) {
            std.log.err(
                "axis {} must be between 1 and {}",
                .{ axis_id, drivercom.Config.MAX_AXES },
            );
            return error.InvalidAxis;
        }
        axes_buf[axes.len] = @intCast(axis_id - 1);
        axes = axes_buf[0 .. axes.len + 1];
    }

    return axes;
}

/// Parse CLI sensors input into a slice of sensor indices.
pub fn parseSensor(str: []const u8, sensor_buf: []u3) ![]u3 {
    std.debug.assert(sensor_buf.len >= drivercom.Config.MAX_AXES * 2);
    var sensors: []u3 = &.{};

    var sensors_str = std.mem.splitScalar(u8, str, ',');
    while (sensors_str.next()) |sensor_str| {
        if (sensor_str.len == 0) continue;
        const sensor_id = try std.fmt.parseUnsigned(u16, sensor_str, 10);
        if (sensor_id == 0 or sensor_id > drivercom.Config.MAX_AXES * 2) {
            std.log.err(
                "sensor {} must be between 1 and {}",
                .{ sensor_id, drivercom.Config.MAX_AXES * 2 },
            );
            return error.InvalidSensor;
        }
        sensor_buf[sensors.len] = @intCast(sensor_id - 1);
        sensors = sensor_buf[0 .. sensors.len + 1];
    }

    return sensors;
}

/// Parse CLI direction into 'f', 'b', or 'a'.
pub fn parseDirection(str: []const u8) !u8 {
    if (str.len == 1) {
        switch (str[0]) {
            'f', 'F' => return 'f',
            'b', 'B' => return 'b',
            'a', 'A' => return 'a',
            else => {
                std.log.err("{c} is not f, b, or a", .{str[0]});
                return error.InvalidDirection;
            },
        }
    } else {
        if (std.ascii.eqlIgnoreCase("backward", str)) return 'b';
        if (std.ascii.eqlIgnoreCase("forward", str)) return 'f';
        if (std.ascii.eqlIgnoreCase("all", str)) return 'a';

        std.log.err("{s} is not backward, forward, or all", .{str});
        return error.InvalidDirection;
    }
    unreachable;
}

pub fn writeConfigFile(file: std.fs.File, c: drivercom.Config) !void {
    try file.seekTo(0);
    try file.setEndPos(0);
    try std.json.stringify(c, .{ .whitespace = .indent_2 }, file.writer());
}
