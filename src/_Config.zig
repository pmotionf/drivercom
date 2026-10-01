//! This module represents driver's configuration.
const std = @import("std");
const Config = @This();

/// Driver ID
id: u16,
/// CC-Link Station ID
station: u16,
/// CC-Link baud rate
baud_rate: CcLinkSpeed,
flags: Flags,
line: struct {
    /// Total number of axes in line.
    axes: u32,
    /// Axis length used in the whole line.
    axis_length: f32,
    /// Slider configuration in the whole line.
    slider: struct {
        mass: f32,
        length: f32,
    },
    /// Magnet pitch (m)
    magnet_pitch: f32,
},
voltage_warmup: f32,
retry_count: u8,
hall_cutoff_freq: f32,
overcurrent_timeout: f32,
pos_offset: f32,
right_sensor_distance: f32,
axes: [3]Axis,

pub const Axis = struct {
    rs: f32,
    ls: f32,
    kf: f32,
    kbm: f32,
    max_current: f32,
    continuous_current: f32,
    gain: struct {
        current: CurrentGain,
        speed: SpeedGain,
        position: PositionGain,
    },
    arrival_threshold: f32,
};

pub const Flags = struct {
    home_exists: bool,
    has_neighbor: packed struct(u2) {
        backward: bool,
        forward: bool,
    },
    use_axis: packed struct(u2) {
        axis2: bool,
        axis3: bool,
    },
    calibration_spare: packed struct(u2) {
        backward: bool,
        forward: bool,
    },
    collision_avoidance: bool,
    calibration_use: bool,
    xts: bool,
    /// Flip all sensors in a driver
    flip: bool,
    /// Swap all sensors in a driver
    swap: bool,
};

pub const CcLinkSpeed = enum(u8) {
    @"156 kbps",
    @"625 kbps",
    @"2.5 Mbps",
    @"5 Mbps",
    @"10 Mbps",
    _,
};

pub const CurrentGain = struct {
    p: f32,
    i: f32,
    denominator: u16,
};

pub const SpeedGain = struct {
    p: f32,
    i: f32,
    denominator: u16,
    denominator_pi: u16,
};

pub const PositionGain = struct {
    p: f32,
    denominator: u16,
};
