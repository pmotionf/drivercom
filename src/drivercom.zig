const std = @import("std");

/// `drivercom` version; always matches version in `build.zig.zon`.
pub const version = std.SemanticVersion.parse("0.4.0") catch unreachable;

pub const Config = @import("Config.zig");
pub const OldConfig = @import("OldConfig.zig");
pub const Log = @import("Log.zig");
pub const Message = @import("message.zig").Message;

pub const gain = struct {
    pub const current = struct {
        pub fn wcc(denominator: u32) f64 {
            return 2.0 * std.math.pi * (15000.0 / @as(
                f64,
                @floatFromInt(denominator),
            ));
        }

        pub fn p(ls: f64, wcc_: f64) f64 {
            return ls * wcc_;
        }

        pub fn i(rs: f64, wcc_: f64) f64 {
            return rs * wcc_;
        }
    };

    pub const velocity = struct {
        pub fn wsc(denominator: u32, wcc: f64) f64 {
            return wcc / @as(f64, @floatFromInt(denominator));
        }

        pub fn wpi(denominator: u32, wsc_: f64) f64 {
            return wsc_ / @as(f64, @floatFromInt(denominator));
        }

        pub fn radius(pitch: f64) f64 {
            return pitch / (2.0 * std.math.pi);
        }

        pub fn inertia(mass: f64, radius_: f64) f64 {
            return mass * radius_ * radius_;
        }

        pub fn torqueConstant(force_constant: f64, radius_: f64) f64 {
            return force_constant * radius_;
        }

        pub fn p(inertia_: f64, torque_constant: f64, wsc_: f64) f64 {
            return (inertia_ * wsc_) / torque_constant;
        }

        pub fn i(p_: f64, wpi_: f64) f64 {
            return p_ * wpi_;
        }
    };

    pub const position = struct {
        pub fn wpc(denominator: u32, wsc: f64) f64 {
            return wsc / @as(f64, @floatFromInt(denominator));
        }

        pub fn p(wpc_: f64) f64 {
            return wpc_;
        }
    };
};

pub const DriverMessage = enum(u16) {
    none,
    update,
    prof_req,
    prof_noti,
    update_cali_home,
    update_mech_angle_offset,
    cali_on_pos_req,
    cali_on_pos_rsp,
    cali_off_pos_req,
    cali_off_pos_rsp,
    clear_carrier_info,
};

pub const CarrierState = enum(u16) {
    None = 0x0,

    WarmupProgressing,
    WarmupCompleted,

    PosMoveProgressing = 0x4,
    PosMoveCompleted,
    SpdMoveProgressing,
    SpdMoveCompleted,
    Auxiliary,
    AuxiliaryCompleted,

    ForwardCalibrationProgressing = 0xA,
    ForwardCalibrationCompleted,
    BackwardCalibrationProgressing,
    BackwardCalibrationCompleted,

    ForwardIsolationProgressing = 0x10,
    ForwardIsolationCompleted,
    BackwardIsolationProgressing,
    BackwardIsolationCompleted,
    ForwardRestartProgressing,
    ForwardRestartCompleted,
    BackwardRestartProgressing,
    BackwardRestartCompleted,

    PullForward = 0x1A,
    PullForwardCompleted,
    PullBackward,
    PullBackwardCompleted,

    Overcurrent = 0x1F,
};

test {
    std.testing.refAllDeclsRecursive(@This());
}
