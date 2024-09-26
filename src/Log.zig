const std = @import("std");

cycles: u32,
config: Config,
start: struct {
    kind: Start = .immediate,
    hall_sensors: [6]bool = .{false} ** 6,
    vehicles: [4]u12 = .{0} ** 4,
},

pub const Status = enum(u2) {
    stopped = 0,
    started = 1,
    waiting = 2,
    invalid = 3,
};

pub const Tag: type = b: {
    var result: std.builtin.Type.Enum = .{
        .tag_type = u5,
        .fields = &.{},
        .decls = &.{},
        .is_exhaustive = true,
    };

    const ti = @typeInfo(Config).@"struct";
    for (ti.fields, 0..) |field, i| {
        result.fields = result.fields ++ .{.{
            .name = field.name,
            .value = i,
        }};
    }

    break :b @Type(.{ .@"enum" = result });
};

pub const Config = packed struct(u32) {
    cycle: bool,
    cycle_time: bool,
    vdc: bool,
    _: u29 = 0,
};

pub const Start = enum(u3) {
    immediate = 0,
    sensor_on = 1,
    sensor_off = 2,
    vehicle_present = 3,
    vehicle_absent = 4,
};
