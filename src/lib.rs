use marlin::{verilator::tracing::Trace, verilog::prelude::*};

#[verilog(src = "src/top.sv", name = "top_simulation")]
pub struct TopVga;

impl TopVga<'_> {
    pub fn tick(&mut self, trace: &mut Option<Trace<'_>>, timestamp: &mut u64) {
        self.clk = 0;
        self.eval();
        if let Some(trace) = trace {
            *timestamp += 1;
            trace.dump(*timestamp);
        }
        self.clk = 1;
        self.eval();
        if let Some(trace) = trace {
            *timestamp += 1;
            trace.dump(*timestamp);
        }
    }
}
