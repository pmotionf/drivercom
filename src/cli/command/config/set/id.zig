const std = @import("std");
const command = @import("../../../command.zig");
const cli = @import("../../../../cli.zig");
const args = @import("args");
const drivercon = @import("drivercon");

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
    const port = cli.port orelse {
        std.log.err("COM port must be provided", .{});
        return;
    };

    if (cli.positionals.len != 2) {
        std.log.err("Driver ID and CC-Link Station ID must be provided", .{});
        return;
    }

    const driver_id = try std.fmt.parseUnsigned(u16, cli.positionals[0], 10);
    const station_id = try std.fmt.parseUnsigned(u16, cli.positionals[1], 10);

    var msg = drivercon.Message.init(
        .set_id_station,
        0,
        .{ .id = driver_id, .station = station_id },
    );
    try command.sendMessage(port, &msg);

    msg = drivercon.Message.init(.save_config, 1, {});
    try command.sendMessage(port, &msg);
}
