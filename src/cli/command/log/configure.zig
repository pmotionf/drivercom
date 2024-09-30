const std = @import("std");
const cli = @import("../../../cli.zig");
const command = @import("../../command.zig");
const args = @import("args");
const drivercom = @import("drivercom");

/// Logging parameters file.
file: ?[]const u8 = null,

pub const shorthands = .{
    .f = "file",
};

pub const meta = .{
    .full_text = "Configure driver logging parameters.",
    .usage_summary = "[--file]",

    .option_docs = .{
        .file = "logging parameters file",
    },
};

pub fn help(_: @This()) !void {
    const stdout = std.io.getStdOut().writer();
    try args.printHelp(
        @This(),
        "drivercom [--port] [--timeout] log.configure",
        stdout,
    );
}

pub fn execute(self: @This()) !void {
    if (cli.port == null) {
        std.log.err("serial port must be provided", .{});
        return;
    }
    const file = try std.fs.cwd().openFile(self.file orelse {
        std.log.err("params file must be provided", .{});
        return;
    }, .{});
    defer file.close();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const file_str = try file.readToEndAlloc(allocator, 1_024_000_000);
    defer allocator.free(file_str);
    const params = (try std.json.parseFromSlice(
        drivercom.Log,
        allocator,
        file_str,
        .{
            .ignore_unknown_fields = true,
        },
    )).value;

    var sequence: u16 = 0;
    var msg = drivercom.Message.init(
        .log_set_cycles,
        sequence,
        params.cycles,
    );
    try command.sendMessage(&msg);

    sequence += 1;
    msg = drivercom.Message.init(
        .log_set_conf,
        sequence,
        params.config,
    );
    try command.sendMessage(&msg);

    sequence += 1;
    msg = drivercom.Message.init(
        .log_set_axis,
        sequence,
        .{
            .axis1 = params.axes[0],
            .axis2 = params.axes[1],
            .axis3 = params.axes[2],
        },
    );
    try command.sendMessage(&msg);

    sequence += 1;
    msg = drivercom.Message.init(
        .log_set_vehicles,
        sequence,
        .{
            params.vehicles[0],
            params.vehicles[1],
            params.vehicles[2],
            params.vehicles[3],
        },
    );
    try command.sendMessage(&msg);

    sequence += 1;
    msg = drivercom.Message.init(
        .log_set_sensors,
        sequence,
        .{
            .sensor1 = params.hall_sensors[0],
            .sensor2 = params.hall_sensors[1],
            .sensor3 = params.hall_sensors[2],
            .sensor4 = params.hall_sensors[3],
            .sensor5 = params.hall_sensors[4],
            .sensor6 = params.hall_sensors[5],
        },
    );
    try command.sendMessage(&msg);

    sequence += 1;
    msg = drivercom.Message.init(.log_set_start, sequence, .{
        .start = params.start.kind,
        .start_condition_and = params.start.combinator == .@"and",
        .start_condition_or = params.start.combinator == .@"or",
        .vehicle1 = params.start.vehicles[0],
        .vehicle2 = params.start.vehicles[1],
        .vehicle3 = params.start.vehicles[2],
        .vehicle4 = params.start.vehicles[3],
        .hall_sensor_1 = params.start.hall_sensors[0],
        .hall_sensor_2 = params.start.hall_sensors[1],
        .hall_sensor_3 = params.start.hall_sensors[2],
        .hall_sensor_4 = params.start.hall_sensors[3],
        .hall_sensor_5 = params.start.hall_sensors[4],
        .hall_sensor_6 = params.start.hall_sensors[5],
    });
    try command.sendMessage(&msg);

    sequence += 1;
    msg = drivercom.Message.init(
        .log_status,
        sequence,
        .{ .status = .stopped, .cycles_completed = 0 },
    );
    while (true) {
        try command.sendMessage(&msg);
        const req = try command.readMessage();
        if (req.kind == .log_status and req.sequence == sequence) {
            const payload = req.payload(.log_status);
            if (payload.status == .invalid) {
                std.log.err("invalid log parameters", .{});
                return;
            }
            break;
        }
    }
}
