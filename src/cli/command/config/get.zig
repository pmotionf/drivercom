pub const id = @import("get/id.zig");
pub const neighbor = @import("get/neighbor.zig");

const std = @import("std");
const cli = @import("../../../cli.zig");
const command = @import("../../command.zig");
const args = @import("args");
const drivercom = @import("drivercom");
const yaml = @import("yaml");

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
        const msg = drivercom.Message.init(.get_id_station, sequence, {});
        try command.sendMessage(&msg);
        const req = try command.readMessage();
        if (req.kind == .set_id_station and req.sequence == sequence) {
            sequence += 1;
            const payload = req.payload(.set_id_station);
            config.id = payload.id;
            config.station_id = payload.station;
        } else {
            std.log.err("received invalid response: {any}", .{req});
            return error.CommunicationFailure;
        }
    }

    {
        const msg = drivercom.Message.init(.get_system_flags, sequence, {});
        try command.sendMessage(&msg);
        const req = try command.readMessage();
        if (req.kind == .set_system_flags and req.sequence == sequence) {
            sequence += 1;
            const payload = req.payload(.set_system_flags);
            config.flags = payload.flags;
        } else {
            std.log.err("received invalid response: {any}", .{req});
            return error.CommunicationFailure;
        }
    }

    {
        const msg = drivercom.Message.init(.get_magnet, sequence, {});
        try command.sendMessage(&msg);
        const req = try command.readMessage();
        if (req.kind == .set_magnet and req.sequence == sequence) {
            sequence += 1;
            const payload = req.payload(.set_magnet);
            config.magnet.pitch = payload.pitch;
            config.magnet.length = payload.length;
        } else {
            std.log.err("received invalid response: {any}", .{req});
            return error.CommunicationFailure;
        }
    }

    {
        const msg = drivercom.Message.init(.get_vehicle_mass, sequence, {});
        try command.sendMessage(&msg);
        const req = try command.readMessage();
        if (req.kind == .set_vehicle_mass and req.sequence == sequence) {
            sequence += 1;
            const payload = req.payload(.set_vehicle_mass);
            config.vehicle_mass = payload;
        } else {
            std.log.err("received invalid response: {any}", .{req});
            return error.CommunicationFailure;
        }
    }

    while (true) {
        const msg = drivercom.Message.init(.get_angle_offset, sequence, {});
        try command.sendMessage(&msg);
        const req = try command.readMessage();
        if (req.kind == .set_angle_offset and req.sequence == sequence) {
            sequence += 1;
            const payload = req.payload(.set_angle_offset);
            config.mechanical_angle_offset = payload;
            break;
        }
    }

    while (true) {
        const msg = drivercom.Message.init(.get_axis_length, sequence, {});
        try command.sendMessage(&msg);
        const req = try command.readMessage();
        if (req.kind == .set_axis_length and req.sequence == sequence) {
            sequence += 1;
            const payload = req.payload(.set_axis_length);
            config.axis_length = payload.axis_length;
            config.motor_length = payload.motor_length;
            break;
        }
    }

    while (true) {
        const msg = drivercom.Message.init(.get_calibrated_home, sequence, {});
        try command.sendMessage(&msg);
        const req = try command.readMessage();
        if (req.kind == .set_calibrated_home and req.sequence == sequence) {
            sequence += 1;
            const payload = req.payload(.set_calibrated_home);
            config.calibrated_home_position = payload;
            break;
        }
    }

    while (true) {
        const msg = drivercom.Message.init(.get_total_axes, sequence, {});
        try command.sendMessage(&msg);
        const req = try command.readMessage();
        if (req.kind == .set_total_axes and req.sequence == sequence) {
            sequence += 1;
            const payload = req.payload(.set_total_axes);
            config.total_axes = payload;
            break;
        }
    }

    while (true) {
        const msg = drivercom.Message.init(.get_warmup_voltage, sequence, {});
        try command.sendMessage(&msg);
        const req = try command.readMessage();
        if (req.kind == .set_warmup_voltage and req.sequence == sequence) {
            sequence += 1;
            const payload = req.payload(.set_warmup_voltage);
            config.warmup_voltage_reference = payload;
            break;
        }
    }

    while (true) {
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
            config.calibration_magnet_length.backward = payload.backward;
            config.calibration_magnet_length.forward = payload.forward;
            break;
        }
    }

    while (true) {
        const msg = drivercom.Message.init(.get_voltage_target, sequence, {});
        try command.sendMessage(&msg);
        const req = try command.readMessage();
        if (req.kind == .set_voltage_target and req.sequence == sequence) {
            sequence += 1;
            const payload = req.payload(.set_voltage_target);
            config.vdc.target = payload;
            break;
        }
    }

    while (true) {
        const msg = drivercom.Message.init(.get_voltage_limits, sequence, {});
        try command.sendMessage(&msg);
        const req = try command.readMessage();
        if (req.kind == .set_voltage_limits and req.sequence == sequence) {
            sequence += 1;
            const payload = req.payload(.set_voltage_limits);
            config.vdc.limit.lower = payload.lower;
            config.vdc.limit.upper = payload.upper;
            break;
        }
    }

    for (0..drivercom.Config.MAX_AXES) |_i| {
        const i: u16 = @intCast(_i);

        while (true) {
            const msg = drivercom.Message.init(.get_max_current, sequence, i);
            try command.sendMessage(&msg);
            const req = try command.readMessage();
            if (req.kind == .set_max_current and req.sequence == sequence) {
                const payload = req.payload(.set_max_current);
                if (payload.axis != i) continue;
                sequence += 1;
                config.axes[i].max_current = payload.current;
                break;
            }
        }

        while (true) {
            const msg = drivercom.Message.init(
                .get_continuous_current,
                sequence,
                i,
            );
            try command.sendMessage(&msg);
            const req = try command.readMessage();
            if (req.kind == .set_continuous_current and
                req.sequence == sequence)
            {
                const payload = req.payload(.set_continuous_current);
                if (payload.axis != i) continue;
                sequence += 1;
                config.axes[i].continuous_current = payload.current;
                break;
            }
        }

        while (true) {
            const msg = drivercom.Message.init(
                .get_current_gain_p,
                sequence,
                i,
            );
            try command.sendMessage(&msg);
            const req = try command.readMessage();
            if (req.kind == .set_current_gain_p and req.sequence == sequence) {
                const payload = req.payload(.set_current_gain_p);
                if (payload.axis != i) continue;
                sequence += 1;
                config.axes[i].current_gain.p = payload.p;
                break;
            }
        }

        while (true) {
            const msg = drivercom.Message.init(
                .get_current_gain_i,
                sequence,
                i,
            );
            try command.sendMessage(&msg);
            const req = try command.readMessage();
            if (req.kind == .set_current_gain_i and req.sequence == sequence) {
                const payload = req.payload(.set_current_gain_i);
                if (payload.axis != i) continue;
                sequence += 1;
                config.axes[i].current_gain.i = payload.i;
                break;
            }
        }

        while (true) {
            const msg = drivercom.Message.init(
                .get_current_gain_denominator,
                sequence,
                i,
            );
            try command.sendMessage(&msg);
            const req = try command.readMessage();
            if (req.kind == .set_current_gain_denominator and
                req.sequence == sequence)
            {
                const payload = req.payload(.set_current_gain_denominator);
                if (payload.axis != i) continue;
                sequence += 1;
                config.axes[i].current_gain.denominator = payload.denominator;
                break;
            }
        }

        while (true) {
            const msg = drivercom.Message.init(
                .get_velocity_gain_p,
                sequence,
                i,
            );
            try command.sendMessage(&msg);
            const req = try command.readMessage();
            if (req.kind == .set_velocity_gain_p and
                req.sequence == sequence)
            {
                const payload = req.payload(.set_velocity_gain_p);
                if (payload.axis != i) continue;
                sequence += 1;
                config.axes[i].velocity_gain.p = payload.p;
                break;
            }
        }

        while (true) {
            const msg = drivercom.Message.init(
                .get_velocity_gain_i,
                sequence,
                i,
            );
            try command.sendMessage(&msg);
            const req = try command.readMessage();
            if (req.kind == .set_velocity_gain_i and
                req.sequence == sequence)
            {
                const payload = req.payload(.set_velocity_gain_i);
                if (payload.axis != i) continue;
                sequence += 1;
                config.axes[i].velocity_gain.i = payload.i;
                break;
            }
        }

        while (true) {
            const msg = drivercom.Message.init(
                .get_velocity_gain_denominator,
                sequence,
                i,
            );
            try command.sendMessage(&msg);
            const req = try command.readMessage();
            if (req.kind == .set_velocity_gain_denominator and
                req.sequence == sequence)
            {
                const payload = req.payload(.set_velocity_gain_denominator);
                if (payload.axis != i) continue;
                sequence += 1;
                config.axes[i].velocity_gain.denominator = payload.denominator;
                break;
            }
        }

        while (true) {
            const msg = drivercom.Message.init(
                .get_velocity_gain_denominator_pi,
                sequence,
                i,
            );
            try command.sendMessage(&msg);
            const req = try command.readMessage();
            if (req.kind == .set_velocity_gain_denominator_pi and
                req.sequence == sequence)
            {
                const payload = req.payload(.set_velocity_gain_denominator_pi);
                if (payload.axis != i) continue;
                sequence += 1;
                config.axes[i].velocity_gain.denominator_pi =
                    payload.denominator;
                break;
            }
        }

        while (true) {
            const msg = drivercom.Message.init(
                .get_position_gain_p,
                sequence,
                i,
            );
            try command.sendMessage(&msg);
            const req = try command.readMessage();
            if (req.kind == .set_position_gain_p and
                req.sequence == sequence)
            {
                const payload = req.payload(.set_position_gain_p);
                if (payload.axis != i) continue;
                sequence += 1;
                config.axes[i].position_gain.p = payload.p;
                break;
            }
        }

        while (true) {
            const msg = drivercom.Message.init(
                .get_position_gain_denominator,
                sequence,
                i,
            );
            try command.sendMessage(&msg);
            const req = try command.readMessage();
            if (req.kind == .set_position_gain_denominator and
                req.sequence == sequence)
            {
                const payload = req.payload(.set_position_gain_denominator);
                if (payload.axis != i) continue;
                sequence += 1;
                config.axes[i].position_gain.denominator = payload.denominator;
                break;
            }
        }

        while (true) {
            const msg = drivercom.Message.init(
                .get_in_position_threshold,
                sequence,
                i,
            );
            try command.sendMessage(&msg);
            const req = try command.readMessage();
            if (req.kind == .set_in_position_threshold and
                req.sequence == sequence)
            {
                const payload = req.payload(.set_in_position_threshold);
                if (payload.axis != i) continue;
                sequence += 1;
                config.axes[i].in_position_threshold = payload.threshold;
                break;
            }
        }

        while (true) {
            const msg = drivercom.Message.init(
                .get_base_position,
                sequence,
                i,
            );
            try command.sendMessage(&msg);
            const req = try command.readMessage();
            if (req.kind == .set_base_position and req.sequence == sequence) {
                const payload = req.payload(.set_base_position);
                if (payload.axis != i) continue;
                sequence += 1;
                config.axes[i].base_position = payload.position;
                break;
            }
        }

        while (true) {
            const msg = drivercom.Message.init(
                .get_back_sensor_off,
                sequence,
                i,
            );
            try command.sendMessage(&msg);
            const req = try command.readMessage();
            if (req.kind == .set_back_sensor_off and
                req.sequence == sequence)
            {
                const payload = req.payload(.set_back_sensor_off);
                if (payload.axis != i) continue;
                sequence += 1;
                config.axes[i].back_sensor_off.position = payload.position;
                config.axes[i].back_sensor_off.section_count =
                    payload.section_count;
                break;
            }
        }

        while (true) {
            const msg = drivercom.Message.init(
                .get_front_sensor_off,
                sequence,
                i,
            );
            try command.sendMessage(&msg);
            const req = try command.readMessage();
            if (req.kind == .set_front_sensor_off and
                req.sequence == sequence)
            {
                const payload = req.payload(.set_front_sensor_off);
                if (payload.axis != i) continue;
                sequence += 1;
                config.axes[i].front_sensor_off.position = payload.position;
                config.axes[i].front_sensor_off.section_count =
                    payload.section_count;
                break;
            }
        }

        while (true) {
            const msg = drivercom.Message.init(.get_rs, sequence, i);
            try command.sendMessage(&msg);
            const req = try command.readMessage();
            if (req.kind == .set_rs and req.sequence == sequence) {
                const payload = req.payload(.set_rs);
                if (payload.axis != i) continue;
                sequence += 1;
                config.axes[i].rs = payload.rs;
                break;
            }
        }

        while (true) {
            const msg = drivercom.Message.init(.get_ls, sequence, i);
            try command.sendMessage(&msg);
            const req = try command.readMessage();
            if (req.kind == .set_ls and req.sequence == sequence) {
                const payload = req.payload(.set_ls);
                if (payload.axis != i) continue;
                sequence += 1;
                config.axes[i].ls = payload.ls;
                break;
            }
        }

        while (true) {
            const msg = drivercom.Message.init(.get_kf, sequence, i);
            try command.sendMessage(&msg);
            const req = try command.readMessage();
            if (req.kind == .set_kf and req.sequence == sequence) {
                const payload = req.payload(.set_kf);
                if (payload.axis != i) continue;
                sequence += 1;
                config.axes[i].kf = payload.kf;
                break;
            }
        }

        while (true) {
            const msg = drivercom.Message.init(.get_kbm, sequence, i);
            try command.sendMessage(&msg);
            const req = try command.readMessage();
            if (req.kind == .set_kbm and req.sequence == sequence) {
                const payload = req.payload(.set_kbm);
                if (payload.axis != i) continue;
                sequence += 1;
                config.axes[i].kbm = payload.kbm;
                break;
            }
        }
    }

    for (0..drivercom.Config.MAX_AXES * 2) |_i| {
        const i: u16 = @intCast(_i);

        while (true) {
            const msg = drivercom.Message.init(
                .get_calibrated_magnet_length_backward,
                sequence,
                i,
            );
            try command.sendMessage(&msg);
            const req = try command.readMessage();
            if (req.kind == .set_calibrated_magnet_length_backward and
                req.sequence == sequence)
            {
                const payload = req.payload(
                    .set_calibrated_magnet_length_backward,
                );
                if (payload.sensor != i) continue;
                sequence += 1;
                config.hall_sensors[i].calibrated_magnet_length.backward =
                    payload.length;
                break;
            }
        }

        while (true) {
            const msg = drivercom.Message.init(
                .get_calibrated_magnet_length_forward,
                sequence,
                i,
            );
            try command.sendMessage(&msg);
            const req = try command.readMessage();
            if (req.kind == .set_calibrated_magnet_length_forward and
                req.sequence == sequence)
            {
                const payload = req.payload(
                    .set_calibrated_magnet_length_forward,
                );
                if (payload.sensor != i) continue;
                sequence += 1;
                config.hall_sensors[i].calibrated_magnet_length.forward =
                    payload.length;
                break;
            }
        }
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    if (self.file) |f| {
        var file = try std.fs.cwd().createFile(f, .{});
        defer file.close();

        try yaml.stringify(allocator, config, file.writer());
    }
    try yaml.stringify(allocator, config, stdout);
    try stdout.writeByte('\n');
}
