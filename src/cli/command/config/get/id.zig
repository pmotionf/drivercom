const std = @import("std");
const command = @import("../../../command.zig");
const cli = @import("../../../../cli.zig");
const args = @import("args");
const drivercom = @import("drivercom");
const serial = @import("serial");

pub const meta = .{
    .full_text = "Retrieve PMF Smart Driver ID and CC-Link Station ID.",
    .usage_summary = "",

    .option_docs = .{},
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

    const msg = drivercom.Message.init(.get_id_station, 0, {});
    while (true) {
        try command.sendMessage(&msg);
        const req = try command.readMessage();
        if (req.kind == .set_id_station and req.sequence == 1) {
            const payload = req.payload(.set_id_station);

            const stdout = std.io.getStdOut().writer();
            try stdout.print(
                "Driver ID: {}\nCC-Link Station ID: {}\n",
                .{ payload.id, payload.station },
            );
            break;
        }
    }
}
