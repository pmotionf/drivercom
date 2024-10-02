pub const id = @import("get/id.zig");
pub const neighbor = @import("get/neighbor.zig");

const std = @import("std");
const cli = @import("../../../cli.zig");
const command = @import("../../command.zig");
const args = @import("args");
const drivercom = @import("drivercom");

file: ?[]const u8 = null,

pub const shorthands = .{
    .f = "file",
};

pub const meta = .{
    .full_text = "Retrieve driver configuration.",
    .usage_summary = "[--file]",

    .option_docs = .{
        .file = "save retrieved driver configuration to file",
    },
};

pub fn help(_: @This()) !void {
    const stdout = std.io.getStdOut().writer();
    try args.printHelp(
        @This(),
        "drivercom [--port] [--timeout] config.get",
        stdout,
    );
}

pub fn execute(self: @This()) !void {
    if (cli.port == null) {
        std.log.err("serial port must be provided", .{});
        return;
    }

    const stdout = std.io.getStdOut().writer();
    var config: drivercom.Config = std.mem.zeroes(drivercom.Config);

    var sequence: u16 = 0;
    {
        const payload = try command.transceiveMessage(
            .get_id_station,
            .set_id_station,
            .{ .sequence = sequence, .payload = {} },
        );
        config.id = payload.id;
        config.station_id = payload.station;
    }
    {
        sequence += 1;
        const payload = try command.transceiveMessage(
            .get_system_flags,
            .set_system_flags,
            .{ .sequence = sequence, .payload = {} },
        );
        config.flags = payload.flags;
    }
    {
        sequence += 1;
        const payload = try command.transceiveMessage(
            .get_magnet,
            .set_magnet,
            .{ .sequence = sequence, .payload = {} },
        );
        config.magnet.pitch = payload.pitch;
        config.magnet.length = payload.length;
    }
    {
        sequence += 1;
        const payload = try command.transceiveMessage(
            .get_vehicle_mass,
            .set_vehicle_mass,
            .{ .sequence = sequence, .payload = {} },
        );
        config.vehicle_mass = payload;
    }
    {
        sequence += 1;
        const payload = try command.transceiveMessage(
            .get_angle_offset,
            .set_angle_offset,
            .{ .sequence = sequence, .payload = {} },
        );
        config.mechanical_angle_offset = payload;
    }
    {
        sequence += 1;
        const payload = try command.transceiveMessage(
            .get_axis_length,
            .set_axis_length,
            .{ .sequence = sequence, .payload = {} },
        );
        config.axis_length = payload.axis_length;
        config.motor.length = payload.motor_length;
    }
    {
        sequence += 1;
        const payload = try command.transceiveMessage(
            .get_calibrated_home,
            .set_calibrated_home,
            .{ .sequence = sequence, .payload = {} },
        );
        config.calibrated_home_position = payload;
    }
    {
        sequence += 1;
        const payload = try command.transceiveMessage(
            .get_total_axes,
            .set_total_axes,
            .{ .sequence = sequence, .payload = {} },
        );
        config.total_axes = payload;
    }
    {
        sequence += 1;
        const payload = try command.transceiveMessage(
            .get_warmup_voltage,
            .set_warmup_voltage,
            .{ .sequence = sequence, .payload = {} },
        );
        config.warmup_voltage_reference = payload;
    }
    {
        sequence += 1;
        const payload = try command.transceiveMessage(
            .get_calibration_magnet_length,
            .set_calibration_magnet_length,
            .{ .sequence = sequence, .payload = {} },
        );
        config.calibration_magnet_length.backward = payload.backward;
        config.calibration_magnet_length.forward = payload.forward;
    }
    {
        sequence += 1;
        const payload = try command.transceiveMessage(
            .get_voltage_target,
            .set_voltage_target,
            .{ .sequence = sequence, .payload = {} },
        );
        config.vdc.target = payload;
    }
    {
        sequence += 1;
        const payload = try command.transceiveMessage(
            .get_voltage_limits,
            .set_voltage_limits,
            .{ .sequence = sequence, .payload = {} },
        );
        config.vdc.limit.lower = payload.lower;
        config.vdc.limit.upper = payload.upper;
    }
    {
        sequence += 1;
        const payload = try command.transceiveMessage(
            .get_max_current,
            .set_max_current,
            .{ .sequence = sequence, .payload = {} },
        );
        config.motor.max_current = payload;
    }
    {
        sequence += 1;
        const payload = try command.transceiveMessage(
            .get_continuous_current,
            .set_continuous_current,
            .{ .sequence = sequence, .payload = {} },
        );
        config.motor.continuous_current = payload;
    }
    {
        sequence += 1;
        const payload = try command.transceiveMessage(
            .get_rs,
            .set_rs,
            .{ .sequence = sequence, .payload = {} },
        );
        config.motor.rs = payload;
    }
    {
        sequence += 1;
        const payload = try command.transceiveMessage(
            .get_ls,
            .set_ls,
            .{ .sequence = sequence, .payload = {} },
        );
        config.motor.ls = payload;
    }
    {
        sequence += 1;
        const payload = try command.transceiveMessage(
            .get_kf,
            .set_kf,
            .{ .sequence = sequence, .payload = {} },
        );
        config.motor.kf = payload;
    }
    {
        sequence += 1;
        const payload = try command.transceiveMessage(
            .get_kbm,
            .set_kbm,
            .{ .sequence = sequence, .payload = {} },
        );
        config.motor.kbm = payload;
    }

    for (0..drivercom.Config.MAX_AXES) |_i| {
        const i: u16 = @intCast(_i);
        {
            sequence += 1;
            const payload = try command.transceiveMessage(
                .get_current_gain_p,
                .set_current_gain_p,
                .{ .sequence = sequence, .payload = i },
            );
            if (payload.axis != i) {
                std.log.err(
                    "{s} for axis {d} received axis {d}",
                    .{ @tagName(.get_current_gain_p), i, payload.axis },
                );
                return error.CommunicationFailure;
            }
            config.axes[i].current_gain.p = payload.p;
        }
        {
            sequence += 1;
            const payload = try command.transceiveMessage(
                .get_current_gain_i,
                .set_current_gain_i,
                .{ .sequence = sequence, .payload = i },
            );
            if (payload.axis != i) {
                std.log.err(
                    "{s} for axis {d} received axis {d}",
                    .{ @tagName(.get_current_gain_i), i, payload.axis },
                );
                return error.CommunicationFailure;
            }
            config.axes[i].current_gain.i = payload.i;
        }
        {
            sequence += 1;
            const payload = try command.transceiveMessage(
                .get_current_gain_denominator,
                .set_current_gain_denominator,
                .{ .sequence = sequence, .payload = i },
            );
            if (payload.axis != i) {
                std.log.err(
                    "{s} for axis {d} received axis {d}",
                    .{
                        @tagName(.get_current_gain_denominator),
                        i,
                        payload.axis,
                    },
                );
                return error.CommunicationFailure;
            }
            config.axes[i].current_gain.denominator = payload.denominator;
        }
        {
            sequence += 1;
            const payload = try command.transceiveMessage(
                .get_velocity_gain_p,
                .set_velocity_gain_p,
                .{ .sequence = sequence, .payload = i },
            );
            if (payload.axis != i) {
                std.log.err(
                    "{s} for axis {d} received axis {d}",
                    .{ @tagName(.get_velocity_gain_p), i, payload.axis },
                );
                return error.CommunicationFailure;
            }
            config.axes[i].velocity_gain.p = payload.p;
        }
        {
            sequence += 1;
            const payload = try command.transceiveMessage(
                .get_velocity_gain_i,
                .set_velocity_gain_i,
                .{ .sequence = sequence, .payload = i },
            );
            if (payload.axis != i) {
                std.log.err(
                    "{s} for axis {d} received axis {d}",
                    .{ @tagName(.get_velocity_gain_i), i, payload.axis },
                );
                return error.CommunicationFailure;
            }
            config.axes[i].velocity_gain.i = payload.i;
        }
        {
            sequence += 1;
            const payload = try command.transceiveMessage(
                .get_velocity_gain_denominator,
                .set_velocity_gain_denominator,
                .{ .sequence = sequence, .payload = i },
            );
            if (payload.axis != i) {
                std.log.err(
                    "{s} for axis {d} received axis {d}",
                    .{
                        @tagName(.get_velocity_gain_denominator),
                        i,
                        payload.axis,
                    },
                );
                return error.CommunicationFailure;
            }
            config.axes[i].velocity_gain.denominator = payload.denominator;
        }
        {
            sequence += 1;
            const payload = try command.transceiveMessage(
                .get_velocity_gain_denominator_pi,
                .set_velocity_gain_denominator_pi,
                .{ .sequence = sequence, .payload = i },
            );
            if (payload.axis != i) {
                std.log.err(
                    "{s} for axis {d} received axis {d}",
                    .{
                        @tagName(.get_velocity_gain_denominator_pi),
                        i,
                        payload.axis,
                    },
                );
                return error.CommunicationFailure;
            }
            config.axes[i].velocity_gain.denominator_pi = payload.denominator;
        }
        {
            sequence += 1;
            const payload = try command.transceiveMessage(
                .get_position_gain_p,
                .set_position_gain_p,
                .{ .sequence = sequence, .payload = i },
            );
            if (payload.axis != i) {
                std.log.err(
                    "{s} for axis {d} received axis {d}",
                    .{ @tagName(.get_position_gain_p), i, payload.axis },
                );
                return error.CommunicationFailure;
            }
            config.axes[i].position_gain.p = payload.p;
        }
        {
            sequence += 1;
            const payload = try command.transceiveMessage(
                .get_position_gain_denominator,
                .set_position_gain_denominator,
                .{ .sequence = sequence, .payload = i },
            );
            if (payload.axis != i) {
                std.log.err(
                    "{s} for axis {d} received axis {d}",
                    .{
                        @tagName(.get_position_gain_denominator),
                        i,
                        payload.axis,
                    },
                );
                return error.CommunicationFailure;
            }
            config.axes[i].position_gain.denominator = payload.denominator;
        }
        {
            sequence += 1;
            const payload = try command.transceiveMessage(
                .get_in_position_threshold,
                .set_in_position_threshold,
                .{ .sequence = sequence, .payload = i },
            );
            if (payload.axis != i) {
                std.log.err(
                    "{s} for axis {d} received axis {d}",
                    .{
                        @tagName(.get_in_position_threshold),
                        i,
                        payload.axis,
                    },
                );
                return error.CommunicationFailure;
            }
            config.axes[i].in_position_threshold = payload.threshold;
        }
        {
            sequence += 1;
            const payload = try command.transceiveMessage(
                .get_base_position,
                .set_base_position,
                .{ .sequence = sequence, .payload = i },
            );
            if (payload.axis != i) {
                std.log.err(
                    "{s} for axis {d} received axis {d}",
                    .{ @tagName(.get_base_position), i, payload.axis },
                );
                return error.CommunicationFailure;
            }
            config.axes[i].base_position = payload.position;
        }
        {
            sequence += 1;
            const payload = try command.transceiveMessage(
                .get_back_sensor_off,
                .set_back_sensor_off,
                .{ .sequence = sequence, .payload = i },
            );
            if (payload.axis != i) {
                std.log.err(
                    "{s} for axis {d} received axis {d}",
                    .{ @tagName(.get_back_sensor_off), i, payload.axis },
                );
                return error.CommunicationFailure;
            }
            config.axes[i].back_sensor_off.position = payload.position;
            config.axes[i].back_sensor_off.section_count =
                payload.section_count;
        }
        {
            sequence += 1;
            const payload = try command.transceiveMessage(
                .get_front_sensor_off,
                .set_front_sensor_off,
                .{ .sequence = sequence, .payload = i },
            );
            if (payload.axis != i) {
                std.log.err(
                    "{s} for axis {d} received axis {d}",
                    .{ @tagName(.get_front_sensor_off), i, payload.axis },
                );
                return error.CommunicationFailure;
            }
            config.axes[i].front_sensor_off.position = payload.position;
            config.axes[i].front_sensor_off.section_count =
                payload.section_count;
        }
    }

    for (0..drivercom.Config.MAX_AXES * 2) |_i| {
        const i: u16 = @intCast(_i);
        {
            sequence += 1;
            const payload = try command.transceiveMessage(
                .get_calibrated_magnet_length_backward,
                .set_calibrated_magnet_length_backward,
                .{ .sequence = sequence, .payload = i },
            );
            if (payload.sensor != i) {
                std.log.err(
                    "{s} for sensor {d} received axis {d}",
                    .{
                        @tagName(.get_calibrated_magnet_length_backward),
                        i,
                        payload.sensor,
                    },
                );
                return error.CommunicationFailure;
            }
            config.hall_sensors[i].calibrated_magnet_length.backward =
                payload.length;
        }
        {
            sequence += 1;
            const payload = try command.transceiveMessage(
                .get_calibrated_magnet_length_forward,
                .set_calibrated_magnet_length_forward,
                .{ .sequence = sequence, .payload = i },
            );
            if (payload.sensor != i) {
                std.log.err(
                    "{s} for sensor {d} received axis {d}",
                    .{
                        @tagName(.get_calibrated_magnet_length_forward),
                        i,
                        payload.sensor,
                    },
                );
                return error.CommunicationFailure;
            }
            config.hall_sensors[i].calibrated_magnet_length.forward =
                payload.length;
        }
        {
            sequence += 1;
            const payload = try command.transceiveMessage(
                .get_ignore_distance_backward,
                .set_ignore_distance_backward,
                .{ .sequence = sequence, .payload = i },
            );
            if (payload.sensor != i) {
                std.log.err(
                    "{s} for sensor {d} received axis {d}",
                    .{
                        @tagName(.get_ignore_distance_backward),
                        i,
                        payload.sensor,
                    },
                );
                return error.CommunicationFailure;
            }
            config.hall_sensors[i].ignore_distance.backward =
                payload.distance;
        }
        {
            sequence += 1;
            const payload = try command.transceiveMessage(
                .get_ignore_distance_forward,
                .set_ignore_distance_forward,
                .{ .sequence = sequence, .payload = i },
            );
            if (payload.sensor != i) {
                std.log.err(
                    "{s} for sensor {d} received axis {d}",
                    .{
                        @tagName(.get_ignore_distance_forward),
                        i,
                        payload.sensor,
                    },
                );
                return error.CommunicationFailure;
            }
            config.hall_sensors[i].ignore_distance.forward = payload.distance;
        }
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    if (self.file) |f| {
        var file = try std.fs.cwd().createFile(f, .{});
        defer file.close();

        try std.json.stringify(
            config,
            .{ .whitespace = .indent_2 },
            file.writer(),
        );
    }
    try std.json.stringify(config, .{ .whitespace = .indent_2 }, stdout);
    try stdout.writeByte('\n');
}
