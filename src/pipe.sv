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
  reg [M - 1:0] counter[STAGES] = '{STAGES{0}};


  always @(posedge clk, negedge rstn) begin
    if (en) begin
      counter[0] <= x;
      for (int unsigned i = 1; i < STAGES; i++) begin
        counter[i] <= counter[i-1];
      end
    end
    if (!rstn) begin
      counter <= '{STAGES{0}};
    end
  end

  assign y = counter[STAGES-1];
endmodule
