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
    .full_text = "Set calibration magnet length.",
    .usage_summary = "[--file] <backward/forward/all> <length>",

    .option_docs = .{
        .file = "set calibration magnet length in configuration file",
    },
};

pub fn help(_: @This()) !void {
    const stdout = std.io.getStdOut().writer();
    try args.printHelp(
        @This(),
        "drivercom [--port] [--timeout] config.set.calibration_magnet_length",
        stdout,
    );
}

pub fn execute(self: @This()) !void {
    if (cli.port == null and self.file == null) {
        std.log.err("serial port or file must be provided", .{});
        return;
    }

    if (cli.positionals.len != 2) {
        std.log.err("direction and length must be provided", .{});
        return;
    }

    const dir = try command.parseDirection(cli.positionals[0]);
    const length = try std.fmt.parseFloat(f32, cli.positionals[1]);

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

        if (dir == 'b' or dir == 'a') {
            config.calibration_magnet_length.backward =
                if (length > 0.0) -length else length;
        }
        if (dir == 'f' or dir == 'a') {
            config.calibration_magnet_length.forward =
                if (length < 0.0) -length else length;
        }

        try file.seekTo(0);
        try std.json.stringify(
            config,
            .{ .whitespace = .indent_2 },
            file.writer(),
        );
    }

    if (cli.port) |_| {
        var sequence: u16 = 0;
        var backward: f32 = 0.0;
        var forward: f32 = 0.0;

        if (dir == 'a') {
            backward = if (length > 0.0) -length else length;
            forward = if (length < 0.0) -length else length;
        } else if (dir == 'b') {
            backward = if (length > 0.0) -length else length;

            const msg = drivercom.Message.init(
                .get_calibration_magnet_length,
                sequence,
                {},
            );
            try command.sendMessage(&msg);
            const req = try command.readMessage();
            if (req.kind == .set_calibration_magnet_length and
                req.sequence == sequence)
            {
                sequence += 1;
                const payload = req.payload(.set_calibration_magnet_length);
                forward = payload.forward;
            } else {
                std.log.err("received invalid response: {any}", .{req});
                return error.CommunicationFailure;
            }
        } else if (dir == 'f') {
            forward = if (length < 0.0) -length else length;

            const msg = drivercom.Message.init(
                .get_calibration_magnet_length,
                sequence,
                {},
            );
            try command.sendMessage(&msg);
            const req = try command.readMessage();
            if (req.kind == .set_calibration_magnet_length and
                req.sequence == sequence)
            {
                sequence += 1;
                const payload = req.payload(.set_calibration_magnet_length);
                backward = payload.backward;
            } else {
                std.log.err("received invalid response: {any}", .{req});
                return error.CommunicationFailure;
            }
        } else unreachable;

        var msg = drivercom.Message.init(
            .set_calibration_magnet_length,
            sequence,
            .{ .backward = backward, .forward = forward },
        );
        try command.sendMessage(&msg);
        sequence += 1;

        msg = drivercom.Message.init(.save_config, sequence, {});
        try command.sendMessage(&msg);
    }
}
