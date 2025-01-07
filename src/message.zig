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
        // Configuration message name guide:
        // -----------|-------------------------------------------------------
        // `:`        | Delimiter used after `get` or `set`. E.g. `get:foo`.
        // -----------|-------------------------------------------------------
        // `<foo>`    | Denotes that a field of the message payload also named
        //            | `foo` contains the value.
        // -----------|-------------------------------------------------------
        // `|`        | Separates multiple Config fields contained within the
        //            | message payload, each field at the same level of
        //            | nesting to each other.
        // -----------|-------------------------------------------------------
        // `.`        | Denotes a Config field nested within the parent, e.g.
        //            | `foo.bar` would denote a Config field `bar` within the
        //            | Config parent field (struct) `foo`.
        // -----------|-------------------------------------------------------
        // `foo[bar]` | Indicates a Config field `foo` that is a sequence type
        //            | (array), indexed by the value contained in the message
        //            | payload field `bar`.
        // -----------|-------------------------------------------------------
        @"get:id": void,
        @"set:id": packed struct {
            driver: u16,
            station: u16,
        },
        @"get:<flags>": void,
        @"set:<flags>": packed struct(u16) {
            flags: Config.SystemFlags,
            _: u6 = 0,
        },
        @"get:magnet": void,
        @"set:magnet": packed struct {
            pitch: f32,
            length: f32,
        },
        @"get:vehicle_mass": void,
        @"set:vehicle_mass": f32,
        @"get:mechanical_angle_offset": void,
        @"set:mechanical_angle_offset": f32,
        @"get:<axis_length>|<motor_length>": void,
        @"set:<axis_length>|<motor_length>": packed struct {
            axis_length: f32,
            motor_length: f32,
        },
        @"get:calibrated_home_position": void,
        @"set:calibrated_home_position": f32,
        @"get:total_axes": void,
        @"set:total_axes": u16,
        @"get:warmup_voltage_reference": void,
        @"set:warmup_voltage_reference": f32,
        @"get:calibration_magnet_length": void,
        @"set:calibration_magnet_length": packed struct {
            backward: f32,
            forward: f32,
        },
        @"get:vdc.target": void,
        @"set:vdc.target": f32,
        @"get:vdc.limit": void,
        @"set:vdc.limit": packed struct {
            lower: f32,
            upper: f32,
        },
        @"get:arrival.threshold.position": void,
        @"set:arrival.threshold.position": f32,
        @"get:arrival.threshold.velocity": void,
        @"set:arrival.threshold.velocity": f32,
        @"get:motor.max_current": void,
        @"set:motor.max_current": f32,
        @"get:motor.continuous_current": void,
        @"set:motor.continuous_current": f32,
        @"get:axes[axis].current_gain.p": u16,
        @"set:axes[axis].current_gain.p": packed struct {
            axis: u16,
            _: u16 = 0,
            p: f32,
        },
        @"get:axes[axis].current_gain.i": u16,
        @"set:axes[axis].current_gain.i": packed struct {
            axis: u16,
            _: u16 = 0,
            i: f32,
        },
        @"get:axes[axis].current_gain.denominator": u16,
        @"set:axes[axis].current_gain.denominator": packed struct {
            axis: u16,
            _: u16 = 0,
            denominator: u32,
        },
        @"get:axes[axis].velocity_gain.p": u16,
        @"set:axes[axis].velocity_gain.p": packed struct {
            axis: u16,
            _: u16 = 0,
            p: f32,
        },
        @"get:axes[axis].velocity_gain.i": u16,
        @"set:axes[axis].velocity_gain.i": packed struct {
            axis: u16,
            _: u16 = 0,
            i: f32,
        },
        @"get:axes[axis].velocity_gain.denominator": u16,
        @"set:axes[axis].velocity_gain.denominator": packed struct {
            axis: u16,
            _: u16 = 0,
            denominator: u32,
        },
        @"get:axes[axis].velocity_gain.denominator_pi": u16,
        @"set:axes[axis].velocity_gain.denominator_pi": packed struct {
            axis: u16,
            _: u16 = 0,
            denominator_pi: u32,
        },
        @"get:axes[axis].position_gain.p": u16,
        @"set:axes[axis].position_gain.p": packed struct {
            axis: u16,
            _: u16 = 0,
            p: f32,
        },
        @"get:axes[axis].position_gain.<denominator>": u16,
        @"set:axes[axis].position_gain.<denominator>": packed struct {
            axis: u16,
            _: u16 = 0,
            denominator: u32,
        },
        @"get:axes[axis].<base_position>": u16,
        @"set:axes[axis].<base_position>": packed struct {
            axis: u16,
            _: u16 = 0,
            base_position: f32,
        },
        @"get:axes[axis].back_sensor_off": u16,
        @"set:axes[axis].back_sensor_off": packed struct {
            axis: u16,
            _: u16 = 0,
            position: i16,
            section_count: i16,
        },
        @"get:axes[axis].front_sensor_off": u16,
        @"set:axes[axis].front_sensor_off": packed struct {
            axis: u16,
            _: u16 = 0,
            position: i16,
            section_count: i16,
        },
        @"get:motor.rs": void,
        @"set:motor.rs": f32,
        @"get:motor.ls": void,
        @"set:motor.ls": f32,
        @"get:motor.kf": void,
        @"set:motor.kf": f32,
        @"get:motor.kbm": void,
        @"set:motor.kbm": f32,
        @"get:hall_sensors[sensor].calibrated_magnet_length.<backward>": u16,
        @"set:hall_sensors[sensor].calibrated_magnet_length.<backward>": packed struct {
            sensor: u16,
            _: u16 = 0,
            backward: f32,
        },
        @"get:hall_sensors[sensor].calibrated_magnet_length.<forward>": u16,
        @"set:hall_sensors[sensor].calibrated_magnet_length.<forward>": packed struct {
            sensor: u16,
            _: u16 = 0,
            forward: f32,
        },
        @"get:hall_sensors[sensor].ignore_distance.<backward>": u16,
        @"set:hall_sensors[sensor].ignore_distance.<backward>": packed struct {
            sensor: u16,
            _: u16 = 0,
            backward: f32,
        },
        @"get:hall_sensors[sensor].ignore_distance.<forward>": u16,
        @"set:hall_sensors[sensor].ignore_distance.<forward>": packed struct {
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

        /// Creates new message payload from `Config` struct. If payload kind
        /// must contain value from an indexable field in `Config` struct, a
        /// valid index must be provided.
        pub fn fromConfig(kind: std.meta.stringToEnum(comptime T: type, str: []const u8)config: Config, index: ?usize) Payload {
            // TODO
        }

        /// Creates a new `Config` struct from payload. An existing `Config`
        /// struct can be provided to fill all values not provided by the
        /// payload.
        pub fn toConfig(payload: Payload, existing_config: ?Config) Config {
            // TODO
        }
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
            if (std.mem.eql(u8, "get:id", field.name)) {
                val = 0x10;
            } else if (std.mem.eql(u8, "get:motor.max_current", field.name)) {
                val = 0x30;
            } else if (std.mem.eql(
                u8,
                "get:hall_sensors[sensor].calibrated_magnet_length.<backward>",
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

    const payload_ti = @typeInfo(Message.Payload).@"union";
    for (payload_ti.fields) |field| {
        if (field.name.len < 3) continue;
        if (!std.mem.eql(u8, "set", field.name[0..3])) continue;

        // const field_ti = @typeInfo(field.type);
    }
}
