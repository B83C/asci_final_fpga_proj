`timescale 1ns / 1ps

module ram #(
    parameter int WIDTH = 16,
    parameter int DEPTH = 8,
    parameter string BINARY_FILE = "rom",
    parameter int ADDR_BITS = $clog2(DEPTH)
) (
    input clk,
    input [ADDR_BITS - 1:0] addr,
    output logic [WIDTH - 1:0] data
);
  logic [WIDTH-1:0] irom[DEPTH];
  initial begin
    $readmemh(BINARY_FILE, irom);
  end

  always @(posedge clk) begin
    data <= irom[addr];
  end
endmodule
