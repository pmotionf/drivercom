const std = @import("std");

const Config = @import("Config.zig");
const Log = @import("Log.zig");

pub const Message = packed struct {
    kind: Kind,
    sequence: u16,
    _payload: u64,
    cycle: u16 = 0,
    _120: u8 = 0,
    bcc: u8 = undefined,

    pub const Payload = extern union {
        response: void,
        ping: u32,
        save_config: void,
        firmware_version: extern struct {
            major: u16 = 0,
            minor: u16 = 0,
            patch: u16 = 0,
        },
        start_sequence: void,
        end_sequence: void,
        get_id_station: void,
        set_id_station: packed struct {
            id: u16,
            station: u16,
        },
        get_system_flags: void,
        set_system_flags: packed struct(u16) {
            flags: Config.SystemFlags,
            _reserved: u6 = 0,
        },
        get_magnet: void,
        set_magnet: packed struct {
            pitch: f32,
            length: f32,
        },
        get_vehicle_mass: void,
        set_vehicle_mass: f32,
        get_angle_offset: void,
        set_angle_offset: f32,
        get_axis_length: void,
        set_axis_length: packed struct {
            axis_length: f32,
            motor_length: f32,
        },
        get_calibrated_home: void,
        set_calibrated_home: f32,
        get_total_axes: void,
        set_total_axes: u16,
        get_warmup_voltage: void,
        set_warmup_voltage: f32,
        get_calibration_magnet_length: void,
        set_calibration_magnet_length: packed struct {
            backward: f32,
            forward: f32,
        },
        get_voltage_target: void,
        set_voltage_target: f32,
        get_voltage_limits: void,
        set_voltage_limits: packed struct {
            lower: f32,
            upper: f32,
        },
        get_max_current: void,
        set_max_current: f32,
        get_continuous_current: void,
        set_continuous_current: f32,
        get_current_gain_p: u16,
        set_current_gain_p: packed struct {
            axis: u16,
            _: u16 = 0,
            p: f32,
        },
        get_current_gain_i: u16,
        set_current_gain_i: packed struct {
            axis: u16,
            _: u16 = 0,
            i: f32,
        },
        get_current_gain_denominator: u16,
        set_current_gain_denominator: packed struct {
            axis: u16,
            _: u16 = 0,
            denominator: u32,
        },
        get_velocity_gain_p: u16,
        set_velocity_gain_p: packed struct {
            axis: u16,
            _: u16 = 0,
            p: f32,
        },
        get_velocity_gain_i: u16,
        set_velocity_gain_i: packed struct {
            axis: u16,
            _: u16 = 0,
            i: f32,
        },
        get_velocity_gain_denominator: u16,
        set_velocity_gain_denominator: packed struct {
            axis: u16,
            _: u16 = 0,
            denominator: u32,
        },
        get_velocity_gain_denominator_pi: u16,
        set_velocity_gain_denominator_pi: packed struct {
            axis: u16,
            _: u16 = 0,
            denominator: u32,
        },
        get_position_gain_p: u16,
        set_position_gain_p: packed struct {
            axis: u16,
            _: u16 = 0,
            p: f32,
        },
        get_position_gain_denominator: u16,
        set_position_gain_denominator: packed struct {
            axis: u16,
            _: u16 = 0,
            denominator: u32,
        },
        get_in_position_threshold: u16,
        set_in_position_threshold: packed struct {
            axis: u16,
            _: u16 = 0,
            threshold: f32,
        },
        get_base_position: u16,
        set_base_position: packed struct {
            axis: u16,
            _: u16 = 0,
            position: f32,
        },
        get_back_sensor_off: u16,
        set_back_sensor_off: packed struct {
            axis: u16,
            _: u16 = 0,
            position: i16,
            section_count: i16,
        },
        get_front_sensor_off: u16,
        set_front_sensor_off: packed struct {
            axis: u16,
            _: u16 = 0,
            position: i16,
            section_count: i16,
        },
        get_rs: void,
        set_rs: f32,
        get_ls: void,
        set_ls: f32,
        get_kf: void,
        set_kf: f32,
        get_kbm: void,
        set_kbm: f32,
        get_calibrated_magnet_length_backward: u16,
        set_calibrated_magnet_length_backward: packed struct {
            sensor: u16,
            _: u16 = 0,
            length: f32,
        },
        get_calibrated_magnet_length_forward: u16,
        set_calibrated_magnet_length_forward: packed struct {
            sensor: u16,
            _: u16 = 0,
            length: f32,
        },
        get_ignore_distance_backward: u16,
        set_ignore_distance_backward: packed struct {
            sensor: u16,
            _: u16 = 0,
            distance: f32,
        },
        get_ignore_distance_forward: u16,
        set_ignore_distance_forward: packed struct {
            sensor: u16,
            _: u16 = 0,
            distance: f32,
        },
        log_start: void,
        log_stop: void,
        log_status: packed struct {
            status: Log.Status,
            _: u30 = 0,
            cycles_completed: u32,
        },
        log_get_cycles: void,
        log_set_cycles: u32,
        log_get_conf: void,
        log_set_conf: Log.Config,
        log_add_conf: Log.Config,
        log_remove_conf: Log.Config,
        log_get_axis: void,
        log_set_axis: packed struct(u16) {
            axis1: bool,
            axis2: bool,
            axis3: bool,
            _: u13 = 0,
        },
        log_get_vehicles: void,
        log_set_vehicles: [4]u16,
        log_get_sensors: void,
        log_set_sensors: packed struct(u16) {
            sensor1: bool,
            sensor2: bool,
            sensor3: bool,
            sensor4: bool,
            sensor5: bool,
            sensor6: bool,
            _: u10 = 0,
        },
        log_get_start: void,
        log_set_start: packed struct {
            vehicle1: u12,
            start: Log.Start,
            _: u1 = 0,
            vehicle2: u12,
            hall_sensor_1: bool = false,
            hall_sensor_2: bool = false,
            start_condition_and: bool = false,
            start_condition_or: bool = false,
            vehicle3: u12,
            hall_sensor_3: bool = false,
            hall_sensor_4: bool = false,
            _1: u2 = 0,
            vehicle4: u12,
            hall_sensor_5: bool = false,
            hall_sensor_6: bool = false,
            _2: u2 = 0,
        },
        log_get: packed struct {
            cycle: u24,
            data: Log.Tag,
            id: u3,
            cycles: u32,
        },
        u8: [8]u8,
    };

    pub const Kind = b: {
        var result: std.builtin.Type.Enum = .{
            .tag_type = u16,
            .fields = &.{},
            .decls = &.{},
            .is_exhaustive = false,
        };

        const ti = @typeInfo(Payload).@"union";
        var val: u16 = 1;
        for (ti.fields) |field| {
            if (std.mem.eql(u8, "u8", field.name)) continue;
            if (std.mem.eql(u8, "get_id_station", field.name)) {
                val = 0x10;
            } else if (std.mem.eql(u8, "get_max_current", field.name)) {
                val = 0x30;
            } else if (std.mem.eql(
                u8,
                "get_calibrated_magnet_length_backward",
                field.name,
            )) {
                val = 0x60;
            } else if (std.mem.eql(u8, "log_start", field.name)) {
                val = 0x100;
            }
            result.fields = result.fields ++ .{
                std.builtin.Type.EnumField{
                    .name = field.name,
                    .value = val,
                },
            };
            val += 1;
        }

        break :b @Type(.{ .@"enum" = result });
    };

    pub fn PayloadType(comptime kind: Kind) type {
        const ti = @typeInfo(Payload).@"union";
        inline for (ti.fields) |field| {
            if (std.mem.eql(u8, field.name, @tagName(kind))) {
                return field.type;
            }
        }
    }

    pub fn init(
        comptime kind: Kind,
        sequence: u16,
        p: PayloadType(kind),
    ) Message {
        return switch (kind) {
            inline else => b: {
                var msg: Message = .{
                    .kind = kind,
                    .sequence = sequence,
                    ._payload = undefined,
                };
                var _payload: Payload = .{ .u8 = .{0} ** 8 };
                @field(_payload, @tagName(kind)) = p;
                msg._payload = @bitCast(_payload);
                msg.bcc = msg.getBcc();
                break :b msg;
            },
        };
    }

    pub fn payload(
        self: *const Message,
        comptime kind: Kind,
    ) PayloadType(kind) {
        const _payload: Payload = @bitCast(self._payload);
        return switch (kind) {
            inline else => @field(_payload, @tagName(kind)),
        };
    }

    pub fn getBcc(self: *const Message) u8 {
        const bytes: []const u8 = std.mem.asBytes(self);
        var bcc: u8 = 0;
        for (bytes[0..15]) |b| {
            bcc ^= b;
        }
        return bcc;
    }
};

comptime {
    if (@sizeOf(Message) != 16) {
        @compileError(std.fmt.comptimePrint(
            "Message is invalid size {}",
            .{@sizeOf(Message)},
        ));
    }
}
