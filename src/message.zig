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
            kind: Config.Field.Kind,
            index: u16 = 0,
            value: extern union {
                i16: i16,
                u16: u16,
                u32: u32,
                f32: f32,
            } = undefined,

            /// Set the value from Config struct. Valid kind and (if needed)
            /// index must be provided.
            pub fn getConfig(self: *@This(), config: Config) void {
                const field = Config.Field.fromConfig(config, self.kind, .{
                    .index = self.index,
                });
                switch (field) {
                    inline else => |value| {
                        const value_type = @TypeOf(value);
                        // Special case for flags.
                        if (comptime value_type == Config.Flags) {
                            self.value.u16 = @as(u10, @bitCast(value));
                        } else if (comptime value_type == i16) {
                            self.value.i16 = value;
                        } else if (comptime value_type == u16) {
                            self.value.u16 = value;
                        } else if (comptime value_type == u32) {
                            self.value.u32 = value;
                        } else if (comptime value_type == f32) {
                            self.value.f32 = value;
                        } else {
                            @compileError("unsupported Config field type");
                        }
                    },
                }
            }

            test getConfig {
                var pl: Payload = .{ .config_set = .{
                    .kind = .station,
                    .value = undefined,
                } };
                const conf: Config = std.mem.zeroInit(Config, .{
                    .station = 13,
                });
                pl.config_set.getConfig(conf);
                try std.testing.expectEqual(13, pl.config_set.value.u16);
            }

            /// Set the corresponding Config struct value from this message.
            pub fn setConfig(self: @This(), config: *Config) void {
                switch (self.kind) {
                    inline else => |kind| {
                        const name = @tagName(kind);
                        const value_type = @FieldType(Config.Field, name);
                        const field: Config.Field = b: {
                            // Special case for flags.
                            if (comptime value_type == Config.Flags) {
                                break :b .{ .flags = Config.Flags.fromInt(
                                    @truncate(self.value.u16),
                                ) };
                            } else if (comptime value_type == i16) {
                                break :b @unionInit(
                                    Config.Field,
                                    name,
                                    self.value.i16,
                                );
                            } else if (comptime value_type == u16) {
                                break :b @unionInit(
                                    Config.Field,
                                    name,
                                    self.value.u16,
                                );
                            } else if (comptime value_type == u32) {
                                break :b @unionInit(
                                    Config.Field,
                                    name,
                                    self.value.u32,
                                );
                            } else if (comptime value_type == f32) {
                                break :b @unionInit(
                                    Config.Field,
                                    name,
                                    self.value.f32,
                                );
                            } else {
                                @compileError("unsupported Config field type");
                            }
                        };
                        field.setConfig(config, .{ .index = self.index });
                    },
                }
            }

            test setConfig {
                var config: Config = std.mem.zeroInit(Config, .{});
                setConfig(.{
                    .kind = .station,
                    .value = .{ .u16 = 3 },
                }, &config);
                try std.testing.expectEqual(3, config.station);
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
        @setEvalBranchQuota(3000);
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
