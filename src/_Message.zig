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
/// memory layout. Payload must be in big endian before calling `write()` and in
/// big endian after calling `parse()`.
payload: []u8,
etx: u8,
/// Unused when sending message to firmware.
bcc: u8,

/// Write the message into the writer. The message is writen in Big Endian due
/// to firmware implementation are using Big Endianness.
pub fn write(self: Message, writer: *std.Io.Writer) std.Io.Writer.Error!void {
    const endian: std.builtin.Endian = .big;
    try writer.writeStruct(self.header, endian);
    try writer.writeAll(self.payload);
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
) std.mem.Allocator.Error!Message {
    return .{
        .header = .{
            .stx = STX,
            .kind = kind,
            .len = @sizeOf(@TypeOf(p)) + 9,
            .sequence = sequence,
        },
        .payload = switch (@typeInfo(@TypeOf(p))) {
            .@"struct" => payload: {
                var payload = p;
                std.mem.byteSwapAllFields(
                    PayloadType(kind, message_type),
                    &payload,
                );
                break :payload try gpa.dupe(u8, std.mem.asBytes(&payload));
            },
            .array => array: {
                if (p.len > 0) {
                    @compileError("Array message must be zero length");
                }
                break :array &p;
            },
            .bool => bool: {
                break :bool try gpa.dupe(u8, std.mem.asBytes(&p));
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

/// Set configuration value from the response message.
pub fn setConfig(self: Message, config: *Config) void {
    switch (self.header.kind) {
        inline .get_driver_config,
        .get_gain_current,
        .get_gain_speed,
        .get_gain_position,
        .get_driver_state,
        .get_section_count,
        => |tag| {
            const T = PayloadType(tag, .response);
            var payload: T = std.mem.bytesToValue(T, self.payload);
            // Change the endianness of the payload
            std.mem.byteSwapAllFields(T, &payload);
            payload.setConfig(config);
        },
        else => unreachable,
    }
}

pub fn PayloadType(
    comptime kind: Kind,
    comptime message_type: Type,
) type {
    // Get either `Request` or `Response` type
    const T = @FieldType(Payload, @tagName(message_type));
    // Return the payload type
    return @FieldType(T, @tagName(kind));
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
    toggle_servo: bool,
    set_driver_config: SystemConfig,
    set_gain_current: CurrentGain,
    set_gain_speed: SpeedGain,
    set_gain_position: PositionGain,
    set_angle_offset: AngleOffset,
    set_section_count: SectionCount,
    get_section_count: [0]u8,

    pub const SystemConfig = extern struct {
        pub fn fromConfig(config: Config) SystemConfig {
            var result: SystemConfig = undefined;
            inline for (config.axes, 1..) |axis, i| {
                const axis_name = std.fmt.comptimePrint("axis{}", .{i});
                @field(result.rs, axis_name) = axis.rs;
                @field(result.ls, axis_name) = axis.ls;
                @field(result.kf, axis_name) = axis.kf;
                @field(result.kbm, axis_name) = axis.kbm;
                @field(result.max_curr, axis_name) = axis.max_current;
                @field(
                    result.continuous_current,
                    axis_name,
                ) = axis.continuous_current;
            }
            result.magnet_pitch = config.line.magnet_pitch;
            result.slider_mass = config.line.slider.mass;
            result.slider_length = config.line.slider.length;
            result.axis_length = config.line.axis_length;
            result.home_exist = config.flags.home_exists;
            result.has_neighbor = .{
                .backward = config.flags.has_neighbor.backward,
                .forward = config.flags.has_neighbor.forward,
            };
            result.use_axis = .{
                .axis2 = config.flags.use_axis.axis2,
                .axis3 = config.flags.use_axis.axis3,
            };
            result.id = config.id;
            result.calibration_spare = .{
                .backward = config.flags.calibration_spare.backward,
                .forward = config.flags.calibration_spare.forward,
            };
            result.collision_avoidance = config.flags.collision_avoidance;
            result.line_axes = config.line.axes;
            result.voltage_warmup = config.voltage_warmup;
            result.retry_count = config.retry_count;
            result.station = config.station;
            result.cc_link_speed = config.cc_link_speed;
            result.hall_cutoff_freq = config.hall_cutoff_freq;
            result.overcurrent_timeout = config.overcurrent_timeout;
            result.pos_offset = config.pos_offset;
            result.calibration_use = config.flags.calibration_use;
            result.xts = config.flags.xts;
            result.right_sensor_distance = config.right_sensor_distance;
            result.flip = config.flags.flip;
            result.swap = config.flags.swap;
            return result;
        }
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
        _unused: u16 align(1) = undefined,
        continuous_current: extern struct {
            axis1: f32 align(1),
            axis2: f32 align(1),
            axis3: f32 align(1),
        },
        line_axes: u32,
        voltage_warmup: f32 align(1),
        retry_count: u8,
        station: u16 align(1),
        cc_link_speed: Config.CcLinkSpeed,
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
        pub fn fromConfig(config: Config) SpeedGain {
            var result: SpeedGain = undefined;
            inline for (config.axes, 1..) |axis, i| {
                const axis_name = std.fmt.comptimePrint("axis{}", .{i});
                @field(result, axis_name) = .{
                    .p = axis.gain.speed.p,
                    .i = axis.gain.speed.i,
                };
                @field(result.denominator, axis_name) =
                    axis.gain.speed.denominator;
                @field(result.denominator_pi, axis_name) =
                    axis.gain.speed.denominator_pi;
            }
            return result;
        }

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
        pub fn fromConfig(config: Config) PositionGain {
            var result: PositionGain = undefined;
            inline for (config.axes, 1..) |axis, i| {
                const axis_name = std.fmt.comptimePrint("axis{}", .{i});
                @field(result.p, axis_name) = axis.gain.position.p;
                @field(result.deno_wpc, axis_name) =
                    axis.gain.position.denominator;
                @field(result.arrival_threshold, axis_name) =
                    axis.arrival_threshold;
            }
            return result;
        }
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
        pub fn fromConfig(config: Config) CurrentGain {
            var result: CurrentGain = undefined;
            inline for (config.axes, 1..) |axis, i| {
                const axis_name = std.fmt.comptimePrint("axis{}", .{i});
                @field(result, axis_name) = .{
                    .p = axis.gain.current.p,
                    .i = axis.gain.current.i,
                };
                @field(result.denominator, axis_name) =
                    axis.gain.current.denominator;
            }
            return result;
        }
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

    pub const AngleOffset = extern struct {
        pub fn fromConfig(config: Config) AngleOffset {
            var result: AngleOffset = undefined;
            result.angle_offset = config.angle_offset;
            inline for (config.axes, 1..) |axis, i| {
                const axis_name = std.fmt.comptimePrint("axis{}", .{i});
                const position = axis.sensor.position;
                const section_count = axis.sensor.section_count;
                @field(result.sensor_off, axis_name) = .{
                    .fwd_lsen_off_pos = position.off.forward,
                    .fwd_lsen_off_section_cnt = section_count.off.forward,
                    .bwd_rsen_off_pos = position.off.backward,
                    .bwd_rsen_off_section_cnt = section_count.off.backward,
                };
                @field(result.base_pos, axis_name) = axis.base_position;
                @field(result.sensor_on, axis_name) = .{
                    .fwd_rsen_on_pos = position.on.forward,
                    .fwd_rsen_on_section_cnt = section_count.on.forward,
                    .bwd_lsen_on_pos = position.on.backward,
                    .bwd_lsen_on_section_cnt = section_count.on.backward,
                };
            }
            return result;
        }
        angle_offset: f32 align(1),
        sensor_off: extern struct {
            axis1: extern struct {
                fwd_lsen_off_pos: f32 align(1),
                fwd_lsen_off_section_cnt: i16 align(1),
                bwd_rsen_off_pos: f32 align(1),
                bwd_rsen_off_section_cnt: i16 align(1),
            },
            axis2: extern struct {
                fwd_lsen_off_pos: f32 align(1),
                fwd_lsen_off_section_cnt: i16 align(1),
                bwd_rsen_off_pos: f32 align(1),
                bwd_rsen_off_section_cnt: i16 align(1),
            },
            axis3: extern struct {
                fwd_lsen_off_pos: f32 align(1),
                fwd_lsen_off_section_cnt: i16 align(1),
                bwd_rsen_off_pos: f32 align(1),
                bwd_rsen_off_section_cnt: i16 align(1),
            },
        },
        base_pos: extern struct {
            axis1: f32 align(1),
            axis2: f32 align(1),
            axis3: f32 align(1),
        },
        sensor_on: extern struct {
            axis1: extern struct {
                fwd_rsen_on_pos: f32 align(1),
                fwd_rsen_on_section_cnt: i16 align(1),
                bwd_lsen_on_pos: f32 align(1),
                bwd_lsen_on_section_cnt: i16 align(1),
            },
            axis2: extern struct {
                fwd_rsen_on_pos: f32 align(1),
                fwd_rsen_on_section_cnt: i16 align(1),
                bwd_lsen_on_pos: f32 align(1),
                bwd_lsen_on_section_cnt: i16 align(1),
            },
            axis3: extern struct {
                fwd_rsen_on_pos: f32 align(1),
                fwd_rsen_on_section_cnt: i16 align(1),
                bwd_lsen_on_pos: f32 align(1),
                bwd_lsen_on_section_cnt: i16 align(1),
            },
        },
    };

    pub const SectionCount = extern struct {
        pub fn fromConfig(config: Config) SectionCount {
            const disable = config.state.section_count.deactivate_secondary;
            const max = config.section_count.max;
            return .{
                .fwd_left_secondary_disable = .{
                    .axis2 = disable.left.forward.axis2,
                    .axis3 = disable.left.forward.axis3,
                },
                .fwd_right_secondary_disable = .{
                    .axis2 = disable.right.forward.axis2,
                    .axis3 = disable.right.forward.axis3,
                },
                .bwd_left_secondary_disable = .{
                    .axis1 = disable.left.backward.axis1,
                    .axis2 = disable.left.backward.axis2,
                },
                .bwd_right_secondary_disable = .{
                    .axis1 = disable.right.backward.axis1,
                    .axis2 = disable.right.backward.axis2,
                },
                .max_section_cnt = .{
                    .axis1 = max.axis1,
                    .axis2 = max.axis2,
                    .axis3 = max.axis3,
                },
                .skip_cnt = config.section_count.skip,
            };
        }
        fwd_left_secondary_disable: extern struct {
            axis2: i16 align(1),
            axis3: i16 align(1),
        },
        fwd_right_secondary_disable: extern struct {
            axis2: i16 align(1),
            axis3: i16 align(1),
        },
        bwd_left_secondary_disable: extern struct {
            axis1: i16 align(1),
            axis2: i16 align(1),
        },
        bwd_right_secondary_disable: extern struct {
            axis1: i16 align(1),
            axis2: i16 align(1),
        },
        max_section_cnt: extern struct {
            axis1: i16 align(1),
            axis2: i16 align(1),
            axis3: i16 align(1),
        },
        skip_cnt: i16 align(1),
    };
};

pub const Response = union(Kind) {
    get_driver_config: SystemConfig,
    get_driver_state: SystemState,
    get_gain_current: CurrentGain,
    get_gain_speed: SpeedGain,
    get_gain_position: PositionGain,
    toggle_servo: Ack,
    set_driver_config: Ack,
    set_gain_current: Ack,
    set_gain_speed: Ack,
    set_gain_position: Ack,
    set_angle_offset: Ack,
    set_section_count: Ack,
    get_section_count: SectionCount,

    pub const SystemConfig = extern struct {
        pub fn setConfig(self: SystemConfig, config: *Config) void {
            config.id = self.id;
            config.station = self.station;
            config.cc_link_speed = self.cc_link_speed;
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
        pub fn setConfig(self: SystemState, config: *Config) void {
            config.angle_offset = self.theta_offset;
            const state = &config.state;
            state.servo_enabled = self.is_servo_on;
            state.cc_link_enabled = self.is_cclink_on;
            state.calibrated = self.is_calibrate;
            state.vdc = self.vdc;
            state.thermo = self.thermo;
            state.sys_version = self.sys_version;
            state.sensor = .{
                .home = self.sensor.home,
                .id0 = self.sensor.id0,
                .id1 = self.sensor.id1,
                .id2 = self.sensor.id2,
            };
            state.synchronization_request_position = .{
                .forward = self.fwd_syncr_info_req_pos,
                .backward = self.bwd_syncl_info_req_pos,
            };
            inline for (&config.axes, 1..) |*axis, i| {
                const axis_name = std.fmt.comptimePrint("axis{}", .{i});
                const bias = @field(self.bias, axis_name);
                state.axes[i - 1] = .{
                    .enabled = @field(self.enable, axis_name),
                    .primary = @field(self.primary_axis, axis_name),
                    .slider = .{
                        .id = @field(self.slide_no, axis_name),
                        .state = @field(self.slide_state, axis_name),
                    },
                    .entrance = @field(self.entrance, axis_name),
                    .overcharge_state = @field(
                        self.over_charge_state,
                        axis_name,
                    ),
                    .pitch_count = @field(self.pitch_cnt, axis_name),
                    .mechanical_position = @field(self.mecha_pos, axis_name),
                    .bias = .{ .a = bias.a, .b = bias.b },
                };

                axis.base_position = @field(self.base_pos, axis_name);
                const position = &axis.sensor.position;
                position.on.forward = @field(self.fwd_rsen_on_pos, axis_name);
                position.on.backward = @field(self.bwd_lsen_on_pos, axis_name);
                position.off.forward =
                    @field(self.fwd_lsen_off_pos, axis_name);
                position.off.backward =
                    @field(self.bwd_rsen_off_pos, axis_name);
                const section_count = &axis.sensor.section_count;
                section_count.on.forward =
                    @field(self.fwd_rsen_on_section_cnt, axis_name);
                section_count.on.backward =
                    @field(self.bwd_lsen_on_section_cnt, axis_name);
                section_count.off.forward =
                    @field(self.fwd_lsen_off_section_cnt, axis_name);
                section_count.off.backward =
                    @field(self.bwd_rsen_off_section_cnt, axis_name);
            }
        }
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
            axis1: Config.Fsm,
            axis2: Config.Fsm,
            axis3: Config.Fsm,
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
            axis1: Config.Entrance,
            axis2: Config.Entrance,
            axis3: Config.Entrance,
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
        /// This field represent two things in SHDrv: RestartSectionCnt and the
        /// following.
        fwd_lsen_off_section_cnt: extern struct {
            axis1: i16 align(1),
            axis2: i16 align(1),
            axis3: i16 align(1),
        },
        bwd_rsen_off_pos: extern struct {
            axis1: f32 align(1),
            axis2: f32 align(1),
            axis3: f32 align(1),
        },
        bwd_rsen_off_section_cnt: extern struct {
            axis1: i16 align(1),
            axis2: i16 align(1),
            axis3: i16 align(1),
        },
        fwd_syncr_info_req_pos: f32 align(1),
        bwd_syncl_info_req_pos: f32 align(1),
        /// Bytes 162..165: not read.
        _4: [4]u8,
        over_charge_state: extern struct {
            axis1: Config.Fsm,
            axis2: Config.Fsm,
            axis3: Config.Fsm,
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
        pub fn setConfig(self: CurrentGain, config: *Config) void {
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
        pub fn setConfig(self: SpeedGain, config: *Config) void {
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
        pub fn setConfig(self: PositionGain, config: *Config) void {
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

    pub const SectionCount = extern struct {
        pub fn setConfig(self: SectionCount, config: *Config) void {
            const max = self.max_section_cnt;
            config.section_count = .{
                .skip = self.skip_cnt,
                .max = .{
                    .axis1 = max.axis1,
                    .axis2 = max.axis2,
                    .axis3 = max.axis3,
                },
            };
            const fwd_left_disable = self.fwd_left_secondary_disable;
            const fwd_right_disable = self.fwd_right_secondary_disable;
            const bwd_left_disable = self.bwd_left_secondary_disable;
            const bwd_right_disable = self.bwd_right_secondary_disable;
            const fwd_left_enable = self.fwd_left_inactive_primary_enable;
            const fwd_right_enable = self.fwd_right_inactive_primary_enable;
            const bwd_left_enable = self.bwd_left_inactive_primary_enable;
            const bwd_right_enable = self.bwd_right_inactive_primary_enable;
            config.state.section_count = .{
                .deactivate_secondary = .{
                    .left = .{
                        .forward = .{
                            .axis2 = fwd_left_disable.axis2,
                            .axis3 = fwd_left_disable.axis3,
                        },
                        .backward = .{
                            .axis1 = bwd_left_disable.axis1,
                            .axis2 = bwd_left_disable.axis2,
                        },
                    },
                    .right = .{
                        .forward = .{
                            .axis2 = fwd_right_disable.axis2,
                            .axis3 = fwd_right_disable.axis3,
                        },
                        .backward = .{
                            .axis1 = bwd_right_disable.axis1,
                            .axis2 = bwd_right_disable.axis2,
                        },
                    },
                },
                .activate_primary = .{
                    .left = .{
                        .forward = .{
                            .axis1 = fwd_left_enable.axis1,
                            .axis2 = fwd_left_enable.axis2,
                            .axis3 = fwd_left_enable.axis3,
                        },
                        .backward = .{
                            .axis1 = bwd_left_enable.axis1,
                            .axis2 = bwd_left_enable.axis2,
                            .axis3 = bwd_left_enable.axis3,
                        },
                    },
                    .right = .{
                        .forward = .{
                            .axis1 = fwd_right_enable.axis1,
                            .axis2 = fwd_right_enable.axis2,
                            .axis3 = fwd_right_enable.axis3,
                        },
                        .backward = .{
                            .axis1 = bwd_right_enable.axis1,
                            .axis2 = bwd_right_enable.axis2,
                            .axis3 = bwd_right_enable.axis3,
                        },
                    },
                },
            };
        }

        /// Byte 7 is not used
        _: u8,
        fwd_left_secondary_disable: extern struct {
            axis2: i16 align(1),
            axis3: i16 align(1),
        },
        fwd_right_secondary_disable: extern struct {
            axis2: i16 align(1),
            axis3: i16 align(1),
        },
        bwd_left_secondary_disable: extern struct {
            axis1: i16 align(1),
            axis2: i16 align(1),
        },
        bwd_right_secondary_disable: extern struct {
            axis1: i16 align(1),
            axis2: i16 align(1),
        },
        fwd_left_inactive_primary_enable: extern struct {
            axis1: i16 align(1),
            axis2: i16 align(1),
            axis3: i16 align(1),
        },
        fwd_right_inactive_primary_enable: extern struct {
            axis1: i16 align(1),
            axis2: i16 align(1),
            axis3: i16 align(1),
        },
        bwd_left_inactive_primary_enable: extern struct {
            axis1: i16 align(1),
            axis2: i16 align(1),
            axis3: i16 align(1),
        },
        bwd_right_inactive_primary_enable: extern struct {
            axis1: i16 align(1),
            axis2: i16 align(1),
            axis3: i16 align(1),
        },
        max_section_cnt: extern struct {
            axis1: i16 align(1),
            axis2: i16 align(1),
            axis3: i16 align(1),
        },
        skip_cnt: i16 align(1),
    };

    pub const Ack = enum(u8) {
        success = 0x00,
        _,
    };
};

/// `get_` prefix gets the information required by the `Config`. `set_` prefix
/// set the mutable configuration to the firmware.
pub const Kind = enum(u8) {
    get_driver_config = 0x02,
    get_driver_state,
    get_gain_current,
    get_gain_speed,
    get_gain_position,
    toggle_servo,
    set_driver_config,
    set_gain_current,
    set_gain_speed,
    set_gain_position,
    set_angle_offset = 0x11,
    set_section_count = 0x15,
    get_section_count,
    _,
};

const Payload = union(Type) {
    request: Request,
    response: Response,
};

const Type = enum(u2) {
    request,
    response,
};

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

test "get_ responses have setConfig and set_ requests have fromConfig" {
    inline for (@typeInfo(Kind).@"enum".fields) |field| {
        const kind: Kind = @enumFromInt(field.value);
        if (comptime std.mem.startsWith(u8, field.name, "get_")) {
            const T = PayloadType(kind, .response);
            try std.testing.expect(@hasDecl(T, "setConfig"));
        }
        if (comptime std.mem.startsWith(u8, field.name, "set_")) {
            const T = PayloadType(kind, .request);
            try std.testing.expect(@hasDecl(T, "fromConfig"));
        }
    }
}
