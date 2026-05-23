`timescale 1ns / 1ps

module pipe #(
    parameter unsigned STAGES = 1,
    parameter unsigned M = 1
) (
    input clk,
    input rstn,
    input en,

    input  [M - 1:0] x,
    output [M - 1:0] y
);
  reg [M - 1:0] counter[STAGES];

  genvar i;
  generate
    for (i = 0; i < STAGES; i = i + 1) begin : gen_stage
      always @(posedge clk, negedge rstn) begin
        if (!rstn) begin
          counter[i] <= 0;
        end else if (en) begin
          counter[i] <= (i == 0) ? x : counter[i-1];
        end
      end
    end
  endgenerate

  assign y = counter[STAGES-1];
endmodule
