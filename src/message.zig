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
        get_id: void,
        set_id: packed struct {
            driver: u16,
            station: u16,
        },
        get_flags: void,
        set_flags: packed struct(u16) {
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
        get_mechanical_angle_offset: void,
        set_mechanical_angle_offset: f32,
        get_axis_length: void,
        set_axis_length: packed struct {
            axis_length: f32,
            motor_length: f32,
        },
        get_calibrated_home_position: void,
        set_calibrated_home_position: f32,
        get_total_axes: void,
        set_total_axes: u16,
        get_warmup_voltage_reference: void,
        set_warmup_voltage_reference: f32,
        get_calibration_magnet_length: void,
        set_calibration_magnet_length: packed struct {
            backward: f32,
            forward: f32,
        },
        get_vdc_target: void,
        set_vdc_target: f32,
        get_vdc_limit: void,
        set_vdc_limit: packed struct {
            lower: f32,
            upper: f32,
        },
        get_arrival_threshold_position: void,
        set_arrival_threshold_position: f32,
        get_arrival_threshold_velocity: void,
        set_arrival_threshold_velocity: f32,
        get_motor_max_current: void,
        set_motor_max_current: f32,
        get_motor_continuous_current: void,
        set_motor_continuous_current: f32,
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
            denominator_pi: u32,
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
        get_base_position: u16,
        set_base_position: packed struct {
            axis: u16,
            _: u16 = 0,
            base_position: f32,
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
        get_motor_rs: void,
        set_motor_rs: f32,
        get_motor_ls: void,
        set_motor_ls: f32,
        get_motor_kf: void,
        set_motor_kf: f32,
        get_motor_kbm: void,
        set_motor_kbm: f32,
        get_calibrated_magnet_length_backward: u16,
        set_calibrated_magnet_length_backward: packed struct {
            sensor: u16,
            _: u16 = 0,
            backward: f32,
        },
        get_calibrated_magnet_length_forward: u16,
        set_calibrated_magnet_length_forward: packed struct {
            sensor: u16,
            _: u16 = 0,
            forward: f32,
        },
        get_ignore_distance_backward: u16,
        set_ignore_distance_backward: packed struct {
            sensor: u16,
            _: u16 = 0,
            backward: f32,
        },
        get_ignore_distance_forward: u16,
        set_ignore_distance_forward: packed struct {
            sensor: u16,
            _: u16 = 0,
            forward: f32,
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
        log_get_config: void,
        log_set_config: Log.Config,
        log_add_config: Log.Config,
        log_remove_config: Log.Config,
        log_get_axis: void,
        log_set_axis: packed struct(u16) {
            axis_1: bool,
            axis_2: bool,
            axis_3: bool,
            _: u13 = 0,
        },
        log_get_vehicle: void,
        log_set_vehicle: [4]u16,
        log_get_hall_sensor: void,
        log_set_hall_sensor: packed struct(u16) {
            hall_sensor_1: bool,
            hall_sensor_2: bool,
            hall_sensor_3: bool,
            hall_sensor_4: bool,
            hall_sensor_5: bool,
            hall_sensor_6: bool,
            _: u10 = 0,
        },
        log_get_start: void,
        log_set_start: packed struct {
            vehicle_1: u12,
            kind: Log.Start,
            _: u1 = 0,
            vehicle_2: u12,
            hall_sensor_1: bool = false,
            hall_sensor_2: bool = false,
            combinator_and: bool = false,
            combinator_or: bool = false,
            vehicle_3: u12,
            hall_sensor_3: bool = false,
            hall_sensor_4: bool = false,
            _1: u2 = 0,
            vehicle_4: u12,
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
            if (std.mem.eql(u8, "get_id", field.name)) {
                val = 0x10;
            } else if (std.mem.eql(u8, "get_motor_max_current", field.name)) {
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
