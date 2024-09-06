const builtin = @import("builtin");
const std = @import("std");

const drivercon = @import("drivercon");
const serial = @import("serial");

pub fn execute(_: @This()) !void {
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

        var writer = port.writer();
        var reader = port.reader();

        var connection_made: bool = false;

        var init_message: drivercon.Message = .{
            .kind = .ping,
            .sequence = 0,
            .payload = .{ .u32 = .{ random_connection_seed, 0 } },
            .cycle = 0,
            .bcc = undefined,
        };
        init_message.setBcc();
        writer.writeAll(std.mem.asBytes(&init_message)) catch {
            continue;
        };

        var buffer: [16]u8 = undefined;
        const read_size = reader.readAll(&buffer) catch {
            continue;
        };
        if (read_size != 16) {
            continue;
        }
        const response: *const drivercon.Message = @alignCast(
            std.mem.bytesAsValue(drivercon.Message, &buffer),
        );
        if (response.kind == .response and
            response.bcc == response.getBcc() and
            response.payload.u32[0] == random_connection_seed)
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
