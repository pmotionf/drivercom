const std = @import("std");
const cli = @import("../../../cli.zig");
const command = @import("../../command.zig");
const args = @import("args");
const drivercom = @import("drivercom");

pub const meta = .{
    .full_text = "Stop driver logging.",
    .usage_summary = "",
};

pub fn help(_: @This()) !void {
    const stdout = std.io.getStdOut().writer();
    try args.printHelp(
        @This(),
        "drivercom [--port] [--timeout] log.stop",
        stdout,
    );
}

pub fn execute(_: @This()) !void {
    if (cli.port == null) {
        std.log.err("serial port must be provided", .{});
        return;
    }

    var sequence: u16 = 0;
    var msg = drivercom.Message.init(.log_stop, sequence, {});
    try command.sendMessage(&msg);

    sequence += 1;
    msg = drivercom.Message.init(
        .log_status,
        sequence,
        .{ .status = .{ .value = .stopped }, .cycles_completed = 0 },
    );
    for (0..3) |_| {
        try command.sendMessage(&msg);
        const req = try command.readMessage();
        std.log.info("{any}", .{req});
        if (req.kind == .log_status and req.sequence == sequence) {
            const payload = req.payload(.log_status);
            switch (payload.status.value) {
                .started => {
                    std.log.err("log started", .{});
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
                    std.log.info("logging stopped", .{});
                    break;
                },
            }
        }
    }
}
