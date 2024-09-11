const builtin = @import("builtin");
const std = @import("std");

const drivercon = @import("drivercon");
const serial = @import("serial");
const cli = @import("../../../cli.zig");

pub fn execute(_: @This()) !void {
    if (cli.port != null) {
        std.log.err("`--port` should not be specified for `port.detect`", .{});
        return;
    }

    var port_iterator = try serial.list();
    defer port_iterator.deinit();

    var random = std.Random.DefaultPrng.init(0);
    const random_connection_seed = random.random().int(u32);

    var attempted_connections: usize = 0;

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
        std.log.info(
            "Attempting connection with COM port: {s}",
            .{_port.display_name},
        );
        attempted_connections += 1;

        // Attempt connection.
        var port = std.fs.cwd().openFile(_port.file_name, .{
            .mode = .read_write,
        }) catch {
            continue;
        };
        defer {
            serial.flushSerialPort(port, true, true) catch {};
            port.close();
        }

        serial.configureSerialPort(port, .{
            .handshake = .none,
            .baud_rate = 230400,
            .parity = .none,
            .word_size = .eight,
            .stop_bits = .one,
        }) catch {
            continue;
        };
        serial.flushSerialPort(port, true, true) catch {};

        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        var poller = std.io.poll(allocator, enum { f }, .{ .f = port });
        defer poller.deinit();
        var fifo = poller.fifo(.f);

        var writer = port.writer();

        var connection_made: bool = false;

        const msg = drivercon.Message.init(.ping, 0, random_connection_seed);
        writer.writeAll(std.mem.asBytes(&msg)) catch {
            continue;
        };

        var timer = try std.time.Timer.start();
        while (timer.read() < std.time.ns_per_ms * cli.timeout) {
            if (try poller.pollTimeout(0)) {
                if (fifo.readableLength() < 16) {
                    timer.reset();
                } else break;
            }
        } else {
            std.log.err("driver response timed out: {}", .{msg.kind});
            try serial.flushSerialPort(port, true, true);
            continue;
        }

        var rsp: drivercon.Message = undefined;
        const read_size = fifo.read(std.mem.asBytes(&rsp));
        std.debug.assert(read_size == 16);

        if (rsp.kind == .response and
            rsp.bcc == rsp.getBcc() and
            rsp.payload(.ping) == random_connection_seed)
        {
            connection_made = true;
        }

        if (connection_made) {
            const stdout = std.io.getStdOut().writer();
            try stdout.print("\nConnection found: {s}\n", .{_port.display_name});
            return;
        }
    }
    const stderr = std.io.getStdErr().writer();
    try stderr.print(
        "{s}No PMF Smart Driver COM port detected.\n",
        .{if (attempted_connections > 0) "\n" else ""},
    );
}
