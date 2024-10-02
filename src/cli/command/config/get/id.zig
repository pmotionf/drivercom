const std = @import("std");
const command = @import("../../../command.zig");
const cli = @import("../../../../cli.zig");
const args = @import("args");
const drivercom = @import("drivercom");

pub const meta = .{
    .full_text = "Retrieve Driver ID and CC-Link Station ID.",
    .usage_summary = "",
};

pub fn help(_: @This()) !void {
    const stdout = std.io.getStdOut().writer();
    try args.printHelp(
        @This(),
        "drivercom [--port] [--timeout] config.get.id",
        stdout,
    );
}

pub fn execute(_: @This()) !void {
    if (cli.port == null) {
        std.log.err("serial port must be provided", .{});
        return;
    }

    const payload = try command.transceiveMessage(
        .get_id_station,
        .set_id_station,
        .{
            .sequence = 0,
            .payload = {},
        },
    );

    const stdout = std.io.getStdOut().writer();
    try stdout.print(
        "Driver ID: {}\nCC-Link Station ID: {}\n",
        .{ payload.id, payload.station },
    );
}
