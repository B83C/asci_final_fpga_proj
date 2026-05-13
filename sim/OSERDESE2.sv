`timescale 1ns / 1ps

// Behavioral simulation model for Xilinx OSERDESE2
// Serializes parallel data LSB-first: D1 → D2 → ... → D8 → SHIFTIN1 → SHIFTIN2
// For DATA_WIDTH=10, two instances (MASTER + SLAVE) cascade to form 10 bits:
//   MASTER: D1-D8 = bits [7:0], SHIFTIN1/2 = bits [9:8] (from SLAVE SHIFTOUT1/2)
//   SLAVE:  D3 = bit 8, D4 = bit 9, SHIFTOUT1 = D3, SHIFTOUT2 = D4

module OSERDESE2 (
    OQ, OFB, SHIFTOUT1, SHIFTOUT2, TBYTEOUT, TFB, TQ,
    CLK, CLKDIV, RST, OCE,
    D1, D2, D3, D4, D5, D6, D7, D8,
    SHIFTIN1, SHIFTIN2,
    T1, T2, T3, T4, TBYTEIN, TCE
);

  parameter DATA_RATE_OQ  = "DDR";
  parameter DATA_RATE_TQ  = "SDR";
  parameter DATA_WIDTH    = 10;
  parameter INIT_OQ       = 1'b0;
  parameter INIT_TQ       = 1'b0;
  parameter SERDES_MODE   = "MASTER";
  parameter SRVAL_OQ      = 1'b0;
  parameter SRVAL_TQ      = 1'b0;
  parameter TBYTE_CTL     = "FALSE";
  parameter TBYTE_SRC     = "FALSE";
  parameter TRISTATE_WIDTH = 1;

  output OQ, OFB, SHIFTOUT1, SHIFTOUT2, TBYTEOUT, TFB, TQ;
  input  CLK, CLKDIV, RST, OCE;
  input  D1, D2, D3, D4, D5, D6, D7, D8;
  input  SHIFTIN1, SHIFTIN2;
  input  T1, T2, T3, T4, TBYTEIN, TCE;

  reg [9:0] sr;
  reg [3:0] cnt;
  reg clkdiv_d;
  reg oq_r;

  // Edge detection for CLKDIV (sampled on posedge CLK)
  always @(posedge CLK or posedge RST) begin
    if (RST) clkdiv_d <= 0;
    else     clkdiv_d <= CLKDIV;
  end

  // Shift on both CLK edges (DDR) or posedge only (SDR)
  always @(CLK or posedge RST) begin
    if (RST) begin
      sr   <= 0;
      cnt  <= 0;
      oq_r <= 0;
    end else begin
      if (CLKDIV && !clkdiv_d && OCE) begin
        sr  <= {SHIFTIN2, SHIFTIN1, D8, D7, D6, D5, D4, D3, D2, D1};
        cnt <= 10;
      end else if (cnt > 0) begin
        oq_r <= sr[0];
        sr   <= {1'b0, sr[9:1]};
        cnt  <= cnt - 1;
      end
    end
  end

  assign OQ        = oq_r;
  assign OFB       = 0;
  assign TBYTEOUT  = 0;
  assign TFB       = 0;
  assign TQ        = 0;

  // In SLAVE mode: pass bit-8 (D3) and bit-9 (D4) to master via SHIFTOUT1/2
  assign SHIFTOUT1 = (SERDES_MODE == "SLAVE") ? D3 : 0;
  assign SHIFTOUT2 = (SERDES_MODE == "SLAVE") ? D4 : 0;

endmodule
