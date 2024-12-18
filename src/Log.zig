const std = @import("std");

cycles: u32 = 0,
config: Config = .{},
axis: [3]bool = .{false} ** 3,
hall_sensor: [6]bool = .{false} ** 6,
vehicle: [4]u12 = .{0} ** 4,
start: struct {
    kind: Start = .immediate,
    combinator: Start.Combinator = .@"or",
    hall_sensor: [6]bool = .{false} ** 6,
    vehicle: [4]u12 = .{0} ** 4,
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
        unwrapped_angle: bool = false,
        distance: bool = false,
        velocity: bool = false,
    } = .{},

    // Axis log.
    axis: packed struct {
        current_d: bool = false,
        current_q: bool = false,
        reference_current_d: bool = false,
        reference_current_q: bool = false,
        vehicle_id: bool = false,
        vehicle_position: bool = false,
        average_angle_diff: bool = false,
    } = .{},
    _: u8 = 0,
};

pub const Start = enum(u3) {
    immediate = 0,
    sensor_on = 1,
    sensor_off = 2,
    vehicle_present = 3,
    vehicle_absent = 4,

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
    vehicle,
};

/// Returns size in bytes of data tag.
pub fn tagSize(tag: Tag) u3 {
    return switch (tag) {
        .driver_cycle,
        .driver_cycle_time,
        .driver_vdc,
        .sensor_alarm,
        .sensor_valid,
        .sensor_active,
        .axis_vehicle_id,
        .driver_com_bwd_sent,
        .driver_com_bwd_arrived,
        .driver_com_fwd_sent,
        .driver_com_fwd_arrived,
        .driver_com_bwd_sent_cycles,
        .driver_com_fwd_sent_cycles,
        => 2,
        .sensor_angle,
        .sensor_unwrapped_angle,
        .sensor_distance,
        .sensor_average_angle,
        .sensor_velocity,
        .axis_current_d,
        .axis_current_q,
        .axis_reference_current_d,
        .axis_reference_current_q,
        .axis_vehicle_position,
        .axis_average_angle_diff,
        => 4,
    };
}

pub fn tagParse(comptime tag: Tag, data: []const u8) TagType(tag) {
    std.debug.assert(data.len == tagSize(tag));
    switch (tag) {
        .driver_cycle,
        .driver_cycle_time,
        .sensor_angle,
        .sensor_average_angle,
        .sensor_unwrapped_angle,
        .sensor_distance,
        .sensor_velocity,
        .axis_current_d,
        .axis_current_q,
        .axis_reference_current_d,
        .axis_reference_current_q,
        .axis_vehicle_id,
        .axis_vehicle_position,
        .axis_average_angle_diff,
        .driver_com_bwd_sent,
        .driver_com_bwd_arrived,
        .driver_com_fwd_sent,
        .driver_com_fwd_arrived,
        .driver_com_bwd_sent_cycles,
        .driver_com_fwd_sent_cycles,
        => {
            return std.mem.bytesToValue(TagType(tag), data);
        },
        .driver_vdc => {
            const result: u16 = std.mem.bytesToValue(u16, data);
            var result_f: f32 = @floatFromInt(result);
            result_f /= 100.0;
            return result_f;
        },
        .sensor_alarm,
        .sensor_valid,
        .sensor_active,
        => {
            return data[0] != 0;
        },
    }
}

test tagParse {
    const vdc: u16 = 12089;
    try std.testing.expectEqual(
        120.89,
        tagParse(.driver_vdc, std.mem.asBytes(&vdc)),
    );
}

pub fn TagType(comptime tag: Tag) type {
    return switch (tag) {
        .driver_cycle,
        .driver_cycle_time,
        .axis_vehicle_id,
        .driver_com_bwd_sent,
        .driver_com_bwd_arrived,
        .driver_com_fwd_sent,
        .driver_com_fwd_arrived,
        .driver_com_bwd_sent_cycles,
        .driver_com_fwd_sent_cycles,
        => u16,
        .sensor_alarm,
        .sensor_valid,
        .sensor_active,
        => bool,
        .driver_vdc,
        .sensor_angle,
        .sensor_average_angle,
        .sensor_unwrapped_angle,
        .sensor_distance,
        .sensor_velocity,
        .axis_current_d,
        .axis_current_q,
        .axis_reference_current_d,
        .axis_reference_current_q,
        .axis_vehicle_position,
        .axis_average_angle_diff,
        => f32,
    };
}

pub fn tagKind(tag: Tag) TagKind {
    if (@tagName(tag)[0] == 'd') return .driver;
    if (@tagName(tag)[0] == 's') return .sensor;
    if (@tagName(tag)[0] == 'a') return .axis;
    if (@tagName(tag)[0] == 'v') return .vehicle;

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
                        name ++ field.name ++ "_"
                    else
                        field.name ++ "_",
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
