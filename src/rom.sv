`timescale 1ns/1ps
module rom #(
	WIDTH = 16,
	DEPTH = 8,
	RISING_EDGE = 1,
	binaryFile = "rom",
	localparam ADDR_BITS= $clog2(DEPTH)
)(
	input clk,
	input [ADDR_BITS - 1:0] addr,
	output logic [WIDTH - 1:0] data
);
	logic [WIDTH-1:0] irom[DEPTH - 1: 0];
	initial begin
		$readmemh(binaryFile, irom);
  end

	// assign data = irom[addr];

	generate 
		if (RISING_EDGE == 1) begin
		 	always_ff @(posedge clk) begin
				data <= irom[addr];
		  end
		end else begin
		 	always_ff @(negedge clk) begin
				data <= irom[addr];
		  end
		end
 	endgenerate

endmodule
