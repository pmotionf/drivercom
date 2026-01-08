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
    @"coil.center.kf": f32,
    @"coil.between.kf": f32,
    @"coil.kbm": f32,
    @"sensor.default_magnet_length": f32,
    @"sensor.ignore_distance": f32,
    zero_position: f32,
    @"axis.center.gain.current.p": f32,
    @"axis.center.gain.current.i": f32,
    @"axis.center.gain.current.denominator": u32,
    @"axis.center.gain.velocity.p": f32,
    @"axis.center.gain.velocity.i": f32,
    @"axis.center.gain.velocity.denominator": u32,
    @"axis.center.gain.velocity.denominator_pi": u32,
    @"axis.center.gain.position.p": f32,
    @"axis.center.gain.position.denominator": u32,
    @"axis.between.gain.current.p": f32,
    @"axis.between.gain.current.i": f32,
    @"axis.between.gain.current.denominator": u32,
    @"axis.between.gain.velocity.p": f32,
    @"axis.between.gain.velocity.i": f32,
    @"axis.between.gain.velocity.denominator": u32,
    @"axis.between.gain.velocity.denominator_pi": u32,
    @"axis.between.gain.position.p": f32,
    @"axis.between.gain.position.denominator": u32,
    @"hall_sensors.magnet_length.backward": f32,
    @"hall_sensors.magnet_length.forward": f32,
    @"hall_sensors.position.on.backward": f32,
    @"hall_sensors.position.on.forward": f32,

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

        config.hall_sensors[3].position.on.forward = 17.48;
        try std.testing.expectEqual(
            config.hall_sensors[3].position.on.forward,
            getInner(config.hall_sensors[3], f32, "position.on.forward"),
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
            config.axis.center.gain.position.p = 32.6;
            const field = fromConfig(
                config,
                .@"axis.center.gain.position.p",
                .{},
            );

            try std.testing.expectEqual(
                config.axis.center.gain.position.p,
                field.@"axis.center.gain.position.p",
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

/// Provides field type of config fields and its metadata.
pub const Info = struct {
    id: Type = "u16",
    __id: Meta = .{
        .description =
        \\ID is an identifier number and unique per Line.
        \\First Driver in Line must have ID number 1.
        \\Each Driver in Line must have consecutively increasing IDs.
        ,
    },

    station: Type = "u16",
    __station: Meta = .{
        .description =
        \\CC-Link Station ID. Identifier number, unique per Track.
        ,
    },

    flags: struct {
        has_neighbor: struct {
            backward: Type = "bool",
            __backward: Meta = .{
                .description =
                \\True if this Driver ID is greater than 1.
                ,
            },
            forward: Type = "bool",
            __forward: Meta = .{
                .description =
                \\True if this Driver ID is less than number of Drivers in this
                \\Line.
                ,
            },
        } = .{},

        uses_axis: struct {
            axis2: Type = "bool",
            axis3: Type = "bool",
            __axis2: Meta = .{
                .description =
                \\Whether this Driver uses second Axis.
                ,
            },
            __axis3: Meta = .{
                .description =
                \\Whether this Driver uses third Axis.
                \\`axis2` must be true if using third Axis.
                ,
            },
        } = .{},
        __uses_axis: Meta = .{
            .description =
            \\Axes used by this driver.
            ,
        },

        calibration_completed: Type = "bool",
        __calibration_completed: Meta = .{ .hidden = true },

        rockwell_magnet: Type = "bool",
        __rockwell_magnet: Meta = .{
            .description =
            \\True if Carriers are Rockwell magnets in this Line.
            ,
        },

        flip_sensors: struct {
            axis1: Type = "bool",
            axis2: Type = "bool",
            axis3: Type = "bool",
        } = .{},
        __flip_sensors: Meta = .{
            .description =
            \\Invert Carrier movement direction readings.
            ,
        },

        swap_sensors: struct {
            axis1: Type = "bool",
            axis2: Type = "bool",
            axis3: Type = "bool",
        } = .{},
        __swap_sensors: Meta = .{
            .description =
            \\Switch order of the two sensors in Axis.
            ,
        },
    } = .{},

    line: struct {
        axes: Type = "u16",
        __axes: Meta = .{
            .description =
            \\Total number of Axes used in this Line.
            ,
        },
    } = .{},

    voltage: struct {
        target: Type = "u16",
        __target: Meta = .{
            .description = "Supplied voltage for motor coils.",
            .unit_short = "V",
            .unit_long = "Volt",
        },
        warmup: Type = "u16",
        __warmup: Meta = .{
            .description = "Voltage applied to find sensor angle offset.",
            .unit_short = "V",
            .unit_long = "Volt",
        },
        limit: struct {
            lower: Type = "u16",
            __lower: Meta = .{
                .description = "Minimum voltage threshold before alarm.",
                .unit_short = "V",
                .unit_long = "Volt",
            },
            upper: Type = "u16",
            __upper: Meta = .{
                .description = "Maximum voltage threshold before alarm.",
                .unit_short = "V",
                .unit_long = "Volt",
            },
        } = .{},
    } = .{},

    magnet: struct {
        pitch: Type = "f32",
        __pitch: Meta = .{
            .description = "Pole pitch of Carrier magnet.",
            .unit_short = "m",
            .unit_long = "Meter",
        },
        length: Type = "f32",
        __length: Meta = .{
            .description = "Length of Carrier magnet.",
            .unit_short = "m",
            .unit_long = "Meter",
        },
    } = .{},

    carrier: struct {
        mass: Type = "u16",
        __mass: Meta = .{
            .description = "Mass of Carrier.",
            .unit_short = "dag",
            .unit_long = "Decagram",
        },
        arrival: struct {
            threshold: struct {
                velocity: Type = "f32",
                __velocity: Meta = .{
                    .description =
                    \\Upper velocity threshold for Carrier movement completion.
                    ,
                    .unit_short = "m/s",
                    .unit_long = "Meters per Second",
                },
                position: Type = "f32",
                __position: Meta = .{
                    .description =
                    \\Absolute position error tolerance for Carrier movement
                    \\completion.
                    ,
                    .unit_short = "m",
                    .unit_long = "Meter",
                },
            } = .{},
        } = .{},

        cas: struct {
            buffer: Type = "u16",
            __buffer: Meta = .{
                .description =
                \\Minimum distance between two Carriers before CAS triggers.
                ,
                .unit_short = "mm",
                .unit_long = "Millimeter",
            },
            acceleration: Type = "f32",
            __acceleration: Meta = .{
                .description =
                \\Acceleration used to stop Carrier movement when CAS triggers.
                ,
                .unit_short = "m/s²",
                .unit_long = "Meters per Second squared",
            },
        } = .{},
        __cas: Meta = .{ .description = "Collision Avoidance System" },
    } = .{},

    mechanical_angle_offset: Type = "f32",

    axis: struct {
        length: Type = "f32",
        __length: Meta = .{
            .description = "Distance between each Axis' coil centers.",
            .unit_short = "m",
            .unit_long = "Meter",
        },
        center: struct {
            gain: struct {
                current: struct {
                    p: Type = "f32",
                    i: Type = "f32",
                    denominator: Type = "u32",
                } = .{},
                velocity: struct {
                    p: Type = "f32",
                    i: Type = "f32",
                    denominator: Type = "u32",
                    denominator_pi: Type = "u32",
                } = .{},
                position: struct {
                    p: Type = "f32",
                    denominator: Type = "u32",
                } = .{},
            } = .{},
        } = .{},
        between: struct {
            gain: struct {
                current: struct {
                    p: Type = "f32",
                    i: Type = "f32",
                    denominator: Type = "u32",
                } = .{},
                velocity: struct {
                    p: Type = "f32",
                    i: Type = "f32",
                    denominator: Type = "u32",
                    denominator_pi: Type = "u32",
                } = .{},
                position: struct {
                    p: Type = "f32",
                    denominator: Type = "u32",
                } = .{},
            } = .{},
        } = .{},
    } = .{},

    coil: struct {
        length: Type = "f32",
        __length: Meta = .{
            .description = "Length of motor coil.",
            .unit_short = "m",
            .unit_long = "Meter",
        },
        max_current: Type = "f32",
        __max_current: Meta = .{
            .unit_short = "A",
            .unit_long = "Ampere",
        },
        continuous_current: Type = "f32",
        __continuous_current: Meta = .{
            .unit_short = "A",
            .unit_long = "Ampere",
        },
        rs: Type = "f32",
        __rs: Meta = .{
            .unit_short = "Ω",
            .unit_long = "Ohm (Line to Neutral)",
        },
        ls: Type = "f32",
        __ls: Meta = .{
            .unit_short = "H",
            .unit_long = "Henry (Line to Neutral)",
        },
        center: struct {
            kf: Type = "f32",
            __kf: Meta = .{
                .unit_short = "N/A_rms",
            },
        } = .{},
        between: struct {
            kf: Type = "f32",
            __kf: Meta = .{
                .unit_short = "N/A_rms",
            },
        } = .{},
        kbm: Type = "f32",
        __kbm: Meta = .{
            .unit_short = "V/(m/s)",
        },
    } = .{},

    sensor: struct {
        default_magnet_length: Type = "f32",
        __default_magnet_length: Meta = .{
            .unit_short = "m",
            .unit_long = "Meter",
        },
        ignore_distance: Type = "f32",
        __ignore_distance: Meta = .{
            .unit_short = "m",
            .unit_long = "Meter",
        },
    } = .{},

    zero_position: Type = "f32",
    __zero_position: Meta = .{
        .unit_short = "m",
        .unit_long = "Meter",
    },

    hall_sensors: []const struct {
        magnet_length: struct {
            backward: Type = "f32",
            __backward: Meta = .{
                .unit_short = "m",
                .unit_long = "Meter",
            },
            forward: Type = "f32",
            __forward: Meta = .{
                .unit_short = "m",
                .unit_long = "Meter",
            },
        } = .{},
        position: struct {
            on: struct {
                backward: Type = "f32",
                __backward: Meta = .{
                    .unit_short = "m",
                    .unit_long = "Meter",
                },
                forward: Type = "f32",
                __forward: Meta = .{
                    .unit_short = "m",
                    .unit_long = "Meter",
                },
            } = .{},
        } = .{},
    } = &.{
        .{}, .{}, .{}, .{}, .{}, .{},
    },

    pub const Type = []const u8;
    pub const Meta = struct {
        hidden: bool = false,
        description: ?[]const u8 = null,
        unit_short: ?[]const u8 = null,
        unit_long: ?[]const u8 = null,
    };
};

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
    center: struct {
        gain: struct {
            current: CurrentGain,
            velocity: VelocityGain,
            position: PositionGain,
        },
    },
    between: struct {
        gain: struct {
            current: CurrentGain,
            velocity: VelocityGain,
            position: PositionGain,
        },
    },
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
    center: struct {
        /// Force constant.
        kf: f32,
    },
    between: struct {
        /// Force constant.
        kf: f32,
    },
    kbm: f32,
},

sensor: struct {
    default_magnet_length: f32,
    ignore_distance: f32,
},

zero_position: f32,

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
    // inertia = carrier mass * radius * radius
    // torque constant = radius * force constant
};

pub const PositionGain = struct {
    /// Position P-gain. By default, Wpc.
    p: f32,
    /// Wpc denominator. Wpc = Wsc / denominator.
    denominator: u32,
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
    swap_sensors: packed struct(u3) {
        axis1: bool,
        axis2: bool,
        axis3: bool,
    },

    pub fn toInt(self: Flags) u16 {
        return @as(u12, @bitCast(self));
    }

    pub fn fromInt(int: u12) Flags {
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
    denominator: u32,
) CurrentGain {
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
    current_gain: *const CurrentGain,
    kf: f32,
    denominator: u32,
    denominator_pi: u32,
) VelocityGain {
    const wcc = drivercom.gain.current.wcc(current_gain.denominator);
    const radius = drivercom.gain.velocity.radius(self.magnet.pitch);
    const inertia = drivercom.gain.velocity.inertia(
        @as(f64, @floatFromInt(self.carrier.mass)) / 100.0,
        radius,
    );
    const torque_constant =
        drivercom.gain.velocity.torqueConstant(kf, radius);
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
    _: *const @This(),
    current_gain: *const CurrentGain,
    velocity_gain: *const VelocityGain,
    denominator: u32,
) PositionGain {
    const wcc = drivercom.gain.current.wcc(current_gain.denominator);
    const wsc =
        drivercom.gain.velocity.wsc(velocity_gain.denominator, wcc);

    const wpc = drivercom.gain.position.wpc(denominator, wsc);
    const p = drivercom.gain.position.p(wpc);

    return .{
        .p = @floatCast(p),
        .denominator = denominator,
    };
}

const OldConfig = @import("OldConfig.zig");
fn migrateWalkFields(new: anytype, old: anytype) void {
    const ti = @typeInfo(@typeInfo(@TypeOf(new)).pointer.child);
    const old_type = @TypeOf(old);
    const old_ti = @typeInfo(old_type);

    if (comptime std.meta.activeTag(old_ti) != std.meta.activeTag(ti)) return;

    switch (comptime ti) {
        .@"struct" => |s_ti| {
            inline for (s_ti.fields) |field| {
                if (comptime @hasField(old_type, field.name)) {
                    const child_ti = @typeInfo(field.type);
                    switch (comptime child_ti) {
                        .@"struct", .array => {
                            migrateWalkFields(
                                &@field(new, field.name),
                                @field(old, field.name),
                            );
                        },
                        else => {
                            const oc_type = @TypeOf(@field(old, field.name));
                            if (comptime field.type == oc_type) {
                                @field(new, field.name) =
                                    @field(old, field.name);
                            }
                        },
                    }
                }
            }
        },
        .array => |a_ti| {
            inline for (0..@min(a_ti.len, old_ti.array.len)) |i| {
                const elem_ti = @typeInfo(a_ti.child);
                switch (comptime elem_ti) {
                    .@"struct", .array => {
                        migrateWalkFields(&new[i], old[i]);
                    },
                    else => {
                        if (comptime a_ti.child == old_ti.array.child) {
                            new[i] = old[i];
                        }
                    },
                }
            }
        },
        else => {
            @compileError(
                std.fmt.comptimePrint(
                    "migrate walked unexpected field kind: {}, {}",
                    .{
                        @TypeOf(new),
                        @TypeOf(old),
                    },
                ),
            );
        },
    }
}
pub fn migrate(old: OldConfig) Config {
    var result: Config = undefined;
    if (comptime @import("builtin").is_test) {
        @memset(std.mem.asBytes(&result), 0xFF);
    }

    // Migrate identical fields.
    migrateWalkFields(&result, old);

    // Migrate changed fields.

    // Default-initialize new fields.
    result.flags.swap_sensors.axis1 = false;
    result.flags.swap_sensors.axis2 = false;
    result.flags.swap_sensors.axis3 = false;

    return result;
}

test migrate {
    const old = std.mem.zeroes(OldConfig);
    var new = std.mem.zeroes(Config);
    new.flags.swap_sensors.axis1 = false;
    new.flags.swap_sensors.axis2 = false;
    new.flags.swap_sensors.axis3 = false;

    const migrated = migrate(old);

    try std.testing.expectEqualDeep(new, migrated);
}
