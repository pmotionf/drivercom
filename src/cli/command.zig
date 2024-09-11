pub const port = @import("command/port.zig");
pub const config = @import("command/config.zig");
pub const firmware = @import("command/firmware.zig");

const std = @import("std");
const drivercon = @import("drivercon");
const serial = @import("serial");
const cli = @import("../cli.zig");

pub fn sendMessage(port_: std.fs.File, msg: *const drivercon.Message) !void {
    const writer = port_.writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var poller = std.io.poll(allocator, enum { f }, .{ .f = port_ });
    defer poller.deinit();
    var fifo = poller.fifo(.f);

    var retry: usize = 0;
    while (retry < cli.retry) {
        try writer.writeAll(std.mem.asBytes(msg));
        std.log.debug("Wrote message {s}: {any}", .{
            @tagName(msg.kind),
            std.mem.asBytes(msg),
        });

        while (try poller.pollTimeout(std.time.ns_per_ms * cli.timeout)) {
            if (fifo.readableLength() < 16) continue;
            break;
        } else {
            std.log.err("driver response timed out: {}", .{msg.kind});
            try serial.flushSerialPort(port_, true, true);
            retry += 1;
            fifo.discard(512);
            continue;
        }

        const rsp = std.mem.bytesToValue(
            drivercon.Message,
            fifo.readableSliceOfLen(16),
        );
        if (rsp.kind != .response or
            rsp.sequence != msg.sequence or
            rsp.bcc != rsp.getBcc())
        {
            std.log.err("received invalid response: {any}", .{rsp});
            try serial.flushSerialPort(port_, true, true);
            fifo.discard(512);
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

pub fn readMessage(port_: std.fs.File) !drivercon.Message {
    const writer = port_.writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var poller = std.io.poll(allocator, enum { f }, .{ .f = port_ });
    defer poller.deinit();
    var fifo = poller.fifo(.f);

    while (try poller.pollTimeout(std.time.ns_per_ms * cli.timeout)) {
        if (fifo.readableLength() < 16) continue;
        break;
    } else {
        std.log.err("wait for driver message timed out", .{});
        return error.CommunicationFailure;
    }
    const req = std.mem.bytesToValue(
        drivercon.Message,
        fifo.readableSliceOfLen(16),
    );
    if (req.getBcc() == req.bcc) {
        var rsp = req;
        rsp.kind = .response;
        rsp.bcc = rsp.getBcc();
        try writer.writeAll(std.mem.asBytes(&rsp));
        return req;
    } else {
        try serial.flushSerialPort(port_, true, false);
        std.log.err("corrupt driver message read", .{});
        return error.CommunicationFailure;
    }
}
