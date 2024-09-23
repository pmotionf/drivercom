const builtin = @import("builtin");
const std = @import("std");

const drivercon = @import("drivercon");
const serialport = @import("serialport");
const cli = @import("../../../cli.zig");

pub fn execute(_: @This()) !void {
    if (cli.port != null) {
        std.log.err("`--port` should not be specified for `port.detect`", .{});
        return;
    }

    var port_iterator = try serialport.iterate();
    defer port_iterator.deinit();

    var random = std.Random.DefaultPrng.init(0);
    const random_connection_seed = random.random().int(u32);

    var attempted_connections: usize = 0;

    while (try port_iterator.next()) |_port| {
        std.log.info(
            "Attempting connection with COM port: {s} ({s})",
            .{ _port.path, _port.name },
        );
        attempted_connections += 1;

        // Attempt connection.
        var port = _port.open() catch continue;
        defer {
            port.flush(.{ .input = true, .output = true }) catch {};
            port.close();
        }

        port.configure(.{
            .baud_rate = if (comptime builtin.os.tag == .windows)
                @enumFromInt(230400)
            else
                .B230400,
        }) catch {
            continue;
        };
        port.flush(.{ .input = true, .output = true }) catch {
            continue;
        };
        std.debug.assert(try port.poll() == false);

        const writer = port.writer();
        const reader = port.reader();

        var connection_made: bool = false;

        const msg = drivercon.Message.init(.ping, 0, random_connection_seed);
        var retry: usize = 0;

        var read_buffer: [16]u8 = undefined;
        retry_loop: while (retry < 3) {
            writer.writeAll(std.mem.asBytes(&msg)) catch {
                continue;
            };

            var timer = try std.time.Timer.start();
            var read_size: usize = 0;
            while (timer.read() < std.time.ns_per_ms * cli.timeout) {
                if (try port.poll()) {
                    read_size += try reader.read(read_buffer[read_size..]);
                    if (read_size == 16) break :retry_loop;
                    timer.reset();
                }
            } else {
                std.log.err("driver response timed out: {}", .{msg.kind});
                try port.flush(.{ .input = true, .output = true });
                retry += 1;
                continue;
            }
            std.debug.assert(read_size == 16);
        } else continue;

        var rsp = std.mem.bytesToValue(drivercon.Message, &read_buffer);

        if (rsp.kind == .response and
            rsp.bcc == rsp.getBcc() and
            rsp.payload(.ping) == random_connection_seed)
        {
            connection_made = true;
        }

        if (connection_made) {
            const stdout = std.io.getStdOut().writer();
            try stdout.print(
                "\nConnection found: {s} ({s})\n",
                .{ _port.path, _port.name },
            );
            return;
        }
    }
    const stderr = std.io.getStdErr().writer();
    try stderr.print(
        "{s}No PMF Smart Driver COM port detected.\n",
        .{if (attempted_connections > 0) "\n" else ""},
    );
}
