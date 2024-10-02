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
    .full_text = "Set neighboring drivers.",
    .usage_summary = "[--file] <forward/backward/all>",

    .option_docs = .{
        .file = "set Driver ID and CC-Link Station ID in configuration file",
    },
};

pub fn help(_: @This()) !void {
    const stdout = std.io.getStdOut().writer();
    try args.printHelp(
        @This(),
        "drivercom [--port] [--timeout] config.set.neighbor",
        stdout,
    );
}

pub fn execute(self: @This()) !void {
    if (cli.port == null and self.file == null) {
        std.log.err("serial port or file must be provided", .{});
        return;
    }

    if (cli.positionals.len != 1) {
        std.log.err("neighbor direction must be provided", .{});
        return;
    }

    const dir = try command.parseDirection(cli.positionals[0]);

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

        switch (dir) {
            'a' => {
                config.flags.has_neighbor.backward = 1;
                config.flags.has_neighbor.forward = 1;
            },
            'b' => {
                config.flags.has_neighbor.backward = 1;
                config.flags.has_neighbor.forward = 0;
            },
            'f' => {
                config.flags.has_neighbor.backward = 0;
                config.flags.has_neighbor.forward = 1;
            },
            else => unreachable,
        }

        try file.seekTo(0);
        try std.json.stringify(
            config,
            .{ .whitespace = .indent_2 },
            file.writer(),
        );
    }

    if (cli.port) |_| {
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

        switch (dir) {
            'a' => {
                flags.has_neighbor.backward = 1;
                flags.has_neighbor.forward = 1;
            },
            'b' => {
                flags.has_neighbor.backward = 1;
                flags.has_neighbor.forward = 0;
            },
            'f' => {
                flags.has_neighbor.backward = 0;
                flags.has_neighbor.forward = 1;
            },
            else => unreachable,
        }

        msg = drivercom.Message.init(.set_system_flags, 1, .{
            .flags = flags,
        });
        try command.sendMessage(&msg);

        msg = drivercom.Message.init(.save_config, 2, {});
        try command.sendMessage(&msg);
    }
}
