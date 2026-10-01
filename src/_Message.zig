//! Message format to Premo Robotics driver. Initialize the message by calling
//! `init()` for writing a message to the firmware or `parse()` for reading a
//! message from the firmware. Caller must call `deinit()` to free allocated
//! payload memory.

const std = @import("std");
const builtin = @import("builtin");
const Config = @import("_Config.zig");
const Message = @This();

const STX = 0x02;
const ETX = 0x03;

header: Header,
/// Payload is defined as slice of u8 since the payload is not consistent for
/// every message. It is preferred over union as union type does not guarantee
/// memory layout.
payload: []u8,
etx: u8,
/// Unused when sending message to firmware.
bcc: u8,

/// Write the message into the writer. The message is writen in Big Endian due
/// to firmware implementation are using Big Endianness.
pub fn write(self: Message, writer: *std.Io.Writer) std.Io.Writer.Error!void {
    const endian: std.builtin.Endian = .big;
    try writer.writeStruct(self.header, endian);
    try writer.writeSliceEndian(u8, self.payload, endian);
    try writer.writeInt(u8, self.etx, endian);
    try writer.writeInt(u8, getBcc(writer.buffered()[1..]), endian);
}

/// Create message structure given its payload values and kind
pub fn init(
    gpa: std.mem.Allocator,
    comptime kind: Kind,
    comptime message_type: Type,
    sequence: u8,
    p: PayloadType(kind, message_type),
) Message {
    return .{
        .header = .{
            .stx = STX,
            .kind = kind,
            .len = @sizeOf(@TypeOf(p)) + 9,
            .sequence = sequence,
        },
        .payload = switch (@typeInfo(@TypeOf(p))) {
            .@"struct" => try gpa.dupe(u8, std.mem.asBytes(p)),
            .array => array: {
                if (p.len > 0) {
                    @compileError("Array message must be zero length");
                }
                break :array &p;
            },
            else => {
                @compileError("Unexpected value");
            },
        },
        .etx = ETX,
        // BCC will be evaluated once the message is going to be sent.
        .bcc = undefined,
    };
}

pub fn deinit(self: *Message, gpa: std.mem.Allocator) void {
    gpa.free(self.payload);
    self.bcc = undefined;
    self.etx = undefined;
    self.header = undefined;
}

/// Parse incoming response to Message type. Payload are written in Big Endian.
/// Caller must call `deinit()` to free allocated payload message.
pub fn parse(
    gpa: std.mem.Allocator,
    buf: []const u8,
) (ParseError || std.mem.Allocator.Error)!Message {
    const header: Header = try .parse(buf[0..@sizeOf(Header)]);

    const len = std.mem.readInt(u32, buf[2..6], .big);
    if (len != buf.len) return ParseError.MismatchLength;
    // TODO: What shall be done with the rest of the header?

    const etx = buf[buf.len - 2];
    if (etx != ETX) return ParseError.MissingEtx;
    const bcc = getBcc(buf[1 .. buf.len - 1]);
    if (bcc != buf[buf.len - 1]) {
        return ParseError.InvalidBcc;
    }

    const payload = buf[7 .. buf.len - 2];

    return .{
        .header = header,
        .payload = try gpa.dupe(u8, payload),
        .etx = etx,
        .bcc = bcc,
    };
}

/// This function shall be used only for response message
pub fn setConfig(self: Message, config: *Config) void {
    const response: Response = switch (self.header.kind) {
        .get_driver_config => get_driver_config: {
            var payload: Response.SystemConfig = std.mem.bytesToValue(
                Response.SystemConfig,
                self.payload,
            );
            std.mem.byteSwapAllFields(Response.SystemConfig, &payload);
            break :get_driver_config .{ .get_driver_config = payload };
        },
        .get_driver_state => unreachable,
        .get_gain_current => get_gain_current: {
            var payload: Response.CurrentGain = std.mem.bytesToValue(
                Response.CurrentGain,
                self.payload,
            );
            std.mem.byteSwapAllFields(Response.CurrentGain, &payload);
            break :get_gain_current .{ .get_gain_current = payload };
        },
        .get_gain_speed => get_gain_speed: {
            var payload: Response.SpeedGain = std.mem.bytesToValue(
                Response.SpeedGain,
                self.payload,
            );
            std.mem.byteSwapAllFields(Response.SpeedGain, &payload);
            break :get_gain_speed .{ .get_gain_speed = payload };
        },
        .get_gain_position => get_gain_position: {
            var payload: Response.PositionGain = std.mem.bytesToValue(
                Response.PositionGain,
                self.payload,
            );
            std.mem.byteSwapAllFields(Response.PositionGain, &payload);
            break :get_gain_position .{ .get_gain_position = payload };
        },
        .set_servo_on => unreachable,
        .set_driver_config => unreachable,
        .set_gain_current => unreachable,
        .set_gain_speed => unreachable,
        .set_gain_position => unreachable,
        _ => unreachable,
    };
    switch (response) {
        inline .get_driver_config,
        .get_gain_current,
        .get_gain_speed,
        .get_gain_position,
        => |message| message.setConfig(config),
        .get_driver_state => unreachable, // TODO
        .set_servo_on,
        .set_driver_config,
        .set_gain_current,
        .set_gain_speed,
        .set_gain_position,
        => unreachable,
    }
}

pub const ParseError = error{
    /// Length message does not match with the whole message
    MismatchLength,
    /// Payload type does not match with message kind
    InvalidPayload,
    /// Bcc value does not match
    InvalidBcc,
    /// Stx byte not found on correct position
    MissingStx,
    /// Etx byte not found on correct position
    MissingEtx,
};

pub const Header = extern struct {
    stx: u8,
    kind: Kind, // 8 bits size
    len: u32 align(1),
    sequence: u8, // Sequence ID will be wrapped back to zero

    /// Parse header from the firmware response. This function is useful for
    /// parsing header first before parsing the whole message to get the actual
    /// length of the response. Endian are swapped
    pub fn parse(buf: []const u8) ParseError!Header {
        std.debug.assert(buf.len == 7);
        var header: Header = std.mem.bytesToValue(Header, buf);
        std.mem.byteSwapAllFields(Header, &header);
        // Ensuring STX is found
        if (header.stx != STX) return ParseError.MissingStx;
        // Validate kind
        const kind_ti = @typeInfo(Kind).@"enum";
        if (@intFromEnum(header.kind) >
            kind_ti.fields[kind_ti.fields.len - 1].value)
        {
            return error.InvalidPayload;
        }
        return header;
    }
};

pub const Request = union(Kind) {
    get_driver_config: [0]u8,
    get_driver_state: [0]u8,
    get_gain_current: [0]u8,
    get_gain_speed: [0]u8,
    get_gain_position: [0]u8,
    set_servo_on: bool,
    set_driver_config: SystemConfig,
    set_gain_current: CurrentGain,
    set_gain_speed: SpeedGain,
    set_gain_position: PositionGain,

    pub const SystemConfig = extern struct {
        rs: extern struct {
            axis1: f32 align(1),
            axis2: f32 align(1),
            axis3: f32 align(1),
        },
        ls: extern struct {
            axis1: f32 align(1),
            axis2: f32 align(1),
            axis3: f32 align(1),
        },
        kf: extern struct {
            axis1: f32 align(1),
            axis2: f32 align(1),
            axis3: f32 align(1),
        },
        kbm: extern struct {
            axis1: f32 align(1),
            axis2: f32 align(1),
            axis3: f32 align(1),
        },
        max_curr: extern struct {
            axis1: f32 align(1),
            axis2: f32 align(1),
            axis3: f32 align(1),
        },
        magnet_pitch: f32 align(1),
        slider_mass: f32 align(1),
        slider_length: f32 align(1),
        axis_length: f32 align(1),
        home_exist: bool,
        has_neighbor: extern struct {
            backward: bool,
            forward: bool,
        },
        use_axis: extern struct {
            axis2: bool,
            axis3: bool,
        },
        /// Driver ID on the line
        id: u16 align(1),
        /// Whether there is space on the edge of driver during calibration
        calibration_spare: extern struct {
            backward: bool,
            forward: bool,
        },
        collision_avoidance: bool,
        _unused: u16 align(1),
        continuous_current: extern struct {
            axis1: f32 align(1),
            axis2: f32 align(1),
            axis3: f32 align(1),
        },
        line_axes: u32,
        voltage_warmup: f32 align(1),
        retry_count: u8,
        station: u16 align(1),
        cc_link_speed: enum(u8) {
            @"156 kbps",
            @"625 kbps",
            @"2.5 Mbps",
            @"5 Mbps",
            @"10 Mbps",
        },
        hall_cutoff_freq: f32 align(1),
        overcurrent_timeout: f32 align(1),
        pos_offset: f32 align(1),
        calibration_use: bool,
        xts: bool,
        right_sensor_distance: f32 align(1),
        flip: bool,
        swap: bool,
    };

    pub const SpeedGain = extern struct {
        axis1: extern struct {
            p: f32 align(1),
            i: f32 align(1),
        },
        axis2: extern struct {
            p: f32 align(1),
            i: f32 align(1),
        },
        axis3: extern struct {
            p: f32 align(1),
            i: f32 align(1),
        },
        denominator: extern struct {
            axis1: u16 align(1),
            axis2: u16 align(1),
            axis3: u16 align(1),
        },
        denominator_pi: extern struct {
            axis1: u16 align(1),
            axis2: u16 align(1),
            axis3: u16 align(1),
        },
        /// SHDrv just send 1 without reasons in the code.
        _const_a: u32 align(1) = 1,
        _const_b: u32 align(1) = 1,
        /// SHDrv just send 100 without reasons in the code.
        _const_c: u16 align(1) = 100,
        _const_d: u16 align(1) = 100,
    };

    pub const PositionGain = extern struct {
        p: extern struct {
            axis1: f32 align(1),
            axis2: f32 align(1),
            axis3: f32 align(1),
        },
        deno_wpc: extern struct {
            axis1: u16 align(1),
            axis2: u16 align(1),
            axis3: u16 align(1),
        },
        arrival_threshold: extern struct {
            axis1: f32 align(1),
            axis2: f32 align(1),
            axis3: f32 align(1),
        },
        /// SHDrv just send 1 without reasons in the code.
        _const_a: u32 align(1) = 1,
        /// SHDrv just send 100 without reasons in the code.
        _const_b: u16 align(1) = 100,
    };

    pub const CurrentGain = extern struct {
        axis1: extern struct {
            p: f32 align(1),
            i: f32 align(1),
        },
        axis2: extern struct {
            p: f32 align(1),
            i: f32 align(1),
        },
        axis3: extern struct {
            p: f32 align(1),
            i: f32 align(1),
        },
        denominator: extern struct {
            axis1: u16 align(1),
            axis2: u16 align(1),
            axis3: u16 align(1),
        },
        /// SHDrv just send 1 without reasons in the code.
        _const_a: u32 align(1) = 1,
        _const_b: u32 align(1) = 1,
        /// SHDrv just send 100 without reasons in the code.
        _const_deno: u16 align(1) = 100,
    };
};

pub const Response = union(Kind) {
    get_driver_config: SystemConfig,
    get_driver_state: SystemState,
    get_gain_current: CurrentGain,
    get_gain_speed: SpeedGain,
    get_gain_position: PositionGain,
    set_servo_on: Ack,
    set_driver_config: Ack,
    set_gain_current: Ack,
    set_gain_speed: Ack,
    set_gain_position: Ack,

    pub const SystemConfig = extern struct {
        fn setConfig(self: SystemConfig, config: *Config) void {
            config.id = self.id;
            config.station = self.station;
            config.baud_rate = self.cc_link_speed;
            config.flags = .{
                .home_exists = self.home_exist,
                .has_neighbor = .{
                    .backward = self.has_neighbor.backward,
                    .forward = self.has_neighbor.forward,
                },
                .use_axis = .{
                    .axis2 = self.use_axis.axis2,
                    .axis3 = self.use_axis.axis3,
                },
                .calibration_spare = .{
                    .backward = self.calibration_spare.backward,
                    .forward = self.calibration_spare.forward,
                },
                .collision_avoidance = self.collision_avoidance,
                .calibration_use = self.calibration_use,
                .xts = self.xts,
                .flip = self.flip,
                .swap = self.swap,
            };
            config.line = .{
                .axes = self.line_axes,
                .axis_length = self.axis_length,
                .slider = .{
                    .mass = self.slider_mass,
                    .length = self.slider_length,
                },
                .magnet_pitch = self.magnet_pitch,
            };
            config.voltage_warmup = self.voltage_warmup;
            config.retry_count = self.retry_count;
            config.hall_cutoff_freq = self.hall_cutoff_freq;
            config.overcurrent_timeout = self.overcurrent_timeout;
            config.pos_offset = self.pos_offset;
            config.right_sensor_distance = self.right_sensor_distance;
            for (&config.axes, 0..) |*axis, i| {
                axis.rs = self.rs.axis(i);
                axis.ls = self.ls.axis(i);
                axis.kf = self.kf.axis(i);
                axis.kbm = self.kbm.axis(i);
                axis.max_current = self.max_curr.axis(i);
                axis.continuous_current = self.continuous_current.axis(i);
            }
        }
        /// Bytes 7..31 are not used
        _: [25]u8,
        rs: extern struct {
            axis1: f32 align(1),
            axis2: f32 align(1),
            axis3: f32 align(1),

            fn axis(self: @This(), i: usize) f32 {
                switch (i) {
                    0 => return self.axis1,
                    1 => return self.axis2,
                    2 => return self.axis3,
                    else => unreachable,
                }
            }
        },
        ls: extern struct {
            axis1: f32 align(1),
            axis2: f32 align(1),
            axis3: f32 align(1),

            fn axis(self: @This(), i: usize) f32 {
                switch (i) {
                    0 => return self.axis1,
                    1 => return self.axis2,
                    2 => return self.axis3,
                    else => unreachable,
                }
            }
        },
        kf: extern struct {
            axis1: f32 align(1),
            axis2: f32 align(1),
            axis3: f32 align(1),

            fn axis(self: @This(), i: usize) f32 {
                switch (i) {
                    0 => return self.axis1,
                    1 => return self.axis2,
                    2 => return self.axis3,
                    else => unreachable,
                }
            }
        },
        kbm: extern struct {
            axis1: f32 align(1),
            axis2: f32 align(1),
            axis3: f32 align(1),

            fn axis(self: @This(), i: usize) f32 {
                switch (i) {
                    0 => return self.axis1,
                    1 => return self.axis2,
                    2 => return self.axis3,
                    else => unreachable,
                }
            }
        },
        max_curr: extern struct {
            axis1: f32 align(1),
            axis2: f32 align(1),
            axis3: f32 align(1),

            fn axis(self: @This(), i: usize) f32 {
                switch (i) {
                    0 => return self.axis1,
                    1 => return self.axis2,
                    2 => return self.axis3,
                    else => unreachable,
                }
            }
        },
        magnet_pitch: f32 align(1),
        slider_mass: f32 align(1),
        slider_length: f32 align(1),
        axis_length: f32 align(1),
        home_exist: bool,
        has_neighbor: extern struct {
            backward: bool,
            forward: bool,
        },
        use_axis: extern struct {
            axis2: bool,
            axis3: bool,
        },
        /// Driver ID on the line
        id: u16 align(1),
        cc_link_speed: Config.CcLinkSpeed,
        /// Whether there is space on the edge of driver during calibration
        calibration_spare: extern struct {
            backward: bool,
            forward: bool,
        },
        collision_avoidance: bool,
        /// Bytes 119..127 are not used
        _1: [9]u8,
        continuous_current: extern struct {
            axis1: f32 align(1),
            axis2: f32 align(1),
            axis3: f32 align(1),

            fn axis(self: @This(), i: usize) f32 {
                switch (i) {
                    0 => return self.axis1,
                    1 => return self.axis2,
                    2 => return self.axis3,
                    else => unreachable,
                }
            }
        },
        line_axes: u32 align(1),
        voltage_warmup: f32 align(1),
        retry_count: u8,
        station: u16 align(1),
        overcurrent_timeout: f32 align(1),
        hall_cutoff_freq: f32 align(1),
        pos_offset: f32 align(1),
        calibration_use: bool,
        xts: bool,
        right_sensor_distance: f32 align(1),
        flip: bool,
        swap: bool,
    };

    pub const SystemState = extern struct {
        pub const SliderState = enum(u8) {
            none = 0,
            warm_up = 1,
            warm_up_comp = 2,
            warm_up_fault = 3,
            curr_bias = 4,
            curr_bias_comp = 5,
            fwd_ramp = 8,
            fwd_ramp_comp = 9,
            fwd_ramp_fault = 10,
            bwd_ramp = 11,
            bwd_ramp_comp = 12,
            bwd_ramp_fault = 13,
            curr_step = 20,
            curr_step_comp = 21,
            curr_step_fault = 22,
            speed_step = 23,
            speed_step_comp = 24,
            speed_step_fault = 25,
            pos_step = 26,
            pos_step_comp = 27,
            pos_step_fault = 28,
            pos_prof = 29,
            pos_prof_comp = 30,
            pos_prof_fault = 31,
            fwd_calib = 32,
            fwd_calib_comp = 33,
            bwd_calib = 34,
            bwd_calib_comp = 35,
            speed_prof = 40,
            speed_prof_comp = 41,
            speed_prof_fault = 42,
            fwd_slave = 43,
            fwd_slave_comp = 44,
            bwd_slave = 45,
            bwd_slave_comp = 46,
            over_charge = 50,
            synch_com_error = 51,
            _,
        };
        pub const Entrance = enum(u8) {
            none = 0,
            left = 1,
            right = 2,
            _,
        };
        _: u8,
        is_servo_on: bool,
        vdc: f32 align(1),
        thermo: f32 align(1),
        slide_no: extern struct {
            axis1: u8,
            axis2: u8,
            axis3: u8,
        },
        fwd_lsen_off_pos: extern struct {
            axis1: f32 align(1),
            axis2: f32 align(1),
            axis3: f32 align(1),
        },
        base_pos: extern struct {
            axis1: f32 align(1),
            _basepos1: [4]u8,
            axis2: f32 align(1),
            _basepos2: [4]u8,
            axis3: f32 align(1),
            _basepos3: [6]u8,
        },
        theta_offset: f32 align(1),
        slide_state: extern struct {
            axis1: SliderState,
            axis2: SliderState,
            axis3: SliderState,
        },
        is_calibrate: bool,
        bias: extern struct {
            axis1: extern struct {
                a: f32 align(1),
                b: f32 align(1),
            },
            axis2: extern struct {
                a: f32 align(1),
                b: f32 align(1),
            },
            axis3: extern struct {
                a: f32 align(1),
                b: f32 align(1),
            },
        },
        sys_version: f32 align(1),
        is_cclink_on: bool,
        mecha_pos: extern struct {
            axis1: f32 align(1),
            axis2: f32 align(1),
            axis3: f32 align(1),
        },
        /// Byte 107: not read.
        _1: u8,
        sensor: extern struct {
            home: u8,
            id0: u8,
            id1: u8,
            id2: u8,
        },
        entrance: extern struct {
            axis1: Entrance,
            axis2: Entrance,
            axis3: Entrance,
        },
        pitch_cnt: extern struct {
            axis1: i16 align(1),
            axis2: i16 align(1),
            axis3: i16 align(1),
        },
        /// Bytes 121..122: not read.
        _2: [2]u8,
        enable: extern struct {
            axis1: bool,
            axis2: bool,
            axis3: bool,
        },
        /// Bytes 126..129: not read (was CaliHome, commented out).
        _3: [4]u8,
        restart_section_cnt: extern struct {
            axis1: i16 align(1),
            axis2: i16 align(1),
            axis3: i16 align(1),
        },
        bwd_rsen_off_pos: extern struct {
            axis1: f32 align(1),
            axis2: f32 align(1),
            axis3: f32 align(1),
        },
        rsen_off_section_cnt: extern struct {
            axis1: i16 align(1),
            axis2: i16 align(1),
            axis3: i16 align(1),
        },
        fwd_syncr_info_req_pos: f32 align(1),
        bwd_syncl_info_req_pos: f32 align(1),
        /// Bytes 162..165: not read.
        _4: [4]u8,
        over_charge_state: extern struct {
            axis1: SliderState,
            axis2: SliderState,
            axis3: SliderState,
        },
        fwd_rsen_on_pos: extern struct {
            axis1: f32 align(1),
            axis2: f32 align(1),
            axis3: f32 align(1),
        },
        fwd_rsen_on_section_cnt: extern struct {
            axis1: i16 align(1),
            axis2: i16 align(1),
            axis3: i16 align(1),
        },
        bwd_lsen_on_pos: extern struct {
            axis1: f32 align(1),
            axis2: f32 align(1),
            axis3: f32 align(1),
        },
        bwd_lsen_on_section_cnt: extern struct {
            axis1: i16 align(1),
            axis2: i16 align(1),
            axis3: i16 align(1),
        },
        primary_axis: extern struct {
            axis1: bool,
            axis2: bool,
            axis3: bool,
        },
    };

    pub const CurrentGain = extern struct {
        fn setConfig(self: CurrentGain, config: *Config) void {
            for (&config.axes, 0..) |*ax, i| {
                const gain = self.axis(@intCast(i));
                ax.gain.current = .{
                    .p = gain.p,
                    .i = gain.i,
                    .denominator = gain.denominator,
                };
            }
        }

        /// Get the gain based on axis index.
        fn axis(self: CurrentGain, i: u2) Gain {
            switch (i) {
                inline 3 => unreachable,
                inline else => |idx| {
                    const axis_name = std.fmt.comptimePrint("axis{}", .{idx + 1});
                    const pi = @field(self, axis_name);
                    return .{
                        .p = pi.p,
                        .i = pi.i,
                        .denominator = @field(self.denominator, axis_name),
                    };
                },
            }
        }

        const Gain = struct { p: f32, i: f32, denominator: u16 };

        /// Byte 7 is not used
        _: u8,
        axis1: extern struct {
            p: f32 align(1),
            i: f32 align(1),
        },
        axis2: extern struct {
            p: f32 align(1),
            i: f32 align(1),
        },
        axis3: extern struct {
            p: f32 align(1),
            i: f32 align(1),
        },
        /// Bytes 32..39 are not used.
        _1: [8]u8,
        denominator: extern struct {
            axis1: u16 align(1),
            axis2: u16 align(1),
            axis3: u16 align(1),
        },
    };

    pub const SpeedGain = extern struct {
        fn setConfig(self: SpeedGain, config: *Config) void {
            for (&config.axes, 0..) |*ax, i| {
                const gain = self.axis(@intCast(i));
                ax.gain.speed = .{
                    .p = gain.p,
                    .i = gain.i,
                    .denominator = gain.denominator,
                    .denominator_pi = gain.denominator_pi,
                };
            }
        }

        /// Get the gain based on axis index.
        fn axis(self: SpeedGain, i: u2) Gain {
            switch (i) {
                inline 3 => unreachable,
                inline else => |idx| {
                    const axis_name = std.fmt.comptimePrint("axis{}", .{idx + 1});
                    const pi = @field(self, axis_name);
                    return .{
                        .p = pi.p,
                        .i = pi.i,
                        .denominator = @field(self.denominator, axis_name),
                        .denominator_pi = @field(self.denominator_pi, axis_name),
                    };
                },
            }
        }

        const Gain = struct {
            p: f32,
            i: f32,
            denominator: u16,
            denominator_pi: u16,
        };

        _: u8,
        axis1: extern struct {
            p: f32 align(1),
            i: f32 align(1),
        },
        axis2: extern struct {
            p: f32 align(1),
            i: f32 align(1),
        },
        axis3: extern struct {
            p: f32 align(1),
            i: f32 align(1),
        },
        _1: [8]u8,
        denominator: extern struct {
            axis1: u16 align(1),
            axis2: u16 align(1),
            axis3: u16 align(1),
        },
        _2: u16 align(1),
        denominator_pi: extern struct {
            axis1: u16 align(1),
            axis2: u16 align(1),
            axis3: u16 align(1),
        },
    };

    pub const PositionGain = extern struct {
        fn setConfig(self: PositionGain, config: *Config) void {
            for (&config.axes, 0..) |*ax, i| {
                const gain = self.axis(@intCast(i));
                ax.gain.position = .{
                    .p = gain.p,
                    .denominator = gain.denominator,
                };
                ax.arrival_threshold = gain.arrival_threshold;
            }
        }

        /// Get the gain based on axis index.
        fn axis(self: PositionGain, i: u2) Gain {
            switch (i) {
                inline 3 => unreachable,
                inline else => |idx| {
                    const axis_name = std.fmt.comptimePrint("axis{}", .{idx + 1});
                    return .{
                        .p = @field(self.p, axis_name),
                        .denominator = @field(self.denominator, axis_name),
                        .arrival_threshold = @field(
                            self.arrival_threshold,
                            axis_name,
                        ),
                    };
                },
            }
        }

        const Gain = struct {
            p: f32,
            denominator: u16,
            arrival_threshold: f32,
        };
        _: u8,
        p: extern struct {
            axis1: f32 align(1),
            axis2: f32 align(1),
            axis3: f32 align(1),
        },
        _1: [4]u8,
        denominator: extern struct {
            axis1: u16 align(1),
            axis2: u16 align(1),
            axis3: u16 align(1),
        },
        _2: u16 align(1),
        arrival_threshold: extern struct {
            axis1: f32 align(1),
            axis2: f32 align(1),
            axis3: f32 align(1),
        },
    };

    pub const Ack = enum(u8) {
        success = 0x00,
        _,
    };
};

pub const Kind = enum(u8) {
    get_driver_config = 0x02,
    get_driver_state,
    get_gain_current,
    get_gain_speed,
    get_gain_position,
    set_servo_on,
    set_driver_config,
    set_gain_current,
    set_gain_speed,
    set_gain_position,
    _,
};

pub const Payload = union(Type) {
    request: Request,
    response: Response,
};

const Type = enum(u2) {
    request,
    response,
};

fn PayloadType(
    comptime kind: Kind,
    comptime message_type: Type,
) type {
    // Get either `Request` or `Response` type
    const T = @FieldType(Payload, @tagName(message_type));
    // Return the payload type
    return @FieldType(T, @tagName(kind));
}

/// Calculate bcc based on the buffer. The buffer must be the message excluding
/// the etx (header) and bcc itself.
fn getBcc(buf: []const u8) u8 {
    // std.debug.assert(buf[0] != STX or @byteSwap(buf[0]) != STX);
    var bcc: u8 = 0;
    for (buf) |b| {
        bcc ^= b;
    }
    return bcc;
}
