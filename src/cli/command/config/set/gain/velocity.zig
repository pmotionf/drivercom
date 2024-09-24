const std = @import("std");
const command = @import("../../../../command.zig");
const cli = @import("../../../../../cli.zig");
const args = @import("args");
const drivercon = @import("drivercon");
const yaml = @import("yaml");

file: ?[]const u8 = null,

pub const shorthands = .{
    .f = "file",
};

pub const meta = .{
    .full_text = "Set PMF Smart Driver velocity gain.",
    .usage_summary = "[--file] <axis> <denominator> <denominator_pi>",

    .option_docs = .{
        .file = "set velocity gain in configuration file",
    },
};

pub fn help(_: @This()) !void {
    const stdout = std.io.getStdOut().writer();
    try args.printHelp(
        @This(),
        "drivercon [--port] [--timeout] config.set.gain.velocity",
        stdout,
    );
}

pub fn execute(self: @This()) !void {
    const name = self.file orelse {
        std.log.err("file must be provided", .{});
        return;
    };

    if (cli.positionals.len != 3) {
        std.log.err(
            "axis, denominator, and denominator_pi must be provided",
            .{},
        );
        return;
    }

    const axis_id = try std.fmt.parseUnsigned(u16, cli.positionals[0], 10);
    const denominator = try std.fmt.parseUnsigned(u32, cli.positionals[1], 10);
    const denominator_pi =
        try std.fmt.parseUnsigned(u32, cli.positionals[2], 10);

    if (axis_id == 0 or axis_id > drivercon.Config.MAX_AXES) {
        std.log.err(
            "axis must be valid between 1 and {}",
            .{drivercon.Config.MAX_AXES},
        );
        return;
    }

    const axis_index = axis_id - 1;

    var file = try std.fs.cwd().openFile(name, .{ .mode = .read_write });
    defer file.close();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const file_str = try file.readToEndAlloc(allocator, 1_024_000_000);
    defer allocator.free(file_str);
    var untyped = try yaml.Yaml.load(
        allocator,
        file_str,
    );
    defer untyped.deinit();
    var config = try untyped.parse(drivercon.Config);

    const axis = &config.axes[axis_index];

    axis.velocity_gain = config.calcVelocityGain(
        axis_index,
        denominator,
        denominator_pi,
    );
    axis.position_gain = config.calcPositionGain(
        axis_index,
        axis.position_gain.denominator,
    );

    try file.seekTo(0);
    try yaml.stringify(allocator, config, file.writer());

    if (cli.port) |_| {
        var sequence: u16 = 0;
        var msg = drivercon.Message.init(
            .set_velocity_gain_p,
            sequence,
            .{ .axis = axis_index, .p = axis.velocity_gain.p },
        );
        try command.sendMessage(&msg);

        sequence += 1;
        msg = drivercon.Message.init(
            .set_velocity_gain_i,
            sequence,
            .{ .axis = axis_index, .i = axis.velocity_gain.i },
        );
        try command.sendMessage(&msg);

        sequence += 1;
        msg = drivercon.Message.init(
            .set_velocity_gain_denominator,
            sequence,
            .{
                .axis = axis_index,
                .denominator = axis.velocity_gain.denominator,
            },
        );
        try command.sendMessage(&msg);

        sequence += 1;
        msg = drivercon.Message.init(
            .set_velocity_gain_denominator_pi,
            sequence,
            .{
                .axis = axis_index,
                .denominator = axis.velocity_gain.denominator_pi,
            },
        );
        try command.sendMessage(&msg);

        sequence += 1;
        msg = drivercon.Message.init(
            .set_position_gain_p,
            sequence,
            .{ .axis = axis_index, .p = axis.position_gain.p },
        );
        try command.sendMessage(&msg);

        sequence += 1;
        msg = drivercon.Message.init(
            .set_position_gain_denominator,
            sequence,
            .{
                .axis = axis_index,
                .denominator = axis.position_gain.denominator,
            },
        );
        try command.sendMessage(&msg);

        sequence += 1;
        msg = drivercon.Message.init(.save_config, sequence, {});
        try command.sendMessage(&msg);
    }
}
