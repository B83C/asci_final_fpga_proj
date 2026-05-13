`timescale 1ns / 1ps

module debouncer #(
    // 75MHz 
    parameter unsigned CYCLES = 128,
    parameter unsigned INVERT = 1
) (
    input clk,
    input rstn,
    input raw_input,
    output reg triggered,
    output reg debounced_output
);
  localparam unsigned Next2Pos = ($clog2(CYCLES) + 1);
  localparam unsigned CyclesRounded = 1 << Next2Pos;
  localparam unsigned MIDPOINT = Next2Pos - 1;
  // To eliminate meta-stability
  logic buffers[2];
  always @(posedge clk, negedge rstn) begin
    buffers <= {buffers[0], raw_input};
    if (!rstn) begin
      buffers <= '{0, 0};
    end
  end
  wire filtered = buffers[1];

  wire flipped = filtered ^ INVERT;

  wire counter_end;

  generic_counter #(
      .MAX(CyclesRounded)
  ) clock_divider (
      .clk(clk),
      .rstn(rstn),
      .en(1),
      .ending(counter_end),
      .x()
  );

  logic [Next2Pos - 1:0] val;
  generic_counter #(
      .MAX(CyclesRounded)
  ) integrator (
      .clk(clk),
      .rstn(rstn && !counter_end),
      .en(flipped),
      .ending(),
      .x(val)
  );

  always @(posedge clk) begin
    // Listens for positive edge
    triggered <= counter_end && (val[MIDPOINT-1] && !debounced_output);
    if (counter_end) begin
      debounced_output <= val[MIDPOINT-1];
    end
  end

endmodule
