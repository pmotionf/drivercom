const builtin = @import("builtin");
const std = @import("std");

const args = @import("args");
const drivercom = @import("drivercom");
const serialport = @import("serialport");
const command = @import("cli/command.zig");

pub const version: std.SemanticVersion = .{
    .major = 0,
    .minor = 2,
    .patch = 0,
};

pub var port: ?serialport.Port = null;
pub var timeout: usize = 1000;
pub var retry: usize = 3;
pub var positionals: [][]const u8 = &.{};

var ec = args.ErrorCollection.init(std.heap.page_allocator);

fn printCommands(
    category: type,
    comptime name: []const u8,
    layer: usize,
) !void {
    const ti = @typeInfo(category).@"struct";
    inline for (ti.decls) |decl| {
        if (std.mem.eql(u8, "shorthands", decl.name)) break;
        if (std.mem.eql(u8, "meta", decl.name)) break;

        const potential_fn_ti =
            @typeInfo(@TypeOf(@field(category, decl.name)));
        switch (potential_fn_ti) {
            .type => {
                const real_type = @field(category, decl.name);
                const real_ti = @typeInfo(real_type);
                switch (real_ti) {
                    .@"struct" => {},
                    else => continue,
                }
            },
            else => continue,
        }

        const child_type = @field(category, decl.name);
        const child_name = if (name.len > 0)
            name ++ "." ++ decl.name
        else
            decl.name;

        const stdout = std.io.getStdOut().writer();
        try stdout.writeByteNTimes(' ', (layer) * 4);
        if (!@hasDecl(child_type, "execute")) {
            try stdout.writeByte('[');
        }
        try stdout.writeAll(child_name);
        if (!@hasDecl(child_type, "execute")) {
            try stdout.writeByte(']');
        }
        try stdout.writeByte('\n');
        try printCommands(child_type, child_name, layer + 1);
    }
}

fn enumerateCommands(
    layer: type,
    name: []const u8,
    result: *std.builtin.Type.Union,
) void {
    const ti = @typeInfo(layer).@"struct";
    for (ti.decls) |decl| {
        if (std.mem.eql(u8, "shorthands", decl.name)) continue;
        if (std.mem.eql(u8, "meta", decl.name)) continue;

        const potential_fn_ti = @typeInfo(@TypeOf(@field(layer, decl.name)));
        switch (potential_fn_ti) {
            .type => {
                const real_type = @field(layer, decl.name);
                const real_ti = @typeInfo(real_type);
                switch (real_ti) {
                    .@"struct" => {},
                    else => continue,
                }
            },
            else => continue,
        }

        const child_type = @field(layer, decl.name);
        const child_name = if (name.len > 0)
            name ++ "." ++ decl.name
        else
            decl.name;

        result.fields = result.fields ++ .{
            std.builtin.Type.UnionField{
                .name = child_name,
                .type = child_type,
                .alignment = @alignOf(child_type),
            },
        };

        enumerateCommands(child_type, child_name, result);
    }
}

pub const Commands = b: {
    var result: std.builtin.Type.Union = .{
        .layout = .auto,
        .tag_type = null,
        .fields = &.{},
        .decls = &.{},
    };
    enumerateCommands(command, "", &result);

    var result_tag: std.builtin.Type.Enum = .{
        .tag_type = u16,
        .fields = &.{},
        .decls = &.{},
        .is_exhaustive = true,
    };
    for (result.fields, 0..) |field, i| {
        result_tag.fields = result_tag.fields ++ .{
            std.builtin.Type.EnumField{
                .name = field.name,
                .value = @intCast(i),
            },
        };
    }
    result.tag_type = @Type(.{ .@"enum" = result_tag });
    break :b @Type(.{ .@"union" = result });
};

pub const CommandsTag = std.meta.Tag(Commands);

pub const Options = struct {
    commands: bool = false,
    port: ?[]const u8 = null,
    /// Serial communication reponse timeout in milliseconds.
    timeout: usize = 100,
    help: bool = false,
    retry: usize = 3,

    pub const shorthands = .{
        .p = "port",
        .t = "timeout",
        .r = "retry",
    };

    pub const meta = .{
        .full_text = "PMF Smart Driver connection utility.",
        .usage_summary = "[--port] [--timeout] [--retry] <command>",

        .option_docs = .{
            .help = "command usage guidance",
            .commands = "list (sub)commands",
            .port = "serial port (name or path) to use for driver connection",
            .timeout = "timeout for message response",
            .retry = "number of message retries before failure",
        },
    };
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
        try args.printHelp(Options, "drivercom", stdout);
        return;
    };

    var commands_list: bool = false;
    var _port_str: ?[]const u8 = null;
    var help: bool = false;
    inline for (std.meta.fields(@TypeOf(options.options))) |fld| {
        if (comptime std.mem.eql(u8, "help", fld.name)) {
            help = @field(options.options, fld.name);
        }
        if (comptime std.mem.eql(u8, "timeout", fld.name)) {
            timeout = @field(options.options, fld.name);
        }
        if (comptime std.mem.eql(u8, "port", fld.name)) {
            _port_str = @field(options.options, fld.name);
        }
        if (comptime std.mem.eql(u8, "commands", fld.name)) {
            commands_list = @field(options.options, fld.name);
        }
    }

    if (_port_str) |port_str| b: {
        if (help or options.verb == null) break :b;
        var port_iterator = try serialport.iterate();
        defer port_iterator.deinit();

        while (try port_iterator.next()) |_port| {
            if (!std.mem.eql(u8, port_str, _port.path) and
                !std.mem.eql(u8, port_str, _port.name))
            {
                continue;
            }

            port = try _port.open();
            errdefer {
                port.?.flush(.{ .input = true, .output = true }) catch {};
                port.?.close();
                port = null;
            }

            try port.?.configure(.{
                .baud_rate = if (comptime builtin.target.os.tag == .windows)
                    @enumFromInt(230400)
                else
                    .B230400,
            });
            port.?.flush(.{ .input = true, .output = true }) catch {};
            std.debug.assert(try port.?.poll() == false);
            break;
        } else {
            std.log.err(
                "No serial port found with name/path: {s}\n",
                .{port_str},
            );
        }
    }
    defer {
        if (port) |*p| {
            p.flush(.{ .input = true, .output = true }) catch {};
            p.close();
            port = null;
        }
    }

    positionals = options.positionals;

    if (options.verb) |verb| switch (verb) {
        inline else => |cmd| {
            if (@hasDecl(@TypeOf(cmd), "execute") and !commands_list) {
                if (help) {
                    try cmd.help();
                } else {
                    try cmd.execute();
                }
            } else {
                // This is just a command category: print sub-commands.
                try printCommandsListLegend();

                const cmd_type = @TypeOf(cmd);
                const cmd_ti: std.builtin.Type.Union =
                    @typeInfo(@TypeOf(verb)).@"union";

                inline for (cmd_ti.fields) |field| {
                    if (field.type == cmd_type) {
                        if (@hasDecl(cmd_type, "execute")) {
                            try stdout.print("{s}\n", .{field.name});
                        } else {
                            try stdout.print("[{s}]\n", .{field.name});
                        }
                        try printCommands(cmd_type, field.name, 1);
                    }
                }
            }
        },
    } else {
        try args.printHelp(Options, "drivercom", stdout);
        try stdout.writeAll("\nCommands:\n");
        try printCommandsListLegend();
        try printCommands(command, "", 0);
    }
}

fn printCommandsListLegend() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.writeByteNTimes('-', 17);
    try stdout.writeByte('+');
    try stdout.writeByteNTimes('-', 36);
    try stdout.writeByte('\n');
    try stdout.writeAll("  command_name:  | Executable command\n" ++
        " [command_name]: | Command category (not executable)\n");
    try stdout.writeByteNTimes('-', 17);
    try stdout.writeByte('+');
    try stdout.writeByteNTimes('-', 36);
    try stdout.writeByteNTimes('\n', 2);
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
