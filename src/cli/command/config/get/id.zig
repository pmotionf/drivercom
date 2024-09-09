const std = @import("std");
const cli = @import("../../../../cli.zig");
const args = @import("args");
const drivercon = @import("drivercon");
const serial = @import("serial");

pub const meta = .{
    .full_text = "Retrieve PMF Smart Driver ID and CC-Link Station ID.",
    .usage_summary = "",

    .option_docs = .{},
};

pub fn help() !void {
    const stdout = std.io.getStdOut().writer();
    try args.printHelp(
        @This(),
        "drivercon [--port] [--timeout] config.get.id",
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
    const port = cli.port.?;
    const writer = port.writer();
    const reader = port.reader();

    var msg: drivercon.Message = .{
        .kind = .get_id_station,
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

    while (true) {
        const req = try reader.readStruct(drivercon.Message);
        if (req.kind == .set_id_station and
            req.sequence == 1 and
            req.getBcc() == req.bcc)
        {
            var rsp = req;
            rsp.kind = .response;
            rsp.setBcc();

            const stdout = std.io.getStdOut().writer();

            try stdout.print(
                "Driver ID: {}\nCC-Link Station ID: {}\n",
                .{ rsp.payload.u16[0], rsp.payload.u16[1] },
            );

            try writer.writeAll(std.mem.asBytes(&rsp));
            break;
        } else {
            try serial.flushSerialPort(port, true, true);
        }
    }
}
