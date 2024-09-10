pub const id = @import("set/id.zig");
pub const gain = @import("set/gain.zig");

const std = @import("std");
const cli = @import("../../../cli.zig");
const command = @import("../../command.zig");
const args = @import("args");
const drivercon = @import("drivercon");
const yaml = @import("yaml");

file: ?[]const u8 = null,

pub const shorthands = .{
    .f = "file",
};

pub const meta = .{
    .full_text = "Set PMF Smart Driver configuration.",
    .usage_summary = "[--file]",

    .option_docs = .{
        .file = "set driver configuration from file",
    },
};

pub fn help() !void {
    const stdout = std.io.getStdOut().writer();
    try args.printHelp(
        @This(),
        "drivercon [--port] [--timeout] config.set",
        stdout,
    );
}

pub fn execute(self: @This()) !void {
    if (cli.help) {
        try help();
        return;
    }
    const port = cli.port orelse {
        std.log.err("COM port must be provided", .{});
        return;
    };

    var file = try std.fs.cwd().openFile(self.file orelse {
        std.log.err("file must be provided", .{});
        return;
    }, .{});
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
    const config = try untyped.parse(drivercon.Config);

    var sequence: u16 = 0;
    var msg = drivercon.Message.init(
        .set_id_station,
        sequence,
        .{ .id = config.id, .station = config.station_id },
    );
    try command.sendMessage(port, &msg);

    sequence += 1;
    msg = drivercon.Message.init(
        .set_system_flags,
        sequence,
        .{ .flags = config.flags },
    );
    try command.sendMessage(port, &msg);

    sequence += 1;
    msg = drivercon.Message.init(
        .set_magnet,
        sequence,
        .{ .pitch = config.magnet.pitch, .length = config.magnet.length },
    );
    try command.sendMessage(port, &msg);

    sequence += 1;
    msg = drivercon.Message.init(
        .set_vehicle_mass,
        sequence,
        config.vehicle_mass,
    );
    try command.sendMessage(port, &msg);

    sequence += 1;
    msg = drivercon.Message.init(
        .set_angle_offset,
        sequence,
        config.mechanical_angle_offset,
    );
    try command.sendMessage(port, &msg);

    sequence += 1;
    msg = drivercon.Message.init(
        .set_angle_offset,
        sequence,
        config.mechanical_angle_offset,
    );
    try command.sendMessage(port, &msg);

    sequence += 1;
    msg = drivercon.Message.init(
        .set_axis_length,
        sequence,
        .{
            .axis_length = config.axis_length,
            .motor_length = config.motor_length,
        },
    );
    try command.sendMessage(port, &msg);

    sequence += 1;
    msg = drivercon.Message.init(
        .set_calibrated_home,
        sequence,
        config.calibrated_home_position,
    );
    try command.sendMessage(port, &msg);

    sequence += 1;
    msg = drivercon.Message.init(
        .set_total_axes,
        sequence,
        config.total_axes,
    );
    try command.sendMessage(port, &msg);

    sequence += 1;
    msg = drivercon.Message.init(
        .set_warmup_voltage,
        sequence,
        config.warmup_voltage_reference,
    );
    try command.sendMessage(port, &msg);

    sequence += 1;
    msg = drivercon.Message.init(
        .set_calibration_magnet_length,
        sequence,
        .{
            .backward = config.calibration_magnet_length.backward,
            .forward = config.calibration_magnet_length.forward,
        },
    );
    try command.sendMessage(port, &msg);

    sequence += 1;
    msg = drivercon.Message.init(
        .set_voltage_target,
        sequence,
        config.vdc.target,
    );
    try command.sendMessage(port, &msg);

    sequence += 1;
    msg = drivercon.Message.init(
        .set_voltage_limits,
        sequence,
        .{
            .lower = config.vdc.limit.lower,
            .upper = config.vdc.limit.upper,
        },
    );
    try command.sendMessage(port, &msg);

    for (0..drivercon.Config.MAX_AXES) |_i| {
        const i: u16 = @intCast(_i);

        sequence += 1;
        msg = drivercon.Message.init(
            .set_max_current,
            sequence,
            .{ .axis = i, .current = config.axes[i].max_current },
        );
        try command.sendMessage(port, &msg);

        sequence += 1;
        msg = drivercon.Message.init(
            .set_continuous_current,
            sequence,
            .{
                .axis = i,
                .current = config.axes[i].continuous_current,
            },
        );
        try command.sendMessage(port, &msg);

        sequence += 1;
        msg = drivercon.Message.init(
            .set_current_gain_p,
            sequence,
            .{ .axis = i, .p = config.axes[i].current_gain.p },
        );
        try command.sendMessage(port, &msg);

        sequence += 1;
        msg = drivercon.Message.init(
            .set_current_gain_i,
            sequence,
            .{ .axis = i, .i = config.axes[i].current_gain.i },
        );
        try command.sendMessage(port, &msg);

        sequence += 1;
        msg = drivercon.Message.init(
            .set_current_gain_denominator,
            sequence,
            .{
                .axis = i,
                .denominator = config.axes[i].current_gain.denominator,
            },
        );
        try command.sendMessage(port, &msg);

        sequence += 1;
        msg = drivercon.Message.init(
            .set_velocity_gain_p,
            sequence,
            .{ .axis = i, .p = config.axes[i].velocity_gain.p },
        );
        try command.sendMessage(port, &msg);

        sequence += 1;
        msg = drivercon.Message.init(
            .set_velocity_gain_i,
            sequence,
            .{ .axis = i, .i = config.axes[i].velocity_gain.i },
        );
        try command.sendMessage(port, &msg);

        sequence += 1;
        msg = drivercon.Message.init(
            .set_velocity_gain_denominator,
            sequence,
            .{
                .axis = i,
                .denominator = config.axes[i].velocity_gain.denominator,
            },
        );
        try command.sendMessage(port, &msg);

        sequence += 1;
        msg = drivercon.Message.init(
            .set_velocity_gain_denominator_pi,
            sequence,
            .{
                .axis = i,
                .denominator = config.axes[i].velocity_gain.denominator_pi,
            },
        );
        try command.sendMessage(port, &msg);

        sequence += 1;
        msg = drivercon.Message.init(
            .set_position_gain_p,
            sequence,
            .{ .axis = i, .p = config.axes[i].position_gain.p },
        );
        try command.sendMessage(port, &msg);

        sequence += 1;
        msg = drivercon.Message.init(
            .set_position_gain_denominator,
            sequence,
            .{
                .axis = i,
                .denominator = config.axes[i].position_gain.denominator,
            },
        );
        try command.sendMessage(port, &msg);

        sequence += 1;
        msg = drivercon.Message.init(
            .set_in_position_threshold,
            sequence,
            .{ .axis = i, .threshold = config.axes[i].in_position_threshold },
        );
        try command.sendMessage(port, &msg);

        sequence += 1;
        msg = drivercon.Message.init(
            .set_base_position,
            sequence,
            .{ .axis = i, .position = config.axes[i].base_position },
        );
        try command.sendMessage(port, &msg);

        sequence += 1;
        msg = drivercon.Message.init(
            .set_back_sensor_off,
            sequence,
            .{
                .axis = i,
                .position = config.axes[i].back_sensor_off.position,
                .section_count = config.axes[i].back_sensor_off.section_count,
            },
        );
        try command.sendMessage(port, &msg);

        sequence += 1;
        msg = drivercon.Message.init(
            .set_front_sensor_off,
            sequence,
            .{
                .axis = i,
                .position = config.axes[i].front_sensor_off.position,
                .section_count = config.axes[i].front_sensor_off.section_count,
            },
        );
        try command.sendMessage(port, &msg);

        sequence += 1;
        msg = drivercon.Message.init(
            .set_rs,
            sequence,
            .{ .axis = i, .rs = config.axes[i].rs },
        );
        try command.sendMessage(port, &msg);

        sequence += 1;
        msg = drivercon.Message.init(
            .set_ls,
            sequence,
            .{ .axis = i, .ls = config.axes[i].ls },
        );
        try command.sendMessage(port, &msg);

        sequence += 1;
        msg = drivercon.Message.init(
            .set_kf,
            sequence,
            .{ .axis = i, .kf = config.axes[i].kf },
        );
        try command.sendMessage(port, &msg);

        sequence += 1;
        msg = drivercon.Message.init(
            .set_kbm,
            sequence,
            .{ .axis = i, .kbm = config.axes[i].kbm },
        );
        try command.sendMessage(port, &msg);
    }

    for (0..drivercon.Config.MAX_AXES * 2) |_i| {
        const i: u16 = @intCast(_i);

        sequence += 1;
        msg = drivercon.Message.init(
            .set_calibrated_magnet_length_backward,
            sequence,
            .{
                .sensor = i,
                .length = config.hall_sensors[i].calibrated_magnet_length.backward,
            },
        );
        try command.sendMessage(port, &msg);

        sequence += 1;
        msg = drivercon.Message.init(
            .set_calibrated_magnet_length_forward,
            sequence,
            .{
                .sensor = i,
                .length = config.hall_sensors[i].calibrated_magnet_length.forward,
            },
        );
        try command.sendMessage(port, &msg);
    }
}
