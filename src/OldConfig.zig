//! This module represents driver's configuration.
const std = @import("std");
const drivercom = @import("drivercom.zig");

pub const MAX_AXES = 3;

const NewConfig = @import("Config.zig");
const Config = @This();

/// `drivercom` version for this `Config` struct.
pub const version: std.SemanticVersion = .{
    .major = 0,
    .minor = 5,
    .patch = 0,
};

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

pub const CurrentGain = NewConfig.CurrentGain;
pub const VelocityGain = NewConfig.VelocityGain;
pub const PositionGain = NewConfig.PositionGain;
