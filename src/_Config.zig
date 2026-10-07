//! This module represents driver's configuration.
const std = @import("std");
const Config = @This();

/// Driver ID
id: u16,
/// CC-Link Station ID
station: u16,
/// CC-Link baud rate
cc_link_speed: CcLinkSpeed,
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
angle_offset: f32, // Can be changed from `set_calibration_info` command
state: State, // Immutable fields, written from driver
section_count: SectionCount,
axes: [3]Axis,

/// Immutable states of driver
pub const State = struct {
    servo_enabled: bool,
    cc_link_enabled: bool,
    calibrated: bool,
    vdc: f32,
    thermo: f32,
    sys_version: f32,
    sensor: struct {
        home: u8,
        id0: u8,
        id1: u8,
        id2: u8,
    },
    synchronization_request_position: struct {
        forward: f32,
        backward: f32,
    },
    section_count: struct {
        /// Count at which the secondary axis is switched off, depends on the
        /// slider movement direction.
        deactivate_secondary: struct {
            left: struct {
                forward: struct { axis2: i16, axis3: i16 },
                backward: struct { axis1: i16, axis2: i16 },
            },
            right: struct {
                forward: struct { axis2: i16, axis3: i16 },
                backward: struct { axis1: i16, axis2: i16 },
            },
        },
        /// Count at which the axis is activated as the primary, depends on
        /// the slider movement direction.
        activate_primary: struct {
            left: struct {
                forward: struct { axis1: i16, axis2: i16, axis3: i16 },
                backward: struct { axis1: i16, axis2: i16, axis3: i16 },
            },
            right: struct {
                forward: struct { axis1: i16, axis2: i16, axis3: i16 },
                backward: struct { axis1: i16, axis2: i16, axis3: i16 },
            },
        },
    },
    axes: [3]State.Axis,

    pub const Axis = struct {
        enabled: bool,
        primary: bool,
        slider: struct { id: u8, state: Fsm },
        entrance: Entrance,
        overcharge_state: Fsm,
        pitch_count: i16,
        mechanical_position: f32,
        // a and b needs confirmation.
        bias: struct { a: f32, b: f32 },
    };
};

pub const SectionCount = struct {
    /// Count at which the next axis in the travel direction becomes the
    /// primary and the current axis becomes the secondary.
    skip: i16,
    max: struct { axis1: i16, axis2: i16, axis3: i16 },
};

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
    base_position: f32,
    sensor: struct {
        position: struct {
            on: struct {
                /// Position of right sensor when slider moves forward and
                /// turned on the sensor
                forward: f32,
                /// Position of left sensor when slider moves backward and
                /// turned on the sensor
                backward: f32,
            },
            off: struct {
                /// Position of left sensor when slider moves forward and
                /// turned off the sensor
                forward: f32,
                /// Position of right sensor when slider moves backward and
                /// turned off the sensor
                backward: f32,
            },
        },
        section_count: struct {
            on: struct {
                /// Section count of right sensor when slider moves forward and
                /// turned on the sensor
                forward: i16,
                /// Section count of left sensor when slider moves backward and
                /// turned on the sensor
                backward: i16,
            },
            off: struct {
                /// Section count of left sensor when slider moves forward and
                /// turned off the sensor
                forward: i16,
                /// Section count of right sensor when slider moves backward and
                /// turned off the sensor
                backward: i16,
            },
        },
    },
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

pub const Fsm = enum(u8) {
    none = 0,
    warm_up = 1,
    warm_up_comp = 2,
    warm_up_fault = 3,
    curr_bias = 4,
    curr_bias_comp = 5,
    fwd_ramp = 8,
    fwd_ramp_comp = 9,
    fwd_ramp_fault = 10,
    bwd_ramp = 11,
    bwd_ramp_comp = 12,
    bwd_ramp_fault = 13,
    curr_step = 20,
    curr_step_comp = 21,
    curr_step_fault = 22,
    speed_step = 23,
    speed_step_comp = 24,
    speed_step_fault = 25,
    pos_step = 26,
    pos_step_comp = 27,
    pos_step_fault = 28,
    pos_prof = 29,
    pos_prof_comp = 30,
    pos_prof_fault = 31,
    fwd_calib = 32,
    fwd_calib_comp = 33,
    bwd_calib = 34,
    bwd_calib_comp = 35,
    speed_prof = 40,
    speed_prof_comp = 41,
    speed_prof_fault = 42,
    fwd_slave = 43,
    fwd_slave_comp = 44,
    bwd_slave = 45,
    bwd_slave_comp = 46,
    over_charge = 50,
    synch_com_error = 51,
    _,
};

pub const Entrance = enum(u8) {
    none = 0,
    left = 1,
    right = 2,
    _,
};
