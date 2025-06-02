//! This module represents driver's configuration.
const std = @import("std");
const drivercom = @import("drivercom.zig");

pub const MAX_AXES = 3;

const NewConfig = @import("Config.zig");
const Config = @This();

/// `drivercom` version for this `Config` struct.
pub const version: std.SemanticVersion = .{
    .major = 0,
    .minor = 4,
    .patch = 0,
};
/// Driver configuration field. These fields are used directly in messages
/// with driver; their ordering matches firmware field kind ordering.
/// Names reflect nested structure within `Config` struct, and types represent
/// the type of value in the `Config` struct.
pub const Field = union(enum(u16)) {
    id: u16,
    station: u16,
    flags: Flags,
    @"line.axes": u16,
    @"voltage.target": u16,
    @"voltage.warmup": u16,
    @"voltage.limit.lower": u16,
    @"voltage.limit.upper": u16,
    @"magnet.pitch": f32,
    @"magnet.length": f32,
    @"carrier.mass": u16,
    @"carrier.arrival.threshold.position": f32,
    @"carrier.arrival.threshold.velocity": f32,
    @"carrier.cas.buffer": u16,
    @"carrier.cas.acceleration": f32,
    mechanical_angle_offset: f32,
    @"axis.length": f32,
    @"coil.length": f32,
    @"coil.max_current": f32,
    @"coil.continuous_current": f32,
    @"coil.rs": f32,
    @"coil.ls": f32,
    @"coil.kf": f32,
    @"coil.kbm": f32,
    @"sensor.default_magnet_length": f32,
    @"sensor.ignore_distance": f32,
    zero_position: f32,
    @"axes.gain.current.p": f32,
    @"axes.gain.current.i": f32,
    @"axes.gain.current.denominator": u32,
    @"axes.gain.velocity.p": f32,
    @"axes.gain.velocity.i": f32,
    @"axes.gain.velocity.denominator": u32,
    @"axes.gain.velocity.denominator_pi": u32,
    @"axes.gain.position.p": f32,
    @"axes.gain.position.denominator": u32,
    @"hall_sensors.magnet_length.backward": f32,
    @"hall_sensors.magnet_length.forward": f32,
    @"hall_sensors.position.on.backward": f32,
    @"hall_sensors.position.on.forward": f32,
    @"hall_sensors.position.off.backward": f32,
    @"hall_sensors.position.off.forward": f32,

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
        setInner(&config, 1360, "carrier.mass");
        try std.testing.expectEqual(1360, config.carrier.mass);
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
        config.carrier.mass = 1320;
        const mass: u16 = getInner(config, u16, "carrier.mass");
        try std.testing.expectEqual(config.carrier.mass, mass);

        config.hall_sensors[3].position.off.forward = 17.48;
        try std.testing.expectEqual(
            config.hall_sensors[3].position.off.forward,
            getInner(config.hall_sensors[3], f32, "position.off.forward"),
        );
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
        {
            config.axes[1].gain.position.p = 32.6;
            const field = fromConfig(
                config,
                .@"axes.gain.position.p",
                .{ .index = 1 },
            );

            try std.testing.expectEqual(
                config.axes[1].gain.position.p,
                field.@"axes.gain.position.p",
            );
        }

        {
            config.hall_sensors[4].position.on.forward = 0.9534;
            const field = fromConfig(
                config,
                .@"hall_sensors.position.on.forward",
                .{ .index = 4 },
            );

            try std.testing.expectEqual(
                config.hall_sensors[4].position.on.forward,
                field.@"hall_sensors.position.on.forward",
            );
        }
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

line: struct {
    /// Total number of axes in line.
    axes: u16,
},

voltage: struct {
    /// Target DC voltage.
    target: u16,
    /// Reference voltage used for warmup to find mechanical angle offset.
    warmup: u16,
    limit: struct {
        /// Lower DC voltage limit, inclusive.
        lower: u16,
        /// Upper DC voltage limit, inclusive.
        upper: u16,
    },
},

magnet: struct {
    /// Magnet pole pair pitch in meters.
    pitch: f32,
    length: f32,
},

carrier: struct {
    /// Carrier mass in decagrams (10 grams, or 1/100 of a kilogram).
    mass: u16,

    /// Threshold conditions to determine carrier arrival at a position.
    arrival: struct {
        threshold: struct {
            position: f32,
            velocity: f32,
        },
    },

    cas: struct {
        /// Minimum buffer to maintain between carriers, in millimeters.
        buffer: u16,
        acceleration: f32,
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

sensor: struct {
    default_magnet_length: f32,
    ignore_distance: f32,
},

zero_position: f32,

axes: [3]Axis,

hall_sensors: [6]HallSensor,

pub const CurrentGain = NewConfig.CurrentGain;
pub const VelocityGain = NewConfig.VelocityGain;
pub const PositionGain = NewConfig.PositionGain;

pub const Axis = struct {
    gain: struct {
        current: CurrentGain,
        velocity: VelocityGain,
        position: PositionGain,
    },
};

pub const HallSensor = struct {
    magnet_length: struct {
        backward: f32,
        forward: f32,
    },
    position: struct {
        on: struct {
            backward: f32,
            forward: f32,
        },
        off: struct {
            backward: f32,
            forward: f32,
        },
    },
};

pub const Flags = packed struct {
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
        return @as(u9, @bitCast(self));
    }

    pub fn fromInt(int: u9) Flags {
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
