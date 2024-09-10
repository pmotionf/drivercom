const std = @import("std");

const Config = @import("Config.zig");

pub const Message = extern struct {
    kind: Kind,
    sequence: u16,
    _payload: extern union {
        response: void,
        ping: u32,
        start_sequence: void,
        end_sequence: void,
        save_config: void,
        get_id_station: void,
        set_id_station: extern struct {
            id: u16,
            station: u16,
        },
        get_system_flags: void,
        set_system_flags: packed struct {
            flags: Config.SystemFlags,
            _reserved: u9 = 0,
        },
        get_magnet: void,
        set_magnet: extern struct {
            pitch: f32,
            length: f32,
        },
        get_vehicle_mass: void,
        set_vehicle_mass: f32,
        get_angle_offset: void,
        set_angle_offset: f32,
        get_axis_length: void,
        set_axis_length: extern struct {
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
        set_calibration_magnet_length: extern struct {
            backward: f32,
            forward: f32,
        },
        get_voltage_target: void,
        set_voltage_target: f32,
        get_voltage_limits: void,
        set_voltage_limits: extern struct {
            lower: f32,
            upper: f32,
        },
        get_max_current: u16,
        set_max_current: extern struct {
            axis: u16,
            _: u16 = 0,
            current: f32,
        },
        get_continuous_current: u16,
        set_continuous_current: extern struct {
            axis: u16,
            _: u16 = 0,
            current: f32,
        },
        get_current_gain_p: u16,
        set_current_gain_p: extern struct {
            axis: u16,
            _: u16 = 0,
            p: f32,
        },
        get_current_gain_i: u16,
        set_current_gain_i: extern struct {
            axis: u16,
            _: u16 = 0,
            i: f32,
        },
        get_current_gain_denominator: u16,
        set_current_gain_denominator: extern struct {
            axis: u16,
            _: u16 = 0,
            denominator: u32,
        },
        get_velocity_gain_p: u16,
        set_velocity_gain_p: extern struct {
            axis: u16,
            _: u16 = 0,
            p: f32,
        },
        get_velocity_gain_i: u16,
        set_velocity_gain_i: extern struct {
            axis: u16,
            _: u16 = 0,
            i: f32,
        },
        get_velocity_gain_denominator: u16,
        set_velocity_gain_denominator: extern struct {
            axis: u16,
            _: u16 = 0,
            denominator: u32,
        },
        get_velocity_gain_denominator_pi: u16,
        set_velocity_gain_denominator_pi: extern struct {
            axis: u16,
            _: u16 = 0,
            denominator: u32,
        },
        get_position_gain_p: u16,
        set_position_gain_p: extern struct {
            axis: u16,
            _: u16 = 0,
            p: f32,
        },
        get_position_gain_denominator: u16,
        set_position_gain_denominator: extern struct {
            axis: u16,
            _: u16 = 0,
            denominator: u32,
        },
        get_in_position_threshold: u16,
        set_in_position_threshold: extern struct {
            axis: u16,
            _: u16 = 0,
            threshold: f32,
        },
        get_base_position: u16,
        set_base_position: extern struct {
            axis: u16,
            _: u16 = 0,
            position: f32,
        },
        get_back_sensor_off: u16,
        set_back_sensor_off: extern struct {
            axis: u16,
            _: u16 = 0,
            position: i16,
            section_count: i16,
        },
        get_front_sensor_off: u16,
        set_front_sensor_off: extern struct {
            axis: u16,
            _: u16 = 0,
            position: i16,
            section_count: i16,
        },
        get_rs: u16,
        set_rs: extern struct {
            axis: u16,
            _: u16 = 0,
            rs: f32,
        },
        get_ls: u16,
        set_ls: extern struct {
            axis: u16,
            _: u16 = 0,
            ls: f32,
        },
        get_kf: u16,
        set_kf: extern struct {
            axis: u16,
            _: u16 = 0,
            kf: f32,
        },
        get_kbm: u16,
        set_kbm: extern struct {
            axis: u16,
            _: u16 = 0,
            kbm: f32,
        },
        get_calibrated_magnet_length_backward: u16,
        set_calibrated_magnet_length_backward: extern struct {
            sensor: u16,
            _: u16 = 0,
            length: f32,
        },
        get_calibrated_magnet_length_forward: u16,
        set_calibrated_magnet_length_forward: extern struct {
            sensor: u16,
            _: u16 = 0,
            length: f32,
        },
        u8: [8]u8,
    } = .{ .u8 = .{0} ** 8 },
    cycle: u16 = 0,
    _120: u8 = 0,
    bcc: u8 = undefined,

    pub const Kind = enum(u16) {
        response = 0x1,
        ping = 0x2,
        save_config = 0x3,
        start_sequence = 0x4,
        end_sequence = 0x5,

        get_id_station = 0x10,
        set_id_station = 0x11,
        get_system_flags = 0x12,
        set_system_flags = 0x13,
        get_magnet = 0x14,
        set_magnet = 0x15,
        get_vehicle_mass = 0x16,
        set_vehicle_mass = 0x17,
        get_angle_offset = 0x18,
        set_angle_offset = 0x19,
        get_axis_length = 0x1A,
        set_axis_length = 0x1B,
        get_calibrated_home = 0x1C,
        set_calibrated_home = 0x1D,
        get_total_axes = 0x1E,
        set_total_axes = 0x1F,
        get_warmup_voltage = 0x20,
        set_warmup_voltage = 0x21,
        get_calibration_magnet_length = 0x22,
        set_calibration_magnet_length = 0x23,
        get_voltage_target = 0x24,
        set_voltage_target = 0x25,
        get_voltage_limits = 0x26,
        set_voltage_limits = 0x27,

        // Per-axis messages.
        get_max_current = 0x30,
        set_max_current = 0x31,
        get_continuous_current = 0x32,
        set_continuous_current = 0x33,
        get_current_gain_p = 0x34,
        set_current_gain_p = 0x35,
        get_current_gain_i = 0x36,
        set_current_gain_i = 0x37,
        get_current_gain_denominator = 0x38,
        set_current_gain_denominator = 0x39,
        get_velocity_gain_p = 0x3A,
        set_velocity_gain_p = 0x3B,
        get_velocity_gain_i = 0x3C,
        set_velocity_gain_i = 0x3D,
        get_velocity_gain_denominator = 0x3E,
        set_velocity_gain_denominator = 0x3F,
        get_velocity_gain_denominator_pi = 0x40,
        set_velocity_gain_denominator_pi = 0x41,
        get_position_gain_p = 0x42,
        set_position_gain_p = 0x43,
        get_position_gain_denominator = 0x44,
        set_position_gain_denominator = 0x45,
        get_in_position_threshold = 0x46,
        set_in_position_threshold = 0x47,
        get_base_position = 0x48,
        set_base_position = 0x49,
        get_back_sensor_off = 0x4A,
        set_back_sensor_off = 0x4B,
        get_front_sensor_off = 0x4C,
        set_front_sensor_off = 0x4D,
        get_rs = 0x4E,
        set_rs = 0x4F,
        get_ls = 0x50,
        set_ls = 0x51,
        get_kf = 0x52,
        set_kf = 0x53,
        get_kbm = 0x54,
        set_kbm = 0x55,

        // Per-hall-sensor messages.
        get_calibrated_magnet_length_backward = 0x60,
        set_calibrated_magnet_length_backward = 0x61,
        get_calibrated_magnet_length_forward = 0x62,
        set_calibrated_magnet_length_forward = 0x63,
        _,

        pub fn Payload(self: Kind) type {
            return switch (self) {
                inline else => b: {
                    const msg: Message = undefined;
                    break :b @TypeOf(@field(msg._payload, @tagName(self)));
                },
            };
        }
    };

    pub fn init(
        comptime kind: Kind,
        sequence: u16,
        p: kind.Payload(),
    ) Message {
        return switch (kind) {
            inline else => b: {
                var msg: Message = .{
                    .kind = kind,
                    .sequence = sequence,
                };
                @field(msg._payload, @tagName(kind)) = p;
                msg.bcc = msg.getBcc();
                break :b msg;
            },
        };
    }

    pub fn payload(self: *const Message, comptime kind: Kind) kind.Payload() {
        return switch (kind) {
            inline else => @field(self._payload, @tagName(kind)),
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
