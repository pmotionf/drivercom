const std = @import("std");

cycles: u32,
config: Config,
axes: [3]bool = .{false} ** 3,
hall_sensors: [6]bool = .{false} ** 6,
vehicles: [4]u12 = .{0} ** 4,
start: struct {
    kind: Start = .immediate,
    combinator: Start.Combinator = .@"or",
    hall_sensors: [6]bool = .{false} ** 6,
    vehicles: [4]u12 = .{0} ** 4,
} = .{},

pub const Status = enum(u2) {
    stopped = 0,
    started = 1,
    waiting = 2,
    invalid = 3,
};

fn unwrapConfig(
    T: anytype,
    tag_value: *u5,
    name: []const u8,
) []const std.builtin.Type.EnumField {
    const ti = @typeInfo(T).@"struct";
    var result: []const std.builtin.Type.EnumField = &.{};
    for (ti.fields) |field| {
        const field_ti = @typeInfo(field.type);
        switch (field_ti) {
            .@"struct" => {
                result = result ++ unwrapConfig(
                    field.type,
                    tag_value,
                    if (name.len > 0)
                        name ++ field.name ++ "_"
                    else
                        field.name ++ "_",
                );
            },
            .bool => {
                result = result ++ .{.{
                    .name = name ++ field.name,
                    .value = tag_value.*,
                }};
                tag_value.* += 1;
            },
            else => {},
        }
    }
    return result;
}

pub const Tag: type = b: {
    var result: std.builtin.Type.Enum = .{
        .tag_type = u5,
        .fields = &.{},
        .decls = &.{},
        .is_exhaustive = true,
    };
    var tag_value: u5 = 0;
    result.fields = result.fields ++ unwrapConfig(Config, &tag_value, "");
    break :b @Type(.{ .@"enum" = result });
};

pub const Config = packed struct(u32) {
    // Driver log.
    driver: packed struct {
        cycle: bool = false,
        cycle_time: bool = false,
        vdc: bool = false,
    } = .{},

    // Sensor log.
    sensor: packed struct {
        alarm: bool = false,
        angle: bool = false,
        unwrapped_angle: bool = false,
        distance: bool = false,
    } = .{},
    _: u25 = 0,
};

pub const Start = enum(u3) {
    immediate = 0,
    sensor_on = 1,
    sensor_off = 2,
    vehicle_present = 3,
    vehicle_absent = 4,

    pub const Combinator = enum(u1) { @"and", @"or" };
};
