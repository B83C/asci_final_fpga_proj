`timescale 1ns / 1ps

// Yosys-compatible copy: fixed async reset pattern
module timing_counter #(
    parameter unsigned DISP = 640,
    parameter unsigned FP = 16,
    parameter unsigned SW = 96,
    parameter unsigned BP = 48,
    parameter unsigned N = 12
) (
    input pixclk,
    input rstn,
    input en,

    output reg sync,

    output [N - 1:0] x,

    output active,
    output ending
);
  reg [N - 1:0] counter = 0;

  localparam int TOTAL = DISP + FP + SW + BP;
  localparam logic [N - 1:0] LAST = N'(TOTAL - 1);
  assign ending = counter == LAST;

  always @(posedge pixclk, negedge rstn) begin
    if (!rstn) begin
      counter <= 0;
    end else if (en) begin
      counter <= ending ? 0 : counter + 1;
    end
  end

  assign x = counter;

  assign sync = rstn && (counter >= DISP + FP) && (counter < DISP + FP + SW);

  assign active = rstn && counter < DISP;
endmodule
