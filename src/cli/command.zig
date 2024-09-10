pub const port = @import("command/port.zig");
pub const config = @import("command/config.zig");

const std = @import("std");
const drivercon = @import("drivercon");
const serial = @import("serial");
const cli = @import("../cli.zig");

pub fn sendMessage(port_: std.fs.File, msg: *const drivercon.Message) !void {
    const writer = port_.writer();
    const reader = port_.reader();

    var retry: usize = 0;
    while (retry < cli.retry) {
        try writer.writeAll(std.mem.asBytes(msg));
        std.log.debug("Wrote message {s}: {any}", .{
            @tagName(msg.kind),
            std.mem.asBytes(msg),
        });
        var timer = try std.time.Timer.start();
        while (timer.read() < std.time.ns_per_us * cli.timeout) {
            var rsp = try reader.readStruct(drivercon.Message);

            if (rsp.kind != .response or
                rsp.sequence != msg.sequence or
                rsp.bcc != rsp.getBcc())
            {
                try serial.flushSerialPort(port_, true, true);
                continue;
            }
            break;
        } else {
            std.log.err("driver response timed out: {}", .{msg.kind});
            retry += 1;
        }
        break;
    } else {
        std.log.err("all retries failed", .{});
        return;
    }
    std.log.debug("Received response for {s}", .{@tagName(msg.kind)});
}

pub fn readMessage(port_: std.fs.File) !drivercon.Message {
    const reader = port_.reader();
    const writer = port_.writer();
    while (true) {
        const req = try reader.readStruct(drivercon.Message);
        if (req.getBcc() == req.bcc) {
            var rsp = req;
            rsp.kind = .response;
            rsp.bcc = rsp.getBcc();
            try writer.writeAll(std.mem.asBytes(&rsp));
            return req;
        } else {
            try serial.flushSerialPort(port_, true, false);
        }
    }
}
