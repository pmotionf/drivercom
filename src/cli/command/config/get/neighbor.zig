const std = @import("std");
const command = @import("../../../command.zig");
const cli = @import("../../../../cli.zig");
const args = @import("args");
const drivercom = @import("drivercom");

pub const meta = .{
    .full_text = "Retrieve neighboring drivers.",
    .usage_summary = "",
};

pub fn help(_: @This()) !void {
    const stdout = std.io.getStdOut().writer();
    try args.printHelp(
        @This(),
        "drivercom [--port] [--timeout] config.get.neighbor",
        stdout,
    );
}

pub fn execute(_: @This()) !void {
    if (cli.port == null) {
        std.log.err("serial port must be provided", .{});
        return;
    }

    const payload = try command.transceiveMessage(
        .get_system_flags,
        .set_system_flags,
        .{
            .sequence = 0,
            .payload = {},
        },
    );

    const flags = payload.flags;

    const stdout = std.io.getStdOut().writer();
    try stdout.print(
        "Backward Neighbor: {}\nForward Neighbor: {}\n",
        .{ flags.has_neighbor.backward, flags.has_neighbor.forward },
    );
}
