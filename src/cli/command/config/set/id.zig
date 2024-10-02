const std = @import("std");
const command = @import("../../../command.zig");
const cli = @import("../../../../cli.zig");
const args = @import("args");
const drivercom = @import("drivercom");

file: ?[]const u8 = null,

pub const shorthands = .{
    .f = "file",
};

pub const meta = .{
    .full_text = "Set Driver ID and CC-Link Station ID.",
    .usage_summary = "[--file] <Driver ID> <CC-Link Station ID>",

    .option_docs = .{
        .file = "set Driver ID and CC-Link Station ID in configuration file",
    },
};

pub fn help(_: @This()) !void {
    const stdout = std.io.getStdOut().writer();
    try args.printHelp(
        @This(),
        "drivercom [--port] [--timeout] config.set.id",
        stdout,
    );
}

pub fn execute(self: @This()) !void {
    if (cli.port == null and self.file == null) {
        std.log.err("serial port or file must be provided", .{});
        return;
    }

    if (cli.positionals.len != 2) {
        std.log.err("Driver ID and CC-Link Station ID must be provided", .{});
        return;
    }

    const driver_id = try std.fmt.parseUnsigned(u16, cli.positionals[0], 10);
    const station_id = try std.fmt.parseUnsigned(u16, cli.positionals[1], 10);

    if (self.file) |name| {
        var file = try std.fs.cwd().openFile(name, .{ .mode = .read_write });
        defer file.close();

        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        const file_str = try file.readToEndAlloc(allocator, 1_024_000_000);
        defer allocator.free(file_str);
        var untyped = try std.json.parseFromSlice(
            drivercom.Config,
            allocator,
            file_str,
            .{},
        );
        defer untyped.deinit();
        var config = untyped.value;

        config.id = driver_id;
        config.station_id = station_id;

        try file.seekTo(0);
        try std.json.stringify(
            config,
            .{ .whitespace = .indent_2 },
            file.writer(),
        );
    }

    if (cli.port) |_| {
        var msg = drivercom.Message.init(
            .set_id_station,
            0,
            .{ .id = driver_id, .station = station_id },
        );
        try command.sendMessage(&msg);

        msg = drivercom.Message.init(.save_config, 1, {});
        try command.sendMessage(&msg);
    }
}
