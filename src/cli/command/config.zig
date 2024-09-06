pub const get = @import("config/get.zig");
pub const set = @import("config/set.zig");

const std = @import("std");
const cli = @import("root");

pub fn help() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.writeAll("Available `config` commands:\n");
    const ti = @typeInfo(@This()).@"struct";

    inline for (ti.decls) |decl| {
        if (comptime std.mem.eql(u8, "execute", decl.name)) continue;
        if (comptime std.mem.eql(u8, "help", decl.name)) continue;
        try stdout.print("\tconfig.{s}\n", .{decl.name});
    }
}

pub fn execute(_: @This()) !void {
    if (cli.help) {
        try help();
    } else {
        std.log.err("`config` is not valid standalone command", .{});
    }
}
