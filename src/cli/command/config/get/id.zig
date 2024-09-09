const std = @import("std");
const command = @import("../../../command.zig");
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

    var msg: drivercon.Message = .{
        .kind = .get_id_station,
    };
    msg.setBcc();

    while (true) {
        try command.sendMessage(cli.port.?, &msg);
        const req = try command.readMessage(cli.port.?);
        if (req.kind == .set_id_station and req.sequence == 1) {
            const stdout = std.io.getStdOut().writer();

            try stdout.print(
                "Driver ID: {}\nCC-Link Station ID: {}\n",
                .{ req.payload.u16[0], req.payload.u16[1] },
            );
            break;
        }
    }
}
