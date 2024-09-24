const std = @import("std");
const command = @import("../command.zig");
const cli = @import("../../cli.zig");
const args = @import("args");
const drivercon = @import("drivercon");
const serial = @import("serial");

pub const meta = .{
    .full_text = "Retrieve PMF Smart Driver firmware version.",
    .usage_summary = "",

    .option_docs = .{},
};

pub fn help(_: @This()) !void {
    const stdout = std.io.getStdOut().writer();
    try args.printHelp(
        @This(),
        "drivercon [--port] [--timeout] firmware",
        stdout,
    );
}

pub fn execute(_: @This()) !void {
    if (cli.port == null) {
        std.log.err("COM port must be provided", .{});
        return;
    }

    const msg = drivercon.Message.init(.firmware_version, 0, .{});
    try command.sendMessage(&msg);
    const req = try command.readMessage();
    if (req.kind == .firmware_version and req.sequence == 1) {
        const payload = req.payload(.firmware_version);

        const stdout = std.io.getStdOut().writer();
        try stdout.print(
            "Driver firmware version: {}.{}.{}\n",
            .{ payload.major, payload.minor, payload.patch },
        );
    } else {
        std.log.err("received invalid response: {any}", .{req});
        return error.CommunicationFailure;
    }
}
