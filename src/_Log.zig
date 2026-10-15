//! This module represents driver's logging configuration. The driver runs the
//! command while recording the configured items of the selected axes at 15000
//! samples per second.
const std = @import("std");

/// Logging duration (s).
duration: f32,
/// Items to be logged on every selected axis.
config: Config,
/// Axes to be logged.
axes: [3]bool,
/// ID of the slider targeted by the command.
slider_id: u8,
/// Command run by the driver while logging.
command: Command,

pub const Command = union(Kind) {
    // TODO: Support the remaining commands SHDrv provide:
    // - Offline commands with applied voltage (V) and applied angle (turn):
    //   current_state = 0, warm_up = 1, move_home = 2, move_forward = 3,
    //   move_backward = 4, restart = 5, move_synchronous = 6, move_dq = 7
    // - current_step = 10 with Q current step (A)
    // - speed_step = 11 with speed step (m/s)
    // - position_step = 12 with position step
    position_profile: Profile,
    speed_profile: Profile,

    pub const Kind = enum(u8) {
        position_profile = 13,
        speed_profile = 14,
    };

    pub const Profile = struct {
        // Unit is unconfirmed: SHDrv labels it m but limits it as rad.
        /// Travel distance. Negative distance travels backward.
        distance: f32,
        /// Percentage of the maximum speed (%).
        speed: f32,
        /// Percentage of the maximum acceleration (%).
        acceleration: f32,
    };
};

/// Field order is the item index. The response tags the item with its index
/// plus one.
pub const Config = packed struct(u32) {
    /// Output position of the profile.
    profile_position: bool,
    /// Applied speed of the profile.
    profile_speed: bool,
    /// Output of the position controller.
    position_output: bool,
    /// Reference of the position controller (rad).
    position_reference: bool,
    /// Feedback of the position controller (rad).
    position_feedback: bool,
    /// Reference of the speed controller (rad/s).
    speed_reference: bool,
    /// Feedback of the speed controller (rad/s).
    speed_feedback: bool,
    current_q_reference: bool,
    current_q_feedback: bool,
    current_d_feedback: bool,
    voltage_q_reference: bool,
    voltage_d_reference: bool,
    voltage_q_feedforward: bool,
    voltage_d_feedforward: bool,
    /// Calculation time of the control loop.
    calculation_time: bool,
    theta_section: bool,
    electrical_angular_speed: bool,
    in_position: bool,
    current_a: bool,
    current_b: bool,
    current_c: bool,
    voltage_alpha: bool,
    voltage_beta: bool,
    /// State of the slider's FSM.
    slider_state: bool,
    applied_angle: bool,
    encoder_angle: bool,
    voltage_a: bool,
    voltage_b: bool,
    voltage_c: bool,
    vector_sector: bool,
    hall_alarm_left: bool,
    hall_alarm_right: bool,
};

test {
    std.testing.refAllDecls(@This());
}
