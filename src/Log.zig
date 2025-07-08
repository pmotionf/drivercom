const std = @import("std");
const drivercom = @import("drivercom.zig");

cycles: u32 = 0,
config: Config = .{},
axis: [3]bool = .{false} ** 3,
hall_sensor: [6]bool = .{false} ** 6,
carrier: [4]u12 = .{0} ** 4,
start: struct {
    kind: Start = .immediate,
    combinator: Start.Combinator = .@"or",
    hall_sensor: [6]bool = .{false} ** 6,
    carrier: [4]u12 = .{0} ** 4,
} = .{},

pub const Config = packed struct(u32) {
    // Driver log.
    driver: packed struct {
        cycle: bool = false,
        cycle_time: bool = false,
        vdc: bool = false,
        com_bwd_sent: bool = false,
        com_bwd_arrived: bool = false,
        com_fwd_sent: bool = false,
        com_fwd_arrived: bool = false,
        com_bwd_sent_cycles: bool = false,
        com_fwd_sent_cycles: bool = false,
    } = .{},

    // Sensor log.
    sensor: packed struct {
        alarm: bool = false,
        valid: bool = false,
        active: bool = false,
        angle: bool = false,
        average_angle: bool = false,
        distance: bool = false,
        velocity: bool = false,
    } = .{},

    // Axis log.
    axis: packed struct {
        current_d: bool = false,
        current_q: bool = false,
        reference_current_d: bool = false,
        reference_current_q: bool = false,
        carrier_id: bool = false,
        carrier_position: bool = false,
        carrier_state: bool = false,
        average_angle_diff: bool = false,
        carrier_reference_velocity: bool = false,
        carrier_velocity: bool = false,
    } = .{},
    _: u6 = 0,
};

pub const Start = enum(u3) {
    immediate = 0,
    sensor_on = 1,
    sensor_off = 2,
    carrier_present = 3,
    carrier_absent = 4,

    pub const Combinator = enum(u1) { @"and", @"or" };
};

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
    var tag_value: u5 = 0;
    result.fields = result.fields ++ unwrapConfig(Config, &tag_value, "");
    break :b @Type(.{ .@"enum" = result });
};

pub const TagKind = enum {
    driver,
    axis,
    sensor,
    carrier,
};

/// Returns size in bytes of data tag.
pub fn tagSize(tag: Tag) u3 {
    return switch (tag) {
        .@"driver.cycle",
        .@"driver.cycle_time",
        .@"driver.vdc",
        .@"sensor.alarm",
        .@"sensor.valid",
        .@"sensor.active",
        .@"axis.carrier_id",
        .@"driver.com_bwd_sent",
        .@"driver.com_bwd_arrived",
        .@"driver.com_fwd_sent",
        .@"driver.com_fwd_arrived",
        .@"driver.com_bwd_sent_cycles",
        .@"driver.com_fwd_sent_cycles",
        .@"axis.carrier_state",
        => 2,
        .@"sensor.angle",
        .@"sensor.distance",
        .@"sensor.average_angle",
        .@"sensor.velocity",
        .@"axis.current_d",
        .@"axis.current_q",
        .@"axis.reference_current_d",
        .@"axis.reference_current_q",
        .@"axis.carrier_position",
        .@"axis.average_angle_diff",
        .@"axis.carrier_reference_velocity",
        .@"axis.carrier_velocity",
        => 4,
    };
}

pub fn tagParse(comptime tag: Tag, data: []const u8) TagType(tag) {
    std.debug.assert(data.len == tagSize(tag));
    switch (tag) {
        .@"driver.cycle",
        .@"driver.cycle_time",
        .@"sensor.angle",
        .@"sensor.average_angle",
        .@"sensor.distance",
        .@"sensor.velocity",
        .@"axis.current_d",
        .@"axis.current_q",
        .@"axis.reference_current_d",
        .@"axis.reference_current_q",
        .@"axis.carrier_id",
        .@"axis.carrier_position",
        .@"axis.average_angle_diff",
        .@"driver.com_bwd_sent",
        .@"driver.com_bwd_arrived",
        .@"driver.com_fwd_sent",
        .@"driver.com_fwd_arrived",
        .@"driver.com_bwd_sent_cycles",
        .@"driver.com_fwd_sent_cycles",
        .@"axis.carrier_state",
        .@"axis.carrier_reference_velocity",
        .@"axis.carrier_velocity",
        => {
            return std.mem.bytesToValue(TagType(tag), data);
        },
        .@"driver.vdc" => {
            const result: u16 = std.mem.bytesToValue(u16, data);
            var result_f: f32 = @floatFromInt(result);
            result_f /= 100.0;
            return result_f;
        },
        .@"sensor.alarm",
        .@"sensor.valid",
        .@"sensor.active",
        => {
            return data[0] != 0;
        },
    }
}

test tagParse {
    const vdc: u16 = 12089;
    try std.testing.expectEqual(
        120.89,
        tagParse(.@"driver.vdc", std.mem.asBytes(&vdc)),
    );
}

pub fn TagType(comptime tag: Tag) type {
    return switch (tag) {
        .@"driver.com_bwd_sent",
        .@"driver.com_bwd_arrived",
        .@"driver.com_fwd_sent",
        .@"driver.com_fwd_arrived",
        => drivercom.DriverMessage,
        .@"axis.carrier_state",
        => drivercom.CarrierState,
        .@"driver.cycle",
        .@"driver.cycle_time",
        .@"axis.carrier_id",
        .@"driver.com_bwd_sent_cycles",
        .@"driver.com_fwd_sent_cycles",
        => u16,
        .@"sensor.alarm",
        .@"sensor.valid",
        .@"sensor.active",
        => bool,
        .@"driver.vdc",
        .@"sensor.angle",
        .@"sensor.average_angle",
        .@"sensor.distance",
        .@"sensor.velocity",
        .@"axis.current_d",
        .@"axis.current_q",
        .@"axis.reference_current_d",
        .@"axis.reference_current_q",
        .@"axis.carrier_position",
        .@"axis.average_angle_diff",
        .@"axis.carrier_reference_velocity",
        .@"axis.carrier_velocity",
        => f32,
    };
}

pub fn tagKind(tag: Tag) TagKind {
    if (@tagName(tag)[0] == 'd') return .driver;
    if (@tagName(tag)[0] == 's') return .sensor;
    if (@tagName(tag)[0] == 'a') return .axis;
    if (@tagName(tag)[0] == 'v') return .carrier;

    unreachable;
}

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
                        name ++ field.name ++ "."
                    else
                        field.name ++ ".",
                );
            },
            .bool => {
                result = result ++ .{std.builtin.Type.EnumField{
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
