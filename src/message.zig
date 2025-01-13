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
        firmware_version: extern struct {
            major: u16 = 0,
            minor: u16 = 0,
            patch: u16 = 0,
        },
        start_sequence: void,
        end_sequence: void,

        config_get: ConfigField,
        config_set: ConfigField,
        config_save: void,

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

        pub const ConfigField = extern struct {
            kind: Config.FieldKind,
            index: u16 = 0,
            value: extern union {
                i16: i16,
                u16: u16,
                u32: u32,
                f32: f32,
            } = undefined,

            /// Set the value from Config struct. Valid kind and (if needed)
            /// index must be provided.
            pub fn fromConfig(self: *@This(), config: Config) void {
                switch (self.kind) {
                    .id => self.value.u16 = config.id.driver,
                    .station => self.value.u16 = config.id.station,
                    .flags => self.value.u16 =
                        @as(u10, @bitCast(config.flags)),
                    .@"magnet.pitch" => self.value.f32 = config.magnet.pitch,
                    .@"magnet.length" => self.value.f32 =
                        config.magnet.length,
                    .@"carrier.mass" => self.value.f32 = config.vehicle_mass,
                    .@"carrier.arrival.threshold.position" => self.value.f32 =
                        config.arrival.threshold.position,
                    .@"carrier.arrival.threshold.velocity" => self.value.f32 =
                        config.arrival.threshold.velocity,
                    .mechanical_angle_offset => self.value.f32 =
                        config.mechanical_angle_offset,
                    .@"axis.length" => self.value.f32 = config.axis_length,
                    .@"coil.length" => self.value.f32 = config.motor.length,
                    .@"coil.max_current" => self.value.f32 =
                        config.motor.max_current,
                    .@"coil.continuous_current" => self.value.f32 =
                        config.motor.continuous_current,
                    .@"coil.rs" => self.value.f32 = config.motor.rs,
                    .@"coil.ls" => self.value.f32 = config.motor.ls,
                    .@"coil.kf" => self.value.f32 = config.motor.kf,
                    .@"coil.kbm" => self.value.f32 = config.motor.kbm,
                    .zero_position => self.value.f32 =
                        config.calibrated_home_position,
                    .line_axes => self.value.u32 = config.total_axes,
                    .warmup_voltage => self.value.f32 =
                        config.warmup_voltage_reference,
                    .@"default_magnet_length.backward" => self.value.f32 =
                        config.calibration_magnet_length.backward,
                    .@"default_magnet_length.forward" => self.value.f32 =
                        config.calibration_magnet_length.forward,
                    .@"vdc.target" => self.value.f32 = config.vdc.target,
                    .@"vdc.limit.lower" => self.value.f32 =
                        config.vdc.limit.lower,
                    .@"vdc.limit.upper" => self.value.f32 =
                        config.vdc.limit.upper,
                    .@"axes.gain.current.p" => self.value.f32 =
                        config.axes[self.index].current_gain.p,
                    .@"axes.gain.current.i" => self.value.f32 =
                        config.axes[self.index].current_gain.i,
                    .@"axes.gain.current.denominator" => self.value.u32 =
                        config.axes[self.index].current_gain.denominator,
                    .@"axes.gain.velocity.p" => self.value.f32 =
                        config.axes[self.index].velocity_gain.p,
                    .@"axes.gain.velocity.i" => self.value.f32 =
                        config.axes[self.index].velocity_gain.i,
                    .@"axes.gain.velocity.denominator" => self.value.u32 =
                        config.axes[self.index].velocity_gain.denominator,
                    .@"axes.gain.velocity.denominator_pi" => self.value.u32 =
                        config.axes[self.index].velocity_gain.denominator_pi,
                    .@"axes.gain.position.p" => self.value.f32 =
                        config.axes[self.index].position_gain.p,
                    .@"axes.gain.position.denominator" => self.value.u32 =
                        config.axes[self.index].position_gain.denominator,
                    .@"axes.base_position" => self.value.f32 =
                        config.axes[self.index].base_position,
                    .@"axes.sensor_off.back.position" => self.value.i16 =
                        config.axes[self.index].back_sensor_off.position,
                    .@"axes.sensor_off.back.section_count" => self.value.i16 =
                        config.axes[self.index].back_sensor_off.section_count,
                    .@"axes.sensor_off.front.position" => self.value.i16 =
                        config.axes[self.index].front_sensor_off.position,
                    .@"axes.sensor_off.front.section_count" => self.value.i16 =
                        config.axes[self.index].front_sensor_off.section_count,
                    .@"hall_sensors.magnet_length.backward" => self.value.f32 =
                        config.hall_sensors[self.index].calibrated_magnet_length.backward,
                    .@"hall_sensors.magnet_length.forward" => self.value.f32 =
                        config.hall_sensors[self.index].calibrated_magnet_length.forward,
                    .@"hall_sensors.ignore_distance.backward" => self.value.f32 =
                        config.hall_sensors[self.index].ignore_distance.backward,
                    .@"hall_sensors.ignore_distance.forward" => self.value.f32 =
                        config.hall_sensors[self.index].ignore_distance.forward,
                }
            }

            test fromConfig {
                var pl: Payload = .{ .config_set = .{
                    .kind = .station,
                    .value = undefined,
                } };
                const conf: Config = std.mem.zeroInit(Config, .{
                    .id = .{
                        .driver = 1,
                        .station = 13,
                    },
                });
                pl.config_set.fromConfig(conf);
                try std.testing.expectEqual(13, pl.config_set.value.u16);
            }

            /// Set the corresponding Config struct value from this message.
            pub fn setConfig(self: @This(), config: *Config) void {
                switch (self.kind) {
                    .id => config.id.driver = self.value.u16,
                    .station => config.id.station = self.value.u16,
                    .flags => config.flags = @bitCast(@as(
                        @typeInfo(Config.Flags).@"struct".backing_integer.?,
                        @truncate(self.value.u16),
                    )),
                    .@"magnet.pitch" => config.magnet.pitch = self.value.f32,
                    .@"magnet.length" => {
                        config.magnet.length = self.value.f32;
                    },
                    .@"carrier.mass" => config.vehicle_mass = self.value.f32,
                    .@"carrier.arrival.threshold.position" => {
                        config.arrival.threshold.position = self.value.f32;
                    },
                    .@"carrier.arrival.threshold.velocity" => {
                        config.arrival.threshold.velocity = self.value.f32;
                    },
                    .mechanical_angle_offset => {
                        config.mechanical_angle_offset = self.value.f32;
                    },
                    .@"axis.length" => config.axis_length = self.value.f32,
                    .@"coil.length" => config.motor.length = self.value.f32,
                    .@"coil.max_current" => {
                        config.motor.max_current = self.value.f32;
                    },
                    .@"coil.continuous_current" => {
                        config.motor.continuous_current = self.value.f32;
                    },
                    .@"coil.rs" => config.motor.rs = self.value.f32,
                    .@"coil.ls" => config.motor.ls = self.value.f32,
                    .@"coil.kf" => config.motor.kf = self.value.f32,
                    .@"coil.kbm" => config.motor.kbm = self.value.f32,
                    .zero_position => {
                        config.calibrated_home_position = self.value.f32;
                    },
                    .line_axes => config.total_axes = self.value.u32,
                    .warmup_voltage => {
                        config.warmup_voltage_reference = self.value.f32;
                    },
                    .@"default_magnet_length.backward" => {
                        config.calibration_magnet_length.backward =
                            self.value.f32;
                    },
                    .@"default_magnet_length.forward" => {
                        config.calibration_magnet_length.forward =
                            self.value.f32;
                    },
                    .@"vdc.target" => {
                        config.vdc.target = self.value.f32;
                    },
                    .@"vdc.limit.lower" => {
                        config.vdc.limit.lower = self.value.f32;
                    },
                    .@"vdc.limit.upper" => {
                        config.vdc.limit.upper = self.value.f32;
                    },
                    .@"axes.gain.current.p" => {
                        config.axes[self.index].current_gain.p =
                            self.value.f32;
                    },
                    .@"axes.gain.current.i" => {
                        config.axes[self.index].current_gain.i =
                            self.value.f32;
                    },
                    .@"axes.gain.current.denominator" => {
                        config.axes[self.index].current_gain.denominator =
                            self.value.u32;
                    },
                    .@"axes.gain.velocity.p" => {
                        config.axes[self.index].velocity_gain.p =
                            self.value.f32;
                    },
                    .@"axes.gain.velocity.i" => {
                        config.axes[self.index].velocity_gain.i =
                            self.value.f32;
                    },
                    .@"axes.gain.velocity.denominator" => {
                        config.axes[self.index].velocity_gain.denominator =
                            self.value.u32;
                    },
                    .@"axes.gain.velocity.denominator_pi" => {
                        config.axes[self.index].velocity_gain.denominator_pi =
                            self.value.u32;
                    },
                    .@"axes.gain.position.p" => {
                        config.axes[self.index].position_gain.p =
                            self.value.f32;
                    },
                    .@"axes.gain.position.denominator" => {
                        config.axes[self.index].position_gain.denominator =
                            self.value.u32;
                    },
                    .@"axes.base_position" => {
                        config.axes[self.index].base_position =
                            self.value.f32;
                    },
                    .@"axes.sensor_off.back.position" => {
                        config.axes[self.index].back_sensor_off.position =
                            self.value.i16;
                    },
                    .@"axes.sensor_off.back.section_count" => {
                        config.axes[self.index].back_sensor_off.section_count =
                            self.value.i16;
                    },
                    .@"axes.sensor_off.front.position" => {
                        config.axes[self.index].front_sensor_off.position =
                            self.value.i16;
                    },
                    .@"axes.sensor_off.front.section_count" => {
                        config.axes[self.index].front_sensor_off.section_count =
                            self.value.i16;
                    },
                    .@"hall_sensors.magnet_length.backward" => {
                        config.hall_sensors[self.index].calibrated_magnet_length.backward =
                            self.value.f32;
                    },
                    .@"hall_sensors.magnet_length.forward" => {
                        config.hall_sensors[self.index].calibrated_magnet_length.forward =
                            self.value.f32;
                    },
                    .@"hall_sensors.ignore_distance.backward" => {
                        config.hall_sensors[self.index].ignore_distance.backward =
                            self.value.f32;
                    },
                    .@"hall_sensors.ignore_distance.forward" => {
                        config.hall_sensors[self.index].ignore_distance.forward =
                            self.value.f32;
                    },
                }
            }

            test setConfig {
                var config: Config = std.mem.zeroInit(Config, .{});
                setConfig(.{
                    .kind = .station,
                    .value = .{ .u16 = 3 },
                }, &config);
                try std.testing.expectEqual(3, config.id.station);
            }
        };
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
            if (std.mem.eql(u8, "config_get", field.name)) {
                val = 0x10;
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
        @setEvalBranchQuota(2000);
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
