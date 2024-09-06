const builtin = @import("builtin");
const std = @import("std");

const args = @import("args");
const drivercon = @import("drivercon");
const serial = @import("serial");
const command = @import("cli/command.zig");

pub var port: ?std.fs.File = null;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const options = args.parseWithVerbForCurrentProcess(
        struct {
            port: ?[]const u8 = null,
            /// Serial communication reponse timeout in milliseconds.
            timeout: usize = 100,

            pub const shorthands = .{
                .p = "port",
                .t = "timeout",
            };
        },
        union(enum) {
            @"port.detect": command.port.detect,
            @"port.list": command.port.list,
            @"port.ping": command.port.ping,
        },
        allocator,
        .print,
    ) catch return;

    if (options.verb) |verb| switch (verb) {
        inline else => |cmd| try cmd.execute(),
    };
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
