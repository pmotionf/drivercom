//! This module represents a PMF Smart Driver's configuration.

/// Driver ID.
id: u16,

/// Driver's CC-Link Station ID.
station_id: u16,

flags: packed struct(u16) {
    home_sensor: u1,
    has_neighbor: packed struct(u2) {
        backward: u1,
        forward: u1,
    },
    uses_axis: packed struct(u2) {
        axis2: u1,
        axis3: u1,
    },
    calibration_completed: u1,
    rockwell_magnet: u1,
    _7: u9 = 0,
},

magnet: struct {
    /// Magnet pole pair pitch in meters.
    pitch: f32,
    length: f32,
},

/// Vehicle mass in kg.
vehicle_mass: f32,

mechanical_angle_offset: f32,

axis_length: f32,

/// Motor coil length in meters.
motor_length: f32,

calibrated_home_position: f32,

system_axes: u32,

warmup_voltage_reference: f32,

calibrated_magnet_length: struct {
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

pub const Axis = struct {
    max_current: f32,
    continuous_current: f32,
    current_gain: struct {
        p: f32,
        i: f32,
        denominator: u32,
    },
    velocity_gain: struct {
        p: f32,
        i: f32,
        denominator: u32,
        denominator_pi: u32,
    },
    position_gain: struct {
        p: f32,
        denominator: u32,
    },
    in_position_threshold: f32,
    base_position: f32,
    back_sensor_off: struct {
        position: i16,
        section_count: i16,
    },
    front_sensor_off: struct {
        position: i16,
        section_count: i16,
    },

    rs: f32,
    ls: f32,
    kf: f32,
    kbm: f32,
};

pub const HallSensor = struct {
    magnet_length: struct {
        backward: f32,
        forward: f32,
    },
};
