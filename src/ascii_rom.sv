`timescale 1ns / 1ps

module ascii_rom #(
    parameter int WIDTH = 16,
    parameter int DEPTH = 8,
    parameter int ADDR_BITS = $clog2(DEPTH)
) (
    input clk,
    input [ADDR_BITS - 1:0] addr,
    output logic [WIDTH - 1:0] data
);
  (* ram_style = "block" *) logic [WIDTH-1:0] irom[DEPTH];
  initial begin
    $readmemh("ascii.rom", irom);
  end

  always @(posedge clk) begin
    data <= irom[addr];
  end
endmodule
