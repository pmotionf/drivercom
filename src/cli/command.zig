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
        return error.CommunicationFailure;
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
        return error.CommunicationFailure;
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

/// Parse CLI axis input into a slice of axis indices.
pub fn parseAxis(str: []const u8, axes_buf: []u16) ![]u16 {
    std.debug.assert(axes_buf.len >= drivercom.Config.MAX_AXES);
    var axes: []u16 = &.{};

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
        axes_buf[axes.len] = axis_id - 1;
        axes = axes_buf[0 .. axes.len + 1];
    }

    return axes;
}
