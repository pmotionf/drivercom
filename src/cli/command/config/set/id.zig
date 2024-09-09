const std = @import("std");
const cli = @import("../../../../cli.zig");
const args = @import("args");
const drivercon = @import("drivercon");
const serial = @import("serial");

pub const meta = .{
    .full_text = "Set PMF Smart Driver ID and CC-Link Station ID.",
    .usage_summary = " <Driver ID> <CC-Link Station ID>",

    .option_docs = .{},
};

pub fn help() !void {
    const stdout = std.io.getStdOut().writer();
    try args.printHelp(
        @This(),
        "drivercon [--port] [--timeout] config.set.id",
        stdout,
    );
}

pub fn execute(_: @This()) !void {
    if (cli.help) {
        try help();
        return;
    }
    if (cli.port == null) {
        std.log.err("COM port must be provided", .{});
        return;
    }

    if (cli.positionals.len != 2) {
        std.log.err("Driver ID and CC-Link Station ID must be provided", .{});
        return;
    }

    const driver_id = try std.fmt.parseUnsigned(u16, cli.positionals[0], 10);
    const station_id = try std.fmt.parseUnsigned(u16, cli.positionals[1], 10);

    const port = cli.port.?;
    const writer = port.writer();
    const reader = port.reader();

    var msg: drivercon.Message = .{
        .kind = .set_id_station,
        .payload = .{ .u16 = .{ driver_id, station_id, 0, 0 } },
    };
    msg.setBcc();

    var retry: usize = 0;
    while (retry < cli.retry) {
        try writer.writeAll(std.mem.asBytes(&msg));
        var timer = try std.time.Timer.start();
        while (timer.read() < std.time.ns_per_us * cli.timeout) {
            var rsp = try reader.readStruct(drivercon.Message);
            if (rsp.kind != .response or
                rsp.sequence != 0 or
                rsp.bcc != rsp.getBcc())
            {
                try serial.flushSerialPort(port, true, true);
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

    msg = .{
        .kind = .save_config,
        .sequence = 1,
    };
    msg.setBcc();

    retry = 0;
    while (retry < cli.retry) {
        try writer.writeAll(std.mem.asBytes(&msg));
        var timer = try std.time.Timer.start();
        while (timer.read() < std.time.ns_per_us * cli.timeout) {
            var rsp = try reader.readStruct(drivercon.Message);
            if (rsp.kind != .response or
                rsp.sequence != 1 or
                rsp.bcc != rsp.getBcc())
            {
                try serial.flushSerialPort(port, true, true);
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
