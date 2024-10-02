const std = @import("std");
const cli = @import("../../cli.zig");
const args = @import("args");

pub const meta = .{
    .full_text = "Retrieve drivercom CLI version.",
    .usage_summary = "",

    .option_docs = .{},
};

pub fn help(_: @This()) !void {
    const stdout = std.io.getStdOut().writer();
    try args.printHelp(
        @This(),
        "drivercom [--port] [--timeout] version",
        stdout,
    );
}

pub fn execute(_: @This()) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print(
        "{}.{}.{}\n",
        .{ cli.version.major, cli.version.minor, cli.version.patch },
    );
}
