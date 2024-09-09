const builtin = @import("builtin");
const std = @import("std");
const serial = @import("serial");
const cli = @import("../../../cli.zig");

pub fn execute(_: @This()) !void {
    if (cli.port != null) {
        std.log.err("`--port` should not be specified for `port.detect`", .{});
        return;
    }

    var port_iterator = try serial.list();
    defer port_iterator.deinit();
    const stdout = std.io.getStdOut().writer();

    while (try port_iterator.next()) |_port| {
        if (comptime builtin.os.tag == .linux) {
            if (_port.display_name.len < "/dev/ttyUSBX".len) {
                continue;
            }
            if (!std.mem.eql(
                u8,
                "/dev/ttyUSB",
                _port.display_name[0.."/dev/ttyUSB".len],
            )) {
                continue;
            }
        }
        try stdout.print("{s}\n", .{_port.display_name});
    }
}
