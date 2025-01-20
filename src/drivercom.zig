const std = @import("std");

pub const Config = @import("Config.zig");
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
    poss_req,
    poss_rsp,
    ack_sens,
    upt_info,
    prof_req,
    prof_ack,
    rstrt_req,
    rstrt_ack,
    mpos_req,
    mpos_rsp,
    prof_noti,
    cali_noti,
    update_cali_home,
};

pub const VehicleState = enum(u16) {
    none_choice = 0,
    warmup_choice = 1,
    warmup_comp_choice,
    warmup_fault_choice,
    curr_bias_choice,
    curr_bias_comp_choice, // 5
    pos_prof_choice = 29,
    pos_prof_comp_choice, // 30
    fwd_cali_choice = 32,
    fwd_cali_comp_choice,
    bwd_isol_choice,
    bwd_isol_comp_choice, // 35
    fwd_rstrt_choice,
    fwd_rstrt_comp_choice,
    bwd_rstrt_choice,
    bwd_rstrt_comp_choice,
    speed_prof_choice, // 40
    speed_prof_comp_choice,
    fwd_slave_choice = 43,
    fwd_slave_comp_choice,
    bwd_slave_choice, // 45
    bwd_slave_comp_choice,
    fwd_isol_choice,
    fwd_isol_comp_choice,

    overcharge_choice = 50, // 50
    comerr_choice,

    fwd_pull_choice,
    fwd_pull_comp_choice,
    fwd_pull_fault_choice,
    bwd_pull_choice, // 55
    bwd_pull_comp_choice,
    bwd_pull_fault_choice,
    bwd_cali_choice,
    bwd_cali_comp_choice,
    bwd_cali_fault_choice, // 60
    fwd_cali_fault_choice,
};

test {
    std.testing.refAllDeclsRecursive(@This());
}
