//! This module represents a PMF Smart Driver's configuration.
const std = @import("std");
const drivercon = @import("drivercon.zig");

pub const MAX_AXES = 3;

/// Driver ID.
id: u16,

/// Driver's CC-Link Station ID.
station_id: u16,

flags: SystemFlags,

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

total_axes: u16,

warmup_voltage_reference: f32,

calibration_magnet_length: struct {
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
    max_current: f32,
    continuous_current: f32,
    current_gain: CurrentGain,
    velocity_gain: VelocityGain,
    position_gain: PositionGain,
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

    /// Resistance.
    rs: f32,
    /// Inductance.
    ls: f32,
    /// Force constant.
    kf: f32,
    kbm: f32,
};

pub const HallSensor = struct {
    calibrated_magnet_length: struct {
        backward: f32,
        forward: f32,
    },
};

pub const SystemFlags = packed struct {
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
};

pub fn calcCurrentGain(
    self: *const @This(),
    axis_index: usize,
    denominator: u32,
) CurrentGain {
    std.debug.assert(axis_index < MAX_AXES);
    const axis = self.axes[axis_index];

    const wcc = drivercon.gain.current.wcc(denominator);
    return .{
        .denominator = denominator,
        .p = @floatCast(
            drivercon.gain.current.p(axis.ls, wcc),
        ),
        .i = @floatCast(
            drivercon.gain.current.i(axis.rs, wcc),
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

    const wcc = drivercon.gain.current.wcc(axis.current_gain.denominator);
    const radius = drivercon.gain.velocity.radius(self.magnet.pitch);
    const inertia = drivercon.gain.velocity.inertia(self.vehicle_mass, radius);
    const torque_constant =
        drivercon.gain.velocity.torqueConstant(axis.kf, radius);
    const wsc = drivercon.gain.velocity.wsc(denominator, wcc);
    const wpi = drivercon.gain.velocity.wpi(denominator_pi, wsc);
    const p = drivercon.gain.velocity.p(inertia, torque_constant, wsc);

    return .{
        .p = @floatCast(p),
        .i = @floatCast(drivercon.gain.velocity.i(p, wpi)),
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

    const wcc = drivercon.gain.current.wcc(axis.current_gain.denominator);
    const wsc =
        drivercon.gain.velocity.wsc(axis.velocity_gain.denominator, wcc);

    const wpc = drivercon.gain.position.wpc(denominator, wsc);
    const p = drivercon.gain.position.p(wpc);

    return .{
        .p = @floatCast(p),
        .denominator = denominator,
    };
}