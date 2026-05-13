// `timescale 1ns / 1ps

// module test (
//     input clk,
//     input rst_,

//     input buttons[2],

//     output reg leds[2],

//     vga_if vga
// );
//   wire bi[2];
//   generate
//     genvar j;
//     for (j = 0; j < 2; j++) begin : gen_debouncer
//       debouncer db (
//           .clk(clk),
//           .raw_input(buttons[j]),
//           .debounced_output(bi[j])
//       );
//     end
//   endgenerate

//   always @(posedge clk) begin
//     for (int i = 0; i < 2; i++) begin
//       leds[i] <= bi[i];
//     end
//   end

//   wire pixclk;
//   wire serdes_clk;
//   wire rst;
//   reg [7:0] rstcnt;
//   wire locked;

//   wire hsync, hblank, vsync, vblank, active, fsync;


//   integer count;
//   reg [1:0] sw;

//   clk_wiz_0 cl_inst (
//       // Clock out ports
//       .clk_375(serdes_clk),
//       .clk_75 (pixclk),
//       // Status and control signals
//       .reset  (0),
//       .locked (locked),
//       // Clock in ports
//       .clk_in1(clk50)
//   );

//   always @(posedge pixclk or negedge locked) begin
//     if (~locked) begin
//       rstcnt <= 0;
//     end else begin
//       if (rstcnt != 8'hff) begin
//         rstcnt <= rstcnt + 1;
//       end
//     end
//   end

//   assign rst = (rstcnt == 8'hff) ? 1'b0 : 1'b1;

//   v_tc_0 video_timing_inst (
//       .clk(pixclk),
//       .clken(1),
//       .gen_clken(1),
//       .sof_state(1),
//       .hsync_out(hsync),
//       .hblank_out(hblank),
//       .vsync_out(vsync),
//       .vblank_out(vblank),

//       .active_video_out(active),
//       .resetn(~rst),
//       .fsync_out(fsync)
//   );

//   localparam int TIMER = 75000000;

//   always @(posedge pixclk) begin
//     if (rst) begin
//       count <= 0;
//       sw <= 2'b00;
//     end else begin
//       if (count < TIMER - 1) begin
//         count <= count + 1;
//       end else begin
//         count <= 0;
//         if (sw == 2'b11) begin
//           sw <= 2'b01;
//         end else begin
//           sw <= sw + 1;
//         end
//       end
//     end
//   end

//   assign vga.r = (sw == 2'b01) ? 8'hff : 8'h00;
//   assign vga.g = (sw == 2'b10) ? 8'hff : 8'h00;
//   assign vga.b = (sw == 2'b11) ? 8'hff : 8'h00;

//   assign vga.hsync = hsync;
//   assign vga.vsync = vsync;
//   assign vga.hblank = hblank;
//   assign vga.vblank = vblank;
//   assign vga.fsync = fsync;
//   assign vga.active = active;

// endmodule

// module top_dvi (
//     input pixclk,
//     input serdes_clk,
//     input rst,
//     vga_if vga,
//     tmds_bus_if tmds_output
// );
//   wire [1:0] ctl[3];
//   wire [7:0] pdata[3];
//   wire [9:0] tmds_data[3];

//   wire active = vga.active;

//   assign pdata[2] = vga.r;
//   assign pdata[1] = vga.g;
//   assign pdata[0] = vga.b;

//   assign ctl[0]   = {vga.vsync, vga.hsync};
//   assign ctl[1]   = 2'b00;
//   assign ctl[2]   = 2'b00;

//   generate
//     genvar i;

//     for (i = 0; i < 3; i = i + 1) begin : gen_tmds

//       wire [9:0] tmds_p;
//       tmds_encoder encoder (
//           .clk(pixclk),
//           .video_data(pdata[i]),
//           .control_data(ctl[i]),
//           .video_data_enable(active),
//           .TMDS(tmds_p)
//       );

//       tmds_serdes serdes (
//           .pixclk(pixclk),
//           .serdes_clk(serdes_clk),
//           .rst(rst),
//           .tmds_p(tmds_p),
//           .tmds_tx_serial_n(tmds_output.tmds_tx_data_n[i]),
//           .tmds_tx_serial_p(tmds_output.tmds_tx_data_p[i])
//       );

//     end
//   endgenerate

//   tmds_serdes serdes (
//       .pixclk(pixclk),
//       .serdes_clk(serdes_clk),
//       .rst(rst),
//       .tmds_p(10'b1111100000),
//       .tmds_tx_serial_n(tmds_output.tmds_tx_clk_n),
//       .tmds_tx_serial_p(tmds_output.tmds_tx_clk_p)
//   );
// endmodule
