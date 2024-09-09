pub const port = @import("command/port.zig");
pub const config = @import("command/config.zig");

const std = @import("std");
const drivercon = @import("drivercon");
const serial = @import("serial");
const cli = @import("../cli.zig");

pub fn sendMessage(p: std.fs.File, msg: *const drivercon.Message) !void {
    const writer = p.writer();
    const reader = p.reader();

    var retry: usize = 0;
    while (retry < cli.retry) {
        try writer.writeAll(std.mem.asBytes(msg));
        var timer = try std.time.Timer.start();
        while (timer.read() < std.time.ns_per_us * cli.timeout) {
            var rsp = try reader.readStruct(drivercon.Message);

            if (rsp.kind != .response or
                rsp.sequence != msg.sequence or
                rsp.bcc != rsp.getBcc())
            {
                try serial.flushSerialPort(p, true, true);
                continue;
            }
            break;
        } else {
            std.log.err("driver response timed out", .{});
            retry += 1;
        }
        break;
    } else {
        std.log.err("all retries failed", .{});
        return;
    }
}

pub fn readMessage(p: std.fs.File) !drivercon.Message {
    const reader = p.reader();
    const writer = p.writer();
    while (true) {
        const req = try reader.readStruct(drivercon.Message);
        if (req.getBcc() == req.bcc) {
            var rsp = req;
            rsp.kind = .response;
            rsp.setBcc();
            try writer.writeAll(std.mem.asBytes(&rsp));
            return req;
        } else {
            try serial.flushSerialPort(p, true, false);
        }
    }
}
