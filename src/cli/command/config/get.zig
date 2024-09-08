pub const id = @import("get/id.zig");

const std = @import("std");
const cli = @import("../../../cli.zig");
const args = @import("args");

file: ?[]const u8 = null,

pub const shorthands = .{
    .f = "file",
};

pub const meta = .{
    .full_text = "Retrieve PMF Smart Driver configuration.",
    .usage_summary = "[--file]",

    .option_docs = .{
        .file = "save retrieved driver configuration to file",
    },
};

pub fn help() !void {
    const stdout = std.io.getStdOut().writer();
    try args.printHelp(
        @This(),
        "drivercon [--port] [--timeout] config.get",
        stdout,
    );
}

pub fn execute(self: @This()) !void {
    if (cli.help) {
        try help();
        return;
    }
    if (self.file) |f| {
        _ = &f;
    }
}
