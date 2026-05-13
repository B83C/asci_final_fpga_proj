`timescale 1ns / 1ps

//TODO Marlin does not support constant expression for now
module lfsr #(
    parameter unsigned MIN = 100,
    parameter unsigned MAX = 65536,
    parameter unsigned SEED = 16'hFADE,
    localparam unsigned N = $clog2(MAX)
) (
    input clk,
    input rstn,
    input en,

    output [N - 1:0] out
);
  reg [15:0] x = SEED;

  wire next_x = x[15] ^ x[13] ^ x[12] ^ x[10] ^ 1;

  always @(posedge clk, negedge rstn) begin
    if (!rstn) begin
      x <= SEED;
    end else begin
      if (en) begin
        x <= {x[14:0], next_x};
      end
    end
  end

  int p = 16 - N + 1;
  assign out = N'(MIN) + N'(p > 0 ? x >> p : x);
endmodule

module test_lfsr (
    input clk,
    input rstn,
    input en,

    output [12:0] out
);
  lfsr #(
      .MIN(1000),
      .MAX(6234)
  ) dut (
      .clk (clk),
      .rstn(rstn),
      .en  (en),
      .out (out)
  );
endmodule
