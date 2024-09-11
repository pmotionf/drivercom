pub const port = @import("command/port.zig");
pub const config = @import("command/config.zig");
pub const firmware = @import("command/firmware.zig");

const std = @import("std");
const drivercon = @import("drivercon");
const serial = @import("serial");
const cli = @import("../cli.zig");

pub fn sendMessage(msg: *const drivercon.Message) !void {
    std.debug.assert(cli.port != null);

    const writer = cli.port.?.writer();

    var retry: usize = 0;
    while (retry < cli.retry) {
        try writer.writeAll(std.mem.asBytes(msg));
        std.log.debug("Wrote message {s}: {any}", .{
            @tagName(msg.kind),
            std.mem.asBytes(msg),
        });

        var timer = try std.time.Timer.start();
        while (timer.read() < std.time.ns_per_ms * cli.timeout) {
            if (try cli.poller.pollTimeout(0)) {
                if (cli.fifo.readableLength() < 16) {
                    timer.reset();
                } else break;
            }
        } else {
            std.log.err("driver response timed out: {}", .{msg.kind});
            try serial.flushSerialPort(cli.port.?, true, true);
            retry += 1;
            continue;
        }

        var rsp: drivercon.Message = undefined;
        const read_size = cli.fifo.read(std.mem.asBytes(&rsp));
        std.debug.assert(read_size == 16);

        if (rsp.kind != .response or
            rsp.sequence != msg.sequence or
            rsp.bcc != rsp.getBcc())
        {
            std.log.err("received invalid response: {any}", .{rsp});
            try serial.flushSerialPort(cli.port.?, true, true);
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

pub fn readMessage() !drivercon.Message {
    std.debug.assert(cli.port != null);

    const writer = cli.port.?.writer();

    var timer = try std.time.Timer.start();
    while (timer.read() < std.time.ns_per_ms * cli.timeout) {
        if (try cli.poller.pollTimeout(0)) {
            if (cli.fifo.readableLength() < 16) {
                timer.reset();
            } else break;
        }
    } else {
        std.log.err("wait for driver message timed out", .{});
        return error.CommunicationFailure;
    }
    var req: drivercon.Message = undefined;
    const read_size = cli.fifo.read(std.mem.asBytes(&req));
    std.debug.assert(read_size == 16);

    if (req.getBcc() == req.bcc) {
        var rsp = req;
        rsp.kind = .response;
        rsp.bcc = rsp.getBcc();
        try writer.writeAll(std.mem.asBytes(&rsp));
        return req;
    } else {
        try serial.flushSerialPort(cli.port.?, true, false);
        std.log.err("corrupt driver message read", .{});
        return error.CommunicationFailure;
    }
}
