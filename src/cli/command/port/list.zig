const builtin = @import("builtin");
const std = @import("std");

const args = @import("args");
const serialport = @import("serialport");
const cli = @import("../../../cli.zig");

pub const meta = .{
    .full_text = "List all system serial ports.",
    .usage_summary = "",
};

pub fn help(_: @This()) !void {
    const stdout = std.io.getStdOut().writer();
    try args.printHelp(
        @This(),
        "drivercon [--port] [--timeout] config.set",
        stdout,
    );
}

pub fn execute(_: @This()) !void {
    if (cli.port != null) {
        std.log.err("`--port` should not be specified for `port.detect`", .{});
        return;
    }

    var port_iterator = try serialport.iterate();
    defer port_iterator.deinit();
    const stdout = std.io.getStdOut().writer();

    while (try port_iterator.next()) |_port| {
        try stdout.print("{s} ({s})\n", .{ _port.path, _port.name });
    }
}
