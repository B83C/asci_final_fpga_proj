`timescale 1ns / 1ps

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
    if (en) counter <= ending ? 0 : counter + 1;
    if (!rstn) begin
      counter <= 0;
      // sync <= 0;
    end else begin
      // sync <= (counter >= DISP + FP) && (counter < DISP + FP + SW);
    end
  end

  assign x = counter;

  assign sync = rstn && (counter >= DISP + FP) && (counter < DISP + FP + SW);

  assign active = rstn && counter < DISP;
endmodule
