use std::{ops::AddAssign, path::Path};

use asic::TopVga;
use histo::Histogram;
use marlin::{
    verilator::{AsDynamicVerilatedModel, VerilatorRuntime, VerilatorRuntimeOptions},
    verilog::prelude::*,
};
use marlin_test::prelude::*;
use snafu::Whatever;

// #[verilog(src = "src/state.sv", name = "state")]
// pub struct State;

// #[marlin_verilog_test]
// fn test_render<'a>(mut module: Seq<'a, State<'a>>) {
//     module.tick();
//     module.bi = 1;
//     module.tick();
//     // assert_eq!(module.pixel_color, 0xFF0000, "bi=0 → red");

//     module.bi = 2;
//     module.tick();
//     // assert_eq!(module.pixel_color, 0x00FF00, "bi=2 → green");
// }

#[verilog(src = "src/test_debouncer2.sv", name = "test_debouncer2")]
pub struct Debouncer2;

#[marlin_verilog_test]
fn debouncer_press<'a>(mut module: Seq<'a, Debouncer2<'a>>) {
    // CYCLES=2 → counter_end every 4 cycles, val[0] determines output
    module.rstn = 0;
    module.raw_input = 1;
    module.tick();
    module.rstn = 1;
    // Wait past first counter_end so debounced_output stabilises
    for _ in 0..8 {
        module.tick();
    }
    assert_eq!(module.debounced_output, 0, "initially low");
    assert_eq!(module.triggered, 0, "no trigger initially");

    // Press
    module.raw_input = 0;
    // Wait up to 16 cycles for the output to go high
    let mut saw_trigger = false;
    for _ in 0..16 {
        module.tick();
        if module.triggered != 0 {
            saw_trigger = true;
        }
    }
    assert!(saw_trigger, "triggered pulsed after press");
    assert_eq!(module.debounced_output, 1, "output high after press");
}

#[marlin_verilog_test]
fn debouncer_hold<'a>(mut module: Seq<'a, Debouncer2<'a>>) {
    module.rstn = 0;
    module.raw_input = 1;
    module.tick();
    module.rstn = 1;
    for _ in 0..8 { module.tick(); }

    // Press and hold
    module.raw_input = 0;
    for _ in 0..16 { module.tick(); }
    assert_eq!(module.debounced_output, 1, "high while held");

    // No new triggered while holding (already high)
    let mut trigger_count = 0;
    for _ in 0..32 {
        module.tick();
        if module.triggered != 0 {
            trigger_count += 1;
        }
    }
    assert_eq!(trigger_count, 0, "no new triggered while holding");
    assert_eq!(module.debounced_output, 1, "stays high");
}

#[marlin_verilog_test]
fn debouncer_release<'a>(mut module: Seq<'a, Debouncer2<'a>>) {
    module.rstn = 0;
    module.raw_input = 1;
    module.tick();
    module.rstn = 1;
    for _ in 0..8 { module.tick(); }

    // Press
    module.raw_input = 0;
    for _ in 0..16 { module.tick(); }
    assert_eq!(module.debounced_output, 1, "high after press");

    // Release
    module.raw_input = 1;
    for _ in 0..16 { module.tick(); }
    assert_eq!(module.debounced_output, 0, "low after release");
}

#[marlin_verilog_test]
fn debouncer_glitch<'a>(mut module: Seq<'a, Debouncer2<'a>>) {
    module.rstn = 0;
    module.raw_input = 1;
    module.tick();
    module.rstn = 1;
    for _ in 0..8 { module.tick(); }
    assert_eq!(module.debounced_output, 0, "initially low");

    // 1-cycle glitch
    module.raw_input = 0;
    module.tick();
    module.raw_input = 1;

    // Wait — output should stay low
    let mut saw_trigger = false;
    for _ in 0..32 {
        module.tick();
        if module.triggered != 0 {
            saw_trigger = true;
        }
    }
    assert!(!saw_trigger, "no trigger from glitch");
    assert_eq!(module.debounced_output, 0, "output unchanged after glitch");
}

#[marlin_verilog_test]
fn debouncer_reset<'a>(mut module: Seq<'a, Debouncer2<'a>>) {
    module.rstn = 0;
    module.raw_input = 1;
    module.tick();
    module.rstn = 1;
    for _ in 0..8 { module.tick(); }

    // Press
    module.raw_input = 0;
    for _ in 0..16 { module.tick(); }
    assert_eq!(module.debounced_output, 1, "high before reset");

    // Reset while pressed
    module.rstn = 0;
    module.tick();
    assert_eq!(module.debounced_output, 0, "forced low by reset");
    assert_eq!(module.triggered, 0, "triggered low after reset");
}
