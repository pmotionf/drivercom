//! Type, description and unit of every `Config` field, in the same layout as
//! `Config`. `x: Type` names the type of field `x`, and `__x: Meta` describes
//! it. drivercom-cli's `config.info` prints `Info{}` for drivercom-gui.
//!
//! Descriptions and units come from the SHDrv tool. A unit is left out where
//! SHDrv does not state one.

pub const Type = []const u8;
pub const Meta = struct {
    description: ?[]const u8 = null,
    unit_short: ?[]const u8 = null,
    unit_long: ?[]const u8 = null,
};

id: Type = "u16",
__id: Meta = .{
    .description =
    \\ID is an identifier number and unique per Line.
    \\First Driver in Line must have ID number 1.
    \\Each Driver in Line must have consecutively increasing IDs.
    ,
},
station: Type = "u16",
__station: Meta = .{
    .description =
    \\CC-Link Station ID. Identifier number, unique per Track.
    ,
},
cc_link_speed: Type = "CcLinkSpeed",
__cc_link_speed: Meta = .{ .description = "CC-Link communication speed." },
flags: struct {
    home_exists: Type = "bool",
    __home_exists: Meta = .{
        .description = "True if this Driver has the Home sensor.",
    },
    has_neighbor: struct {
        backward: Type = "bool",
        __backward: Meta = .{
            .description =
            \\True if another Driver is connected on the left of this Driver.
            ,
        },
        forward: Type = "bool",
        __forward: Meta = .{
            .description =
            \\True if another Driver is connected on the right of this
            \\Driver.
            ,
        },
    } = .{},
    use_axis: struct {
        axis2: Type = "bool",
        __axis2: Meta = .{
            .description =
            \\Whether this Driver uses second Axis.
            ,
        },
        axis3: Type = "bool",
        __axis3: Meta = .{
            .description =
            \\Whether this Driver uses third Axis.
            \\`axis2` must be true if using third Axis.
            ,
        },
    } = .{},
    __use_axis: Meta = .{
        .description =
        \\Axes used by this driver.
        ,
    },
    calibration_spare: struct {
        backward: Type = "bool",
        __backward: Meta = .{
            .description =
            \\True if there is spare space on the left of first Axis during
            \\calibration.
            ,
        },
        forward: Type = "bool",
        __forward: Meta = .{
            .description =
            \\True if there is spare space on the right of last Axis during
            \\calibration.
            ,
        },
    } = .{},
    collision_avoidance: Type = "bool",
    __collision_avoidance: Meta = .{
        .description = "True if Collision Avoidance System is enabled.",
    },
    calibration_use: Type = "bool",
    __calibration_use: Meta = .{
        .description =
        \\True if calibration information is used for LMDS actions.
        ,
    },
    xts: Type = "bool",
    __xts: Meta = .{
        .description = "True if this Line is XTS. False if this Line is LMS.",
    },
    flip: Type = "bool",
    __flip: Meta = .{
        .description = "Exchange cosine and sine readings of sensors.",
    },
    swap: Type = "bool",
    __swap: Meta = .{
        .description = "Switch order of the two sensors in Axis.",
    },
} = .{},
line: struct {
    axes: Type = "u32",
    __axes: Meta = .{
        .description =
        \\Total number of Axes used in this Line.
        ,
    },
    axis_length: Type = "f32",
    __axis_length: Meta = .{
        .description = "Distance between each Axis' coil centers.",
        .unit_short = "m",
        .unit_long = "Meter",
    },
    slider: struct {
        mass: Type = "f32",
        __mass: Meta = .{
            .description = "Mass of Slider including its load.",
            .unit_short = "kg",
            .unit_long = "Kilogram",
        },
        length: Type = "f32",
        __length: Meta = .{
            .description = "Length of Slider.",
            .unit_short = "m",
            .unit_long = "Meter",
        },
    } = .{},
    magnet_pitch: Type = "f32",
    __magnet_pitch: Meta = .{
        .description = "Distance between two N poles of Slider magnet.",
        .unit_short = "m",
        .unit_long = "Meter",
    },
} = .{},
voltage_warmup: Type = "f32",
__voltage_warmup: Meta = .{
    .description = "Maximum voltage applied to find sensor angle offset.",
    .unit_short = "V",
    .unit_long = "Volt",
},
retry_count: Type = "u8",
__retry_count: Meta = .{
    .description =
    \\Number of retries for synchronous communication between Drivers.
    ,
},
hall_cutoff_freq: Type = "f32",
__hall_cutoff_freq: Meta = .{
    .description = "Cut-off frequency of sensor smoothing filter.",
    .unit_short = "Hz",
    .unit_long = "Hertz",
},
overcurrent_timeout: Type = "f32",
__overcurrent_timeout: Meta = .{
    .description = "Minimum overcurrent duration before alarm.",
    .unit_short = "s",
    .unit_long = "Second",
},
pos_offset: Type = "f32",
__pos_offset: Meta = .{
    .description = "Position offset.",
    .unit_short = "pitch",
    .unit_long = "Magnet pitch",
},
right_sensor_distance: Type = "f32",
__right_sensor_distance: Meta = .{
    .description =
    \\Distance between right sensor and right end of Axis.
    \\Only used in XTS.
    ,
},
angle_offset: Type = "f32",
__angle_offset: Meta = .{
    .description =
    \\Normalized sensor angle offset. Measured by calibration.
    ,
},
section_count: struct {
    skip: Type = "i16",
    __skip: Meta = .{
        .description =
        \\Section count at which next Axis becomes primary and current Axis
        \\becomes secondary.
        ,
    },
    max: struct {
        axis1: Type = "i16",
        __axis1: Meta = .{
            .description = "Maximum section count while first Axis is primary.",
        },
        axis2: Type = "i16",
        __axis2: Meta = .{
            .description =
            \\Maximum section count while second Axis is primary.
            ,
        },
        axis3: Type = "i16",
        __axis3: Meta = .{
            .description = "Maximum section count while third Axis is primary.",
        },
    } = .{},
} = .{},
__section_count: Meta = .{
    .description =
    \\Section count thresholds for switching primary Axis.
    ,
},
axes: [3]Axis = .{ .{}, .{}, .{} },
state: State = .{},

pub const Axis = struct {
    rs: Type = "f32",
    __rs: Meta = .{
        .description = "Stator Resistance (line to neutral)",
        .unit_short = "Ω",
        .unit_long = "Ohm",
    },
    ls: Type = "f32",
    __ls: Meta = .{
        .description = "Stator Inductance (line to neutral)",
        .unit_short = "H",
        .unit_long = "Henry",
    },
    kf: Type = "f32",
    __kf: Meta = .{
        .description = "Force Constant",
        .unit_short = "N/A",
        .unit_long = "Newton per Ampere",
    },
    kbm: Type = "f32",
    __kbm: Meta = .{
        .description = "Back EMF Constant",
        .unit_short = "V/(m/s)",
        .unit_long = "Volt per Meter per Second",
    },
    max_current: Type = "f32",
    __max_current: Meta = .{
        .description = "Maximum peak motor coil current.",
        .unit_short = "A",
        .unit_long = "Ampere",
    },
    continuous_current: Type = "f32",
    __continuous_current: Meta = .{
        .description = "Maximum continuous motor coil current.",
        .unit_short = "A",
        .unit_long = "Ampere",
    },
    gain: struct {
        current: struct {
            p: Type = "f32",
            __p: Meta = .{ .description = "Current control P gain." },
            i: Type = "f32",
            __i: Meta = .{ .description = "Current control I gain." },
            denominator: Type = "u16",
            __denominator: Meta = .{
                .description =
                \\Divider of 15 kHz sampling frequency for current control
                \\bandwidth.
                ,
            },
        } = .{},
        speed: struct {
            p: Type = "f32",
            __p: Meta = .{ .description = "Speed control P gain." },
            i: Type = "f32",
            __i: Meta = .{ .description = "Speed control I gain." },
            denominator: Type = "u16",
            __denominator: Meta = .{
                .description =
                \\Divider of current control bandwidth for speed control
                \\bandwidth.
                ,
            },
            denominator_pi: Type = "u16",
            __denominator_pi: Meta = .{
                .description =
                \\Divider of speed control bandwidth for PI corner frequency.
                ,
            },
        } = .{},
        position: struct {
            p: Type = "f32",
            __p: Meta = .{ .description = "Position control P gain." },
            denominator: Type = "u16",
            __denominator: Meta = .{
                .description =
                \\Divider of speed control bandwidth for position control
                \\bandwidth.
                ,
            },
        } = .{},
    } = .{},
    arrival_threshold: Type = "f32",
    __arrival_threshold: Meta = .{
        .description =
        \\Absolute position error tolerance for Slider movement completion.
        ,
        .unit_short = "m",
        .unit_long = "Meter",
    },
    base_position: Type = "f32",
    __base_position: Meta = .{
        .description = "Base position of Axis. Measured by calibration.",
    },
    sensor: struct {
        position: struct {
            on: struct {
                forward: Type = "f32",
                __forward: Meta = .{
                    .description =
                    \\Position where right sensor turns on in forward
                    \\direction. Measured by calibration.
                    ,
                },
                backward: Type = "f32",
                __backward: Meta = .{
                    .description =
                    \\Position where left sensor turns on in backward
                    \\direction. Measured by calibration.
                    ,
                },
            } = .{},
            off: struct {
                forward: Type = "f32",
                __forward: Meta = .{
                    .description =
                    \\Position where left sensor turns off in forward
                    \\direction. Measured by calibration.
                    ,
                },
                backward: Type = "f32",
                __backward: Meta = .{
                    .description =
                    \\Position where right sensor turns off in backward
                    \\direction. Measured by calibration.
                    ,
                },
            } = .{},
        } = .{},
        section_count: struct {
            on: struct {
                forward: Type = "i16",
                __forward: Meta = .{
                    .description =
                    \\Section count where right sensor turns on in forward
                    \\direction. Measured by calibration.
                    ,
                },
                backward: Type = "i16",
                __backward: Meta = .{
                    .description =
                    \\Section count where left sensor turns on in backward
                    \\direction. Measured by calibration.
                    ,
                },
            } = .{},
            off: struct {
                forward: Type = "i16",
                __forward: Meta = .{
                    .description =
                    \\Section count where left sensor turns off in forward
                    \\direction. Measured by calibration.
                    ,
                },
                backward: Type = "i16",
                __backward: Meta = .{
                    .description =
                    \\Section count where right sensor turns off in backward
                    \\direction. Measured by calibration.
                    ,
                },
            } = .{},
        } = .{},
    } = .{},
};

pub const State = struct {
    servo_enabled: Type = "bool",
    __servo_enabled: Meta = .{ .description = "True if servo is on." },
    cc_link_enabled: Type = "bool",
    __cc_link_enabled: Meta = .{ .description = "True if CC-Link is on." },
    calibrated: Type = "bool",
    __calibrated: Meta = .{
        .description = "True if calibration is completed.",
    },
    vdc: Type = "f32",
    __vdc: Meta = .{
        .description = "Measured supply voltage for motor coils.",
        .unit_short = "V",
        .unit_long = "Volt",
    },
    thermo: Type = "f32",
    __thermo: Meta = .{ .description = "Inverter temperature." },
    sys_version: Type = "f32",
    __sys_version: Meta = .{
        .description = "Firmware version of this Driver.",
    },
    sensor: struct {
        home: Type = "u8",
        __home: Meta = .{ .description = "Home sensor reading. 0 if sensed." },
        id0: Type = "u8",
        __id0: Meta = .{ .description = "ID0 sensor reading. 0 if sensed." },
        id1: Type = "u8",
        __id1: Meta = .{ .description = "ID1 sensor reading. 0 if sensed." },
        id2: Type = "u8",
        __id2: Meta = .{ .description = "ID2 sensor reading. 0 if sensed." },
    } = .{},
    synchronization_request_position: struct {
        forward: Type = "f32",
        __forward: Meta = .{
            .description =
            \\Position to receive profile request from next Axis during
            \\backward calibration.
            ,
        },
        backward: Type = "f32",
        __backward: Meta = .{
            .description =
            \\Position to receive profile request from next Axis during
            \\forward calibration.
            ,
        },
    } = .{},
    section_count: struct {
        deactivate_secondary: struct {
            left: struct {
                forward: struct {
                    axis2: Type = "i16",
                    axis3: Type = "i16",
                } = .{},
                backward: struct {
                    axis1: Type = "i16",
                    axis2: Type = "i16",
                } = .{},
            } = .{},
            right: struct {
                forward: struct {
                    axis2: Type = "i16",
                    axis3: Type = "i16",
                } = .{},
                backward: struct {
                    axis1: Type = "i16",
                    axis2: Type = "i16",
                } = .{},
            } = .{},
        } = .{},
        __deactivate_secondary: Meta = .{
            .description =
            \\Section counts at which secondary Axis is deactivated. Secondary
            \\Axis is the Axis that was primary before next Axis took over.
            \\`left` and `right` are the side Slider entered secondary Axis
            \\from, `forward` and `backward` are Slider movement direction, and
            \\`axisN` is the primary Axis whose section count is compared.
            \\Forward triggers when count >= value, backward triggers when
            \\count <= value.
            ,
        },
        activate_primary: struct {
            left: struct {
                forward: struct {
                    axis1: Type = "i16",
                    axis2: Type = "i16",
                    axis3: Type = "i16",
                } = .{},
                backward: struct {
                    axis1: Type = "i16",
                    axis2: Type = "i16",
                    axis3: Type = "i16",
                } = .{},
            } = .{},
            right: struct {
                forward: struct {
                    axis1: Type = "i16",
                    axis2: Type = "i16",
                    axis3: Type = "i16",
                } = .{},
                backward: struct {
                    axis1: Type = "i16",
                    axis2: Type = "i16",
                    axis3: Type = "i16",
                } = .{},
            } = .{},
        } = .{},
        __activate_primary: Meta = .{
            .description =
            \\Section counts at which a deactivated Axis becomes primary again.
            \\`left` and `right` are the side Slider entered the Axis from,
            \\`forward` and `backward` are Slider movement direction, and
            \\`axisN` is the Axis. Forward triggers when count >= value,
            \\backward triggers when count <= value.
            ,
        },
    } = .{},
    __section_count: Meta = .{
        .description =
        \\Section count thresholds for handing Slider between primary and
        \\secondary Axis. Each threshold is a section count of primary Axis.
        ,
    },
    axes: [3]State.Axis = .{ .{}, .{}, .{} },

    pub const Axis = struct {
        enabled: Type = "bool",
        __enabled: Meta = .{
            .description = "True if Axis is active.",
        },
        primary: Type = "bool",
        __primary: Meta = .{ .description = "True if Axis is primary." },
        slider: struct {
            id: Type = "u8",
            __id: Meta = .{ .description = "ID of Slider on this Axis." },
            state: Type = "Fsm",
            __state: Meta = .{
                .description = "State of Slider on this Axis.",
            },
        } = .{},
        entrance: Type = "Entrance",
        __entrance: Meta = .{
            .description = "Side where Slider entered this Axis.",
        },
        overcharge_state: Type = "Fsm",
        __overcharge_state: Meta = .{
            .description = "State of Slider before overcurrent.",
        },
        pitch_count: Type = "i16",
        __pitch_count: Meta = .{ .description = "Pitch count." },
        mechanical_position: Type = "f32",
        __mechanical_position: Meta = .{
            .description =
            \\Position of Slider. Integer part counts magnet pitches.
            ,
            .unit_short = "pitch",
            .unit_long = "Magnet pitch",
        },
        bias: struct {
            a: Type = "f32",
            __a: Meta = .{ .description = "A-phase current offset." },
            b: Type = "f32",
            __b: Meta = .{ .description = "B-phase current offset." },
        } = .{},
    };
};
