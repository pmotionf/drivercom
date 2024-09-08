pub const detect = @import("port/detect.zig");
pub const list = @import("port/list.zig");
pub const ping = @import("port/ping.zig");

const std = @import("std");
const cli = @import("../../cli.zig");

pub fn help() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.writeAll("Available `port` commands:\n");
    const ti = @typeInfo(@This()).@"struct";

    inline for (ti.decls) |decl| {
        if (comptime std.mem.eql(u8, "execute", decl.name)) continue;
        if (comptime std.mem.eql(u8, "help", decl.name)) continue;
        try stdout.print("\tport.{s}\n", .{decl.name});
    }
}

pub fn execute(_: @This()) !void {
    if (cli.help) {
        try help();
    } else {
        std.log.err("`port` is not valid standalone command", .{});
    }
}
