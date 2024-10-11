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

test {
    std.testing.refAllDeclsRecursive(@This());
}
