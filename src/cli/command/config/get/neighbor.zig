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
    var msg = drivercom.Message.init(.get_system_flags, 0, {});
    var flags: drivercom.Config.SystemFlags = undefined;
    while (true) {
        try command.sendMessage(&msg);
        const rsp = try command.readMessage();
        if (rsp.kind == .set_system_flags and rsp.sequence == 0) {
            flags = rsp.payload(.set_system_flags).flags;
            break;
        }
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print(
        "Backward Neighbor: {}\nForward Neighbor: {}\n",
        .{ flags.has_neighbor.backward, flags.has_neighbor.forward },
    );
}
