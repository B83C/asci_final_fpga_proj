`timescale 1ns / 1ps

module tmds_encoder (
    input clk,
    input [7:0] video_data,
    input [1:0] control_data,
    input video_data_enable,
    output reg [9:0] TMDS = 0
);

  wire [3:0] popcnt = video_data[0]
+ video_data[1]
+ video_data[2]
+ video_data[3]
+ video_data[4]
+ video_data[5]
+ video_data[6]
+ video_data[7];

  wire use_xnor = (popcnt > 4'd4) || (popcnt == 4'd4 && video_data[0]);

  wire [8:0] q_m = {~use_xnor, q_m[6:0] ^ video_data[7:1] ^ {7{use_xnor}}, video_data[0]};

  reg [3:0] balance_acc = 0;
  wire [3:0] balance = q_m[0] + q_m[1] + q_m[2] + q_m[3] + q_m[4] + q_m[5] + q_m[6] + q_m[7] - 4'd4;
  wire balance_sign_eq = (balance[3] == balance_acc[3]);
  wire invert_q_m = (balance == 0 || balance_acc == 0) ? ~q_m[8] : balance_sign_eq;

  wire [3:0] balance_acc_inc = balance - ({q_m[8] ^ ~balance_sign_eq} & ~(balance==0 || balance_acc==0));
  wire [3:0] balance_acc_new = invert_q_m ? balance_acc-balance_acc_inc : balance_acc+balance_acc_inc;

  // Pixel data
  // I suppose q_m is the encoded data herem
  wire [9:0] TMDS_data = {invert_q_m, q_m[8], q_m[7:0] ^ {8{invert_q_m}}};
  // Control code
  logic [9:0] TMDS_code;
  // = control_data[1] ? (control_data[0] ? 10'b1010101011 : 10'b0101010100) : (control_data[0] ? 10'b0010101011 : 10'b1101010100);

  always_comb begin
    unique case (control_data)
      2'b00: begin
        TMDS_code = 10'b1101010100;
      end
      2'b01: begin
        TMDS_code = 10'b0010101011;
      end
      2'b10: begin
        TMDS_code = 10'b0101010100;
      end
      2'b11: begin
        TMDS_code = 10'b1010101011;
      end
    endcase
  end

  always @(posedge clk) TMDS <= video_data_enable ? TMDS_data : TMDS_code;
  always @(posedge clk) balance_acc <= video_data_enable ? balance_acc_new : 4'h0;
endmodule
