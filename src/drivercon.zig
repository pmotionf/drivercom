const std = @import("std");

pub const Config = @import("Config.zig");

pub const Message = extern struct {
    kind: Kind,
    sequence: u16 = 0,
    payload: extern union {
        u32: [2]u32,
        f32: [2]f32,
        i16: [4]i16,
        u16: [4]u16,
        u8: [8]u8,
    } = .{ .u8 = .{0} ** 8 },
    cycle: u16 = 0,
    _120: u8 = 0,
    bcc: u8 = undefined,

    pub const Kind = enum(u16) {
        response = 0x1,
        ping = 0x2,
        start_sequence = 0x10,
        end_sequence = 0x11,
        save_config = 0x12,
        get_id_station = 0x13,
        set_id_station = 0x14,
    };

    pub fn getBcc(self: *const Message) u8 {
        const bytes: []const u8 = std.mem.asBytes(self);
        var bcc: u8 = 0;
        for (bytes[0..15]) |b| {
            bcc ^= b;
        }
        return bcc;
    }

    pub fn setBcc(self: *Message) void {
        const bytes: []const u8 = std.mem.asBytes(self);
        var bcc: u8 = 0;
        for (bytes[0..15]) |b| {
            bcc ^= b;
        }
        self.bcc = bcc;
    }
};
