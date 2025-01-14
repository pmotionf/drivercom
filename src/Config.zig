//! This module represents driver's configuration.
const std = @import("std");
const drivercom = @import("drivercom.zig");

pub const MAX_AXES = 3;

const Config = @This();

/// Driver configuration field. These fields are used directly in messages
/// with driver; their ordering matches firmware field kind ordering.
/// Names reflect nested structure within `Config` struct, and types represent
/// the type of value in the `Config` struct.
pub const Field = union(enum(u16)) {
    id: u16,
    station: u16,
    flags: Flags,
    @"magnet.pitch": f32,
    @"magnet.length": f32,
    @"carrier.mass": f32,
    @"carrier.arrival.threshold.position": f32,
    @"carrier.arrival.threshold.velocity": f32,
    mechanical_angle_offset: f32,
    @"axis.length": f32,
    @"coil.length": f32,
    @"coil.max_current": f32,
    @"coil.continuous_current": f32,
    @"coil.rs": f32,
    @"coil.ls": f32,
    @"coil.kf": f32,
    @"coil.kbm": f32,
    zero_position: f32,
    line_axes: u32,
    warmup_voltage: f32,
    @"default_magnet_length.backward": f32,
    @"default_magnet_length.forward": f32,
    @"vdc.target": f32,
    @"vdc.limit.lower": f32,
    @"vdc.limit.upper": f32,
    @"axes.gain.current.p": f32,
    @"axes.gain.current.i": f32,
    @"axes.gain.current.denominator": u32,
    @"axes.gain.velocity.p": f32,
    @"axes.gain.velocity.i": f32,
    @"axes.gain.velocity.denominator": u32,
    @"axes.gain.velocity.denominator_pi": u32,
    @"axes.gain.position.p": f32,
    @"axes.gain.position.denominator": u32,
    @"axes.base_position": f32,
    @"axes.sensor_off.back.position": i16,
    @"axes.sensor_off.back.section_count": i16,
    @"axes.sensor_off.front.position": i16,
    @"axes.sensor_off.front.section_count": i16,
    @"hall_sensors.magnet_length.backward": f32,
    @"hall_sensors.magnet_length.forward": f32,
    @"hall_sensors.ignore_distance.backward": f32,
    @"hall_sensors.ignore_distance.forward": f32,

    pub const Kind = std.meta.Tag(@This());

    fn setInner(
        parent: anytype,
        value: anytype,
        comptime access: []const u8,
    ) void {
        const nested = comptime std.mem.indexOfScalar(u8, access, '.');
        if (nested) |index| {
            setInner(
                &@field(parent, access[0..index]),
                value,
                access[index + 1 ..],
            );
        } else {
            @field(parent, access) = value;
        }
    }

    test setInner {
        var config: Config = undefined;
        setInner(&config, 13.6, "carrier.mass");
        try std.testing.expectEqual(13.6, config.carrier.mass);
    }

    fn getInner(
        parent: anytype,
        comptime return_type: type,
        comptime access: []const u8,
    ) return_type {
        const nested = comptime std.mem.indexOfScalar(u8, access, '.');
        if (nested) |index| {
            return getInner(
                @field(parent, access[0..index]),
                return_type,
                access[index + 1 ..],
            );
        } else {
            return @field(parent, access);
        }
    }

    test getInner {
        var config: Config = undefined;
        config.carrier.mass = 13.2;
        const mass: f32 = getInner(config, f32, "carrier.mass");
        try std.testing.expectEqual(config.carrier.mass, mass);
    }

    /// Set a field in provided Config struct with value in Field.
    pub fn setConfig(self: Field, config: *Config, opts: struct {
        index: usize = 0,
    }) void {
        switch (self) {
            inline else => |value, kind| {
                const name = @tagName(kind);
                const nested = comptime std.mem.indexOfScalar(u8, name, '.');
                if (comptime nested) |index| {
                    if (comptime std.mem.eql(
                        u8,
                        "hall_sensors",
                        name[0..index],
                    )) {
                        const hall_sensor: *HallSensor =
                            &config.hall_sensors[opts.index];
                        setInner(hall_sensor, value, name[index + 1 ..]);
                    } else if (comptime std.mem.eql(
                        u8,
                        "axes",
                        name[0..index],
                    )) {
                        const axis: *Axis = &config.axes[opts.index];
                        setInner(axis, value, name[index + 1 ..]);
                    } else {
                        setInner(config, value, name);
                    }
                } else {
                    setInner(config, value, name);
                }
            },
        }
    }

    pub fn fromConfig(
        config: Config,
        field: Field.Kind,
        opts: struct {
            index: usize = 0,
        },
    ) Field {
        switch (field) {
            inline else => |kind| {
                const name = @tagName(kind);
                const nested = comptime std.mem.indexOfScalar(u8, name, '.');
                if (comptime nested) |index| {
                    if (comptime std.mem.eql(
                        u8,
                        "hall_sensors",
                        name[0..index],
                    )) {
                        return @unionInit(Field, name, getInner(
                            config.hall_sensors[opts.index],
                            @FieldType(Field, name),
                            name[index + 1 ..],
                        ));
                    } else if (comptime std.mem.eql(
                        u8,
                        "axes",
                        name[0..index],
                    )) {
                        return @unionInit(Field, name, getInner(
                            config.axes[opts.index],
                            @FieldType(Field, name),
                            name[index + 1 ..],
                        ));
                    }
                }
                return @unionInit(Field, name, getInner(
                    config,
                    @FieldType(Field, name),
                    name,
                ));
            },
        }
    }

    test fromConfig {
        var config: Config = std.mem.zeroInit(Config, .{});
        config.axes[1].base_position = 32.5;

        const field = fromConfig(
            config,
            .@"axes.base_position",
            .{ .index = 1 },
        );

        try std.testing.expectEqual(
            config.axes[1].base_position,
            field.@"axes.base_position",
        );
    }

    pub fn toConfig(
        field: Field,
        opts: struct {
            /// Existing Config, used as base for returned "modified" Config
            config: Config = std.mem.zeroInit(Config, .{}),
            index: usize = 0,
        },
    ) Config {
        var config: Config = opts.config;
        switch (field) {
            inline else => |value, kind| {
                const name = @tagName(kind);
                const nested = comptime std.mem.indexOfScalar(u8, name, '.');
                if (comptime nested) |index| {
                    if (comptime std.mem.eql(
                        u8,
                        "hall_sensors",
                        name[0..index],
                    )) {
                        const hall_sensor: *HallSensor =
                            &config.hall_sensors[opts.index];
                        setInner(hall_sensor, value, name[index + 1 ..]);
                    } else if (comptime std.mem.eql(
                        u8,
                        "axes",
                        name[0..index],
                    )) {
                        const axis: *Axis = &config.axes[opts.index];
                        setInner(axis, value, name[index + 1 ..]);
                    } else {
                        setInner(&config, value, name);
                    }
                } else {
                    setInner(&config, value, name);
                }
            },
        }
        return config;
    }

    test toConfig {
        var config: Config = std.mem.zeroInit(Config, .{ .id = 3 });
        const field: Field = .{ .station = 15 };

        config = field.toConfig(.{ .config = config });

        try std.testing.expectEqual(3, config.id);
        try std.testing.expectEqual(15, config.station);
    }
};

/// Recursively walk structure fields, checking if leaf fields exist in
/// `FieldKind` enum.
fn walkFields(structure: anytype, comptime prefix: []const u8) !void {
    switch (@typeInfo(structure)) {
        .@"struct" => |ti| {
            inline for (ti.fields) |field| {
                const new_prefix = if (prefix.len > 0)
                    prefix ++ "." ++ field.name
                else
                    field.name;

                const fti = @typeInfo(field.type);
                switch (fti) {
                    .@"struct", .array => {
                        // Special case Config flags field.
                        if (field.type == Flags) {
                            try std.testing.expectEqual(
                                true,
                                @hasField(Field, new_prefix),
                            );
                            try std.testing.expectEqual(
                                field.type,
                                @FieldType(Field, new_prefix),
                            );
                        } else try walkFields(
                            field.type,
                            new_prefix,
                        );
                    },
                    else => {
                        try std.testing.expectEqual(
                            true,
                            @hasField(Field, new_prefix),
                        );
                        try std.testing.expectEqual(
                            field.type,
                            @FieldType(Field, new_prefix),
                        );
                    },
                }
            }
        },
        .array => |ar| {
            const cti = @typeInfo(ar.child);
            switch (cti) {
                .@"struct", .array => try walkFields(ar.child, prefix),
                else => {
                    try std.testing.expectEqual(
                        true,
                        @hasField(Field, prefix),
                    );
                    try std.testing.expectEqual(
                        ar.child,
                        @FieldType(Field, prefix),
                    );
                },
            }
        },
        else => unreachable,
    }
}

test Field {
    try walkFields(@This(), "");
}

/// Driver ID
id: u16,

/// CC-Link Station ID
station: u16,

flags: Flags,

magnet: struct {
    /// Magnet pole pair pitch in meters.
    pitch: f32,
    length: f32,
},

carrier: struct {
    /// Carrier mass in KG.
    mass: f32,

    /// Threshold conditions to determine carrier arrival at a position.
    arrival: struct {
        threshold: struct {
            position: f32,
            velocity: f32,
        },
    },
},

mechanical_angle_offset: f32,

axis: struct {
    length: f32,
},

coil: struct {
    /// Motor coil length in meters.
    length: f32,
    max_current: f32,
    continuous_current: f32,
    /// Resistance.
    rs: f32,
    /// Inductance.
    ls: f32,
    /// Force constant.
    kf: f32,
    kbm: f32,
},

zero_position: f32,

line_axes: u32,

warmup_voltage: f32,

default_magnet_length: struct {
    backward: f32,
    forward: f32,
},

vdc: struct {
    target: f32,
    limit: struct {
        lower: f32,
        upper: f32,
    },
},

axes: [3]Axis,

hall_sensors: [6]HallSensor,

pub const CurrentGain = struct {
    /// Current P-gain. By default, inductance * Wcc.
    p: f32,
    /// Current I-gain. By default, resistance * Wcc.
    i: f32,
    /// Wcc denominator. Wcc = 2pi * (15000 / denominator).
    denominator: u32,
};

pub const VelocityGain = struct {
    /// Speed P-gain. By default, inertia * Wsc / torque constant.
    p: f32,
    /// Speed I-gain. By default, Wpi * p.
    i: f32,
    /// Wsc denominator. Wsc = Wcc / denominator.
    denominator: u32,
    /// Wpi denominator. Wpi = Wsc / denominator_pi.
    denominator_pi: u32,

    // radius = magnet pole pair pitch / 2pi
    // inertia = vehicle mass * radius * radius
    // torque constant = radius * force constant
};

pub const PositionGain = struct {
    /// Position P-gain. By default, Wpc.
    p: f32,
    /// Wpc denominator. Wpc = Wsc / denominator.
    denominator: u32,
};

pub const Axis = struct {
    gain: struct {
        current: CurrentGain,
        velocity: VelocityGain,
        position: PositionGain,
    },
    base_position: f32,
    sensor_off: struct {
        back: struct {
            position: i16,
            section_count: i16,
        },
        front: struct {
            position: i16,
            section_count: i16,
        },
    },
};

pub const HallSensor = struct {
    magnet_length: struct {
        backward: f32,
        forward: f32,
    },
    ignore_distance: struct {
        backward: f32,
        forward: f32,
    },
};

pub const Flags = packed struct {
    home_sensor: bool,
    has_neighbor: packed struct(u2) {
        backward: bool,
        forward: bool,
    },
    uses_axis: packed struct(u2) {
        axis2: bool,
        axis3: bool,
    },
    calibration_completed: bool,
    rockwell_magnet: bool,
    flip_sensors: packed struct(u3) {
        axis1: bool,
        axis2: bool,
        axis3: bool,
    },

    pub fn toInt(self: Flags) u16 {
        return @as(u10, @bitCast(self));
    }

    pub fn fromInt(int: u10) Flags {
        return @bitCast(int);
    }
};

/// Set value in provided field with value from Config.
pub fn setField(self: Config, field: *Field, opts: struct {
    index: usize = 0,
}) void {
    switch (field.*) {
        inline else => |*value, kind| {
            const name = @tagName(kind);
            const nested = comptime std.mem.indexOfScalar(u8, name, '.');
            if (comptime nested) |index| {
                if (comptime std.mem.eql(
                    u8,
                    "hall_sensors",
                    name[0..index],
                )) {
                    value.* = Field.getInner(
                        self.hall_sensors[opts.index],
                        @FieldType(Field, name),
                        name[index + 1 ..],
                    );
                } else if (comptime std.mem.eql(
                    u8,
                    "axes",
                    name[0..index],
                )) {
                    value.* = Field.getInner(
                        self.axes[opts.index],
                        @FieldType(Field, name),
                        name[index + 1 ..],
                    );
                } else {
                    value.* = Field.getInner(
                        self,
                        @FieldType(Field, name),
                        name,
                    );
                }
            } else {
                value.* = Field.getInner(self, @FieldType(Field, name), name);
            }
        },
    }
}

pub fn calcCurrentGain(
    self: *const @This(),
    axis_index: usize,
    denominator: u32,
) CurrentGain {
    std.debug.assert(axis_index < MAX_AXES);
    const wcc = drivercom.gain.current.wcc(denominator);
    return .{
        .denominator = denominator,
        .p = @floatCast(
            drivercom.gain.current.p(self.coil.ls, wcc),
        ),
        .i = @floatCast(
            drivercom.gain.current.i(self.coil.rs, wcc),
        ),
    };
}

pub fn calcVelocityGain(
    self: *const @This(),
    axis_index: usize,
    denominator: u32,
    denominator_pi: u32,
) VelocityGain {
    std.debug.assert(axis_index < MAX_AXES);
    const axis = self.axes[axis_index];

    const wcc = drivercom.gain.current.wcc(axis.gain.current.denominator);
    const radius = drivercom.gain.velocity.radius(self.magnet.pitch);
    const inertia = drivercom.gain.velocity.inertia(
        self.carrier.mass,
        radius,
    );
    const torque_constant =
        drivercom.gain.velocity.torqueConstant(self.coil.kf, radius);
    const wsc = drivercom.gain.velocity.wsc(denominator, wcc);
    const wpi = drivercom.gain.velocity.wpi(denominator_pi, wsc);
    const p = drivercom.gain.velocity.p(inertia, torque_constant, wsc);

    return .{
        .p = @floatCast(p),
        .i = @floatCast(drivercom.gain.velocity.i(p, wpi)),
        .denominator = denominator,
        .denominator_pi = denominator_pi,
    };
}

pub fn calcPositionGain(
    self: *const @This(),
    axis_index: usize,
    denominator: u32,
) PositionGain {
    std.debug.assert(axis_index < MAX_AXES);
    const axis = self.axes[axis_index];

    const wcc = drivercom.gain.current.wcc(axis.gain.current.denominator);
    const wsc =
        drivercom.gain.velocity.wsc(axis.gain.velocity.denominator, wcc);

    const wpc = drivercom.gain.position.wpc(denominator, wsc);
    const p = drivercom.gain.position.p(wpc);

    return .{
        .p = @floatCast(p),
        .denominator = denominator,
    };
}
