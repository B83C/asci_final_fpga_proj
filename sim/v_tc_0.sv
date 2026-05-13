`timescale 1ns / 1ps

module v_tc_0 (
    input  clk,
    input  clken,
    input  gen_clken,
    input  sof_state,
    input  resetn,
    output reg hsync_out,
    output reg hblank_out,
    output reg vsync_out,
    output reg vblank_out,
    output reg active_video_out,
    output reg fsync_out
);
  reg [9:0] hcount = 0;
  reg [9:0] vcount = 0;

  always @(posedge clk or negedge resetn) begin
    if (~resetn) begin
      hcount <= 0;
      vcount <= 0;
    end else if (clken) begin
      if (hcount == 799) begin
        hcount <= 0;
        if (vcount == 524)
          vcount <= 0;
        else
          vcount <= vcount + 1;
      end else begin
        hcount <= hcount + 1;
      end
    end
  end

  always @(posedge clk or negedge resetn) begin
    if (~resetn) begin
      hsync_out       <= 0;
      hblank_out      <= 0;
      vsync_out       <= 0;
      vblank_out      <= 0;
      active_video_out <= 0;
      fsync_out       <= 0;
    end else if (clken) begin
      hsync_out       <= (hcount >= 656) && (hcount < 752);
      hblank_out      <= (hcount >= 640);
      vsync_out       <= (vcount >= 490) && (vcount < 492);
      vblank_out      <= (vcount >= 480);
      active_video_out <= (hcount < 640) && (vcount < 480);
      fsync_out       <= (vcount == 0) && (hcount == 0);
    end
  end

endmodule
