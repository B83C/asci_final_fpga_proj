use std::{ops::AddAssign, path::Path};

use asic::TopVga;
use histo::Histogram;
use marlin::{
    verilator::{AsDynamicVerilatedModel, VerilatorRuntime, VerilatorRuntimeOptions},
    verilog::prelude::*,
};
use marlin_test::prelude::*;
use snafu::Whatever;

// #[test]
// #[snafu::report]
// fn testidk() -> Result<(), Whatever> {
//     let runtime = VerilatorRuntime::new(
//         &Path::new("build"),
//         &["src/top.sv".as_ref()],
//         &["./src".as_ref()],
//         [],
//         VerilatorRuntimeOptions::default(),
//     )
//     .unwrap();

//     let mut top = runtime.create_model::<TopVga>(&marlin::verilator::VerilatedModelConfig {
//         enable_tracing: None,
//         verilator_optimization: 3,
//         ignored_warnings: vec!["fatal".into(), "lint".into()],
//         ..Default::default()
//     })?;
//     // let mut top = runtime.create_model_simple::<TopVga>().unwrap();
//     // top.raw_input = 1;

//     for _ in 0..2000 {
//         top.clk ^= 1;
//         top.eval();
//         if top.hsync == 1 {
//             dbg!(top.hsync);
//         }
//     }
//     // top.raw_input = 0;

//     Ok(())
// }
#[verilog(src = "src/lfsr.sv", name = "test_lfsr")]
pub struct Lsfr;

#[marlin_verilog_test]
#[fst("test.fst")]
fn test_vga<'a>(mut module: Seq<'a, Lsfr<'a>>) {
    let mut h = Histogram::with_buckets(16);

    module.rstn = 0;
    module.tick();
    module.rstn = 1;
    module.en = 1;
    module.tick();

    for i in 0..300 {
        let val = module.out;
        h.add(val as u64);
        module.tick();
    }

    // println!("{h}");
}

#[verilog(
    src = "src/generic_countdown_counter.sv",
    name = "test_generic_countdown_counter"
)]
pub struct Generic_Countdown;

#[marlin_verilog_test]
#[fst("test2.fst")]
fn test_countdown<'a>(mut module: Seq<'a, Generic_Countdown<'a>>) {
    // let mut h = Histogram::with_buckets(16);
    let cycles = 388;

    module.rstn = 0;
    module.tick();
    module.rstn = 1;
    module.en = 1;
    module.load_val = cycles;
    module.load = 1;
    module.tick();

    assert_eq!(module.done != 0, false);

    for i in 0..cycles {
        module.tick();
    }

    assert_eq!(module.done != 0, true);
}

#[verilog(src = "src/debouncer.sv", name = "debouncer")]
pub struct Debouncer;

#[marlin_verilog_test]
#[fst("testdebouncer.fst")]
fn test_debouncer<'a>(mut module: Seq<'a, Debouncer<'a>>) {
    // let mut h = Histogram::with_buckets(16);
    let cycles = 128;

    module.rstn = 0;
    module.tick();
    module.rstn = 1;
    module.tick();

    module.raw_input = 0;
    module.tick();
    assert!(module.debounced_output == 0);

    module.raw_input = 1;
    module.tick();
    assert!(module.debounced_output == 0);

    for i in 0..cycles / 2 {
        module.tick();
    }

    assert!(module.debounced_output == 0);

    for i in 0..cycles / 2 {
        module.tick();
    }

    assert!(module.debounced_output == 1);
}

#[verilog(src = "src/generic_counter.sv", name = "test_generic_counter")]
pub struct GenericCounter;

#[marlin_verilog_test]
#[vcd("test_counter.vcd")]
fn test_counter<'a>(mut module: Seq<'a, GenericCounter<'a>>) {
    // let mut h = Histogram::with_buckets(16);
    let cycles = 16;

    module.rstn = 0;
    module.tick();
    module.rstn = 1;
    module.en = 1;

    for i in 0..cycles - 1 {
        assert_eq!(module.x, i);
        module.tick();
    }
    assert_eq!(module.x, cycles - 1);
    assert!(module.ending == 1);
}

#[marlin_verilog_test]
#[vcd("test_counter2.vcd")]
fn test_counter_unen<'a>(mut module: Seq<'a, GenericCounter<'a>>) {
    // let mut h = Histogram::with_buckets(16);
    let cycles = 16;

    module.rstn = 0;
    module.tick();
    module.rstn = 1;
    module.en = 0;

    for i in 0..cycles - 1 {
        assert_eq!(module.x, 0);
        module.tick();
    }
    assert_eq!(module.x, 0);
    assert!(module.ending == 0);

    module.en = 1;
    module.tick();
    assert_eq!(module.x, 1);
}


// #[marlin_verilog_test]
// #[fst("test.fst")]
// fn test_vga<'a>(mut module: Seq<'a, TopVga<'a>>) {
//     module.rstn = 1;
//     module.tick();
//     module.rstn = 0;
//     module.tick();
// }

// #[verilog(src = "src/timing_counter.sv", name = "timing_counter")]
// pub struct TimingCounter;

// #[marlin_verilog_test()]
// #[fst("test.fst")]
// fn counter_test<'a>(module: Seq<'a, TimingCounter<'a>>) {
//     let mut module = module.with_clk("pixclk");
//     module.rst = 1;
//     module.en = 1;
//     module.tick();
//     module.rst = 0;
//     module.tick();

//     for i in 0..10 {
//         dbg!(module.x);
//         module.tick();
//     }
// }

// #[test]
// #[snafu::report]
// fn counter_test() -> Result<(), Whatever> {
//     let runtime = VerilatorRuntime::new(
//         &Path::new("build"),
//         &["src/timing_counter.sv".as_ref()],
//         &["./src".as_ref()],
//         [],
//         VerilatorRuntimeOptions::default(),
//     )
//     .unwrap();

//     let mut top = runtime.create_model::<TopVga>(&marlin::verilator::VerilatedModelConfig {
//         enable_tracing: None,
//         verilator_optimization: 3,
//         ignored_warnings: vec!["fatal".into(), "lint".into()],
//         ..Default::default()
//     })?;
//     // let mut top = runtime.create_model_simple::<TopVga>().unwrap();
//     // top.raw_input = 1;

//     for _ in 0..2000 {
//         top.clk ^= 1;
//         top.eval();
//         if top.hsync == 1 {
//             dbg!(top.hsync);
//         }
//     }
//     // top.raw_input = 0;

//     Ok(())
// }
