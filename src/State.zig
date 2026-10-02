servo_enabled: bool,
cc_link_enabled: bool,
calibrated: bool,
vdc: f32,
thermo: f32,
theta_offset: f32,
sys_version: f32,
sensor: struct {
    home: u8,
    id0: u8,
    id1: u8,
    id2: u8,
},
synchronization_request_position: struct {
    forward: f32,
    backward: f32,
},
axes: [3]Axis,

pub const Axis = struct {
    enabled: bool,
    primary: bool,
    slider: struct {
        id: u8,
        state: Fsm,
    },
    entrance: Entrance,
    overcharge_state: Fsm,
    pitch_count: i16,
    restart_section_count: i16,
    base_position: f32,
    mechanical_position: f32,
    bias: struct {
        a: f32,
        b: f32,
    },
    sensor: struct {
        position: struct {
            on: struct {
                /// Position of right sensor when slider moves forward and
                /// turned on the sensor
                forward: f32,
                /// Position of left sensor when slider moves backward and
                /// turned on the sensor
                backward: f32,
            },
            off: struct {
                /// Position of left sensor when slider moves forward and
                /// turned off the sensor
                forward: f32,
                /// Position of right sensor when slider moves backward and
                /// turned off the sensor
                backward: f32,
            },
        },
        section_count: struct {
            restart: i16,
            on: struct {
                /// Section count of right sensor when slider moves forward and
                /// turned on the sensor
                forward: i16,
                /// Section count of left sensor when slider moves backward and
                /// turned on the sensor
                backward: i16,
            },
            off: struct {
                // There is not section count off when moving forward
                /// Section count of right sensor when slider moves backward and
                /// turned off the sensor
                backward: i16,
            },
        },
    },
};

pub const Fsm = enum(u8) {
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
