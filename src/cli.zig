const builtin = @import("builtin");
const std = @import("std");

const args = @import("args");
const drivercon = @import("drivercon");
const serial = @import("serial");
const command = @import("cli/command.zig");

const StreamEnum = enum { f };

pub var port: ?std.fs.File = null;
pub var poller: std.io.Poller(StreamEnum) = undefined;
pub var fifo: *std.io.PollFifo = undefined;
pub var help: bool = false;
pub var timeout: usize = 100;
pub var retry: usize = 3;
pub var positionals: [][]const u8 = &.{};

var ec = args.ErrorCollection.init(std.heap.page_allocator);

pub const Options = struct {
    port: ?[]const u8 = null,
    /// Serial communication reponse timeout in milliseconds.
    timeout: usize = 100,
    help: bool = false,
    retry: usize = 3,

    pub const shorthands = .{
        .p = "port",
        .t = "timeout",
        .h = "help",
        .r = "retry",
    };

    pub const meta = .{
        .full_text = "PMF Smart Driver connection utility.",
        .usage_summary = "[--port] [--timeout] [--retry] <command>",

        .option_docs = .{
            .help = "command usage guidance",
            .port = "COM port to use for driver connection",
            .timeout = "timeout for message response",
            .retry = "number of message retries before failure",
        },
    };
};

pub const Commands = union(enum) {
    firmware: command.firmware,
    port: command.port,
    @"port.detect": command.port.detect,
    @"port.list": command.port.list,
    @"port.ping": command.port.ping,
    config: command.config,
    @"config.get": command.config.get,
    @"config.get.id": command.config.get.id,
    @"config.set": command.config.set,
    @"config.set.id": command.config.set.id,
    @"config.set.gain.current": command.config.set.gain.current,
    @"config.set.gain.velocity": command.config.set.gain.velocity,
    @"config.set.gain.position": command.config.set.gain.position,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();
    defer ec.deinit();

    const options = args.parseWithVerbForCurrentProcess(
        Options,
        Commands,
        allocator,
        .{ .collect = &ec },
    ) catch {
        for (ec.errors()) |e| {
            switch (e.kind) {
                .unknown_verb => {
                    try stderr.print("Unknown command {s}\n\n", .{e.option});
                },
                else => {
                    try e.format("", .{}, stderr);
                    try stderr.writeByteNTimes('\n', 2);
                },
            }
            break;
        }
        try args.printHelp(Options, "drivercon", stdout);
        return;
    };

    var port_name: ?[]const u8 = null;
    inline for (std.meta.fields(@TypeOf(options.options))) |fld| {
        if (comptime std.mem.eql(u8, "help", fld.name)) {
            help = @field(options.options, fld.name);
        }
        if (comptime std.mem.eql(u8, "timeout", fld.name)) {
            timeout = @field(options.options, fld.name);
        }
        if (comptime std.mem.eql(u8, "port", fld.name)) {
            port_name = @field(options.options, fld.name);
        }
    }

    if (port_name) |name| {
        if (!help and options.verb != null) {
            var port_iterator = try serial.list();
            defer port_iterator.deinit();

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
                if (!std.mem.eql(u8, name, _port.display_name)) {
                    continue;
                }
                port = try std.fs.cwd().openFile(_port.file_name, .{
                    .mode = .read_write,
                });
                serial.flushSerialPort(port.?, true, true) catch {};
                poller = std.io.poll(allocator, StreamEnum, .{ .f = port.? });
                fifo = poller.fifo(.f);
                break;
            } else {
                std.log.err("No COM port found with name: {s}\n", .{name});
            }
        }
    }
    defer {
        if (port) |p| {
            poller.deinit();
            serial.flushSerialPort(p, true, true) catch {};
            p.close();
            port = null;
        }
    }

    positionals = options.positionals;

    if (options.verb) |verb| switch (verb) {
        inline else => |cmd| try cmd.execute(),
    } else {
        try args.printHelp(Options, "drivercon", stdout);
        // TODO: Print a list of commands
    }
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
