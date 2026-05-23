`timescale 1ns / 1ps
`include "defs.svh"

module display_pipeline #(
    parameter unsigned H = 1280,
    parameter unsigned V = 720,
    parameter unsigned C_H = 8,
    parameter unsigned C_V = 8,
    parameter unsigned SCALE_X = 2,
    parameter unsigned SCALE_Y = 2,
    parameter int Latencies = 6,
    parameter N_H = $clog2(H),
    parameter N_V = $clog2(V)
) (
    input clk,
    input rstn,

    input hactive,
    input vactive,
    input xc_end,
    input yc_end,
    input [N_H-1:0] x,
    input [N_V-1:0] y,
    input hsync,
    input vsync,

    input state_t sys_state,
    input [1:0] bi,
    input [$clog2(30000)-1:0] measured_latency,
    input [$clog2(30000)-1:0] latency_avg,
    input timed_out,

    output vga_hsync,
    output vga_vsync,
    output vga_active,
    output logic [7:0] vga_r,
    output logic [7:0] vga_g,
    output logic [7:0] vga_b
);
  localparam unsigned HCC = H / (C_H * SCALE_X);
  localparam unsigned VCC = V / (C_V * SCALE_Y);
  localparam unsigned X_BOUND = HCC * (C_H * SCALE_X) + 1;
  localparam unsigned Y_BOUND = VCC * (C_V * SCALE_Y) + 1;

  wire sx_ending, cx_ending;
  wire [$clog2(C_H)-1:0] glyph_pixel_x;
  wire [$clog2(C_V)-1:0] glyph_pixel_y;
  wire [$clog2(X_BOUND)-1:0] ascii_x, ascii_y;
  wire sy_ending, cy_ending;

  generic_counter #(
      .MAX(SCALE_X)
  ) sx (
      .clk(clk),
      .rstn(rstn && !xc_end),
      .en(hactive && 1),
      .ending(sx_ending),
      .x()
  );
  generic_counter #(
      .MAX(C_H)
  ) cx (
      .clk(clk),
      .rstn(rstn && !xc_end),
      .en(hactive && sx_ending),
      .ending(cx_ending),
      .x(glyph_pixel_x)
  );
  generic_counter #(
      .MAX(X_BOUND)
  ) xp (
      .clk(clk),
      .rstn(rstn && !xc_end),
      .en(hactive && cx_ending && sx_ending),
      .ending(),
      .x(ascii_x)
  );

  generic_counter #(
      .MAX(SCALE_Y)
  ) sy (
      .clk(clk),
      .rstn(rstn && !(xc_end && yc_end)),
      .en(vactive && xc_end),
      .ending(sy_ending),
      .x()
  );
  generic_counter #(
      .MAX(C_V)
  ) cy (
      .clk(clk),
      .rstn(rstn && !(xc_end && yc_end)),
      .en(vactive && xc_end && sy_ending),
      .ending(cy_ending),
      .x(glyph_pixel_y)
  );
  generic_counter #(
      .MAX(Y_BOUND)
  ) yp (
      .clk(clk),
      .rstn(rstn && !(xc_end && yc_end)),
      .en(vactive && xc_end && cy_ending && sy_ending),
      .ending(),
      .x(ascii_y)
  );

  (* ram_style = "block" *)logic [7:0] text_buffer[HCC * VCC];
  logic [7:0] read_ascii;

  typedef struct {
    int x;
    int y;
  } pos_t;

  function automatic pos_t DS(int x, int y, string Str, int anchor = 0);
    int shift = 0;
    if (anchor == 1) shift = Str.len() / 2;
    else if (anchor == 2) shift = Str.len();
    for (int j = 0; j < Str.len(); j++) begin
      text_buffer[y*HCC+x+j-shift] = unsigned'(Str[j]);
    end
    DS.x = x + Str.len() - shift;
    DS.y = y;
  endfunction

  pos_t p0, p1, p2, p3, p4, p5, p6, p7;
  initial begin
    p0 = DS(5, 6, "System State");
    p1 = DS(5, 8, "Current: ");
    p2 = DS(5, 10, "Latency: ");
    void'(DS(p2.x + 5, p2.y, "ms"));
    p3 = DS(51, 16, "START", 1);
    p4 = DS(51, 24, "RESET", 1);
    p5 = '{x: 5, y: 14};
    p6 = DS(40, 1, "Human Reflex Tester", 1);
    p7 = DS(5, 12, "Average: ");
    void'(DS(p7.x + 5, p7.y, "ms"));
  end

  logic [7:0] buffer[10];
  always_comb begin
    case (sys_state)
      IDLE: buffer = {>>8{"      IDLE"}};
      INIT: buffer = {>>8{"      INIT"}};
      TRIGGERED: buffer = {>>8{"   WAITING"}};
      MEASURING: buffer = {>>8{" MEASURING"}};
      MEASURED: buffer = {>>8{"  MEASURED"}};
      SPAM: buffer = {>>8{"  SPAMMED!"}};
      default: buffer = {>>8{"UNDEFINED"}};
    endcase
  end

  logic [7:0] prompt[20];
  always_comb begin
    if (sys_state == SPAM) prompt = {>>8{"spam: dont cheat    "}};
    else if (sys_state == MEASURING) prompt = {>>8{"  >> press now <<   "}};
    else if (timed_out) prompt = {>>8{"     timed out!     "}};
    else prompt = {>>8{"                    "}};
  end

  function automatic [19:0] bin2bcd(input [14:0] bin);
    reg [19:0] bcd = 0;
    for (int i = 14; i >= 0; i = i - 1) begin
      if (bcd[3:0] >= 5) bcd[3:0] = bcd[3:0] + 3;
      if (bcd[7:4] >= 5) bcd[7:4] = bcd[7:4] + 3;
      if (bcd[11:8] >= 5) bcd[11:8] = bcd[11:8] + 3;
      if (bcd[15:12] >= 5) bcd[15:12] = bcd[15:12] + 3;
      if (bcd[19:16] >= 5) bcd[19:16] = bcd[19:16] + 3;
      bcd = {bcd[18:0], bin[i]};
    end
    return bcd;
  endfunction

  wire [19:0] bcd = bin2bcd(measured_latency);

  logic [7:0] measured_latency_bcd[5];

  assign measured_latency_bcd = '{
          "0" + bcd[19:16],
          "0" + bcd[15:12],
          "0" + bcd[11:8],
          "0" + bcd[7:4],
          "0" + bcd[3:0]
      };

  wire [19:0] avg_bcd = bin2bcd(latency_avg);

  logic [7:0] avg_bcd_digits[5];

  assign avg_bcd_digits = '{
          "0" + avg_bcd[19:16],
          "0" + avg_bcd[15:12],
          "0" + avg_bcd[11:8],
          "0" + avg_bcd[7:4],
          "0" + avg_bcd[3:0]
      };

  reg [$clog2(HCC*VCC)-1:0] text_rd_addr;
  reg [$clog2(Y_BOUND)-1:0] ascii_y_d_0;
  reg [$clog2(X_BOUND)-1:0] ascii_x_d_0;
  always @(posedge clk) begin
    ascii_y_d_0  <= ascii_y;
    ascii_x_d_0  <= ascii_x;
    text_rd_addr <= (ascii_y << 6) + (ascii_y << 4) + ascii_x;
  end

  reg [7:0] text_rd_q;
  reg [$clog2(Y_BOUND)-1:0] ascii_y_d;
  reg [$clog2(X_BOUND)-1:0] ascii_x_d;
  always @(posedge clk) begin
    text_rd_q <= text_buffer[text_rd_addr];
    ascii_y_d <= ascii_y_d_0;
    ascii_x_d <= ascii_x_d_0;
  end

  logic [7:0] react_text[5];
  initial begin
    react_text = {>>8{"REACT"}};
  end
  reg latency_area, avg_area;
  always @(posedge clk) begin
    read_ascii <= text_rd_q;
    foreach (buffer[i]) begin
      if (p1.y == ascii_y_d && ascii_x_d == (p1.x + unsigned'(i))) begin
        read_ascii <= buffer[i];
      end
    end
    foreach (measured_latency_bcd[i]) begin
      if (p2.y == ascii_y_d && ascii_x_d == (p2.x + unsigned'(i))) begin
        read_ascii <= measured_latency_bcd[i];
      end
    end
    foreach (avg_bcd_digits[i]) begin
      if (p7.y == ascii_y_d && ascii_x_d == (p7.x + unsigned'(i))) begin
        read_ascii <= avg_bcd_digits[i];
      end
    end
    foreach (react_text[i]) begin
      if (sys_state == MEASURING && p3.y == ascii_y_d && ascii_x_d == (p3.x - 5 + unsigned'(i))) begin
        read_ascii <= react_text[i];
      end
    end
    foreach (prompt[i]) begin
      if (p5.y == ascii_y_d && ascii_x_d == (p5.x + unsigned'(i))) begin
        read_ascii <= prompt[i];
      end
    end
    latency_area <= (p2.y == ascii_y_d) && (ascii_x_d >= p2.x) && (ascii_x_d <= p2.x + 6);
    avg_area <= (p7.y == ascii_y_d) && (ascii_x_d >= p7.x) && (ascii_x_d <= p7.x + 6);
  end

  reg latency_area_d1, latency_area_d2;
  reg avg_area_d1, avg_area_d2;
  always @(posedge clk) begin
    latency_area_d1 <= latency_area;
    latency_area_d2 <= latency_area_d1;
    avg_area_d1 <= avg_area;
    avg_area_d2 <= avg_area_d1;
  end

  localparam logic [23:0] DARKBG = 24'h2E3440;
  localparam logic [23:0] PANEL = 24'h3B4252;
  localparam logic [23:0] N2 = 24'h434C5E;
  localparam logic [23:0] BORDER = 24'h4C566A;
  localparam logic [23:0] TEXTLIGHT = 24'hD8DEE9;
  localparam logic [23:0] N5 = 24'hE5E9F0;
  localparam logic [23:0] TEAL = 24'h8FBCBB;
  localparam logic [23:0] LIGHTBLUE = 24'h88C0D0;
  localparam logic [23:0] BLUE = 24'h81A1C1;
  localparam logic [23:0] DARKBLUE = 24'h5E81AC;
  localparam logic [23:0] RED = 24'hBF616A;
  localparam logic [23:0] ORANGE = 24'hD08770;
  localparam logic [23:0] YELLOW = 24'hEBCB8B;
  localparam logic [23:0] GREEN = 24'hA3BE8C;

  function automatic logic [23:0] get_latency_color(input [14:0] lat);
    if (lat < 100) return DARKBLUE;
    if (lat < 150) return GREEN;
    if (lat < 250) return YELLOW;
    if (lat < 400) return ORANGE;
    return RED;
  endfunction

  wire [C_V - 1 : 0][C_H - 1 : 0] char_buf;
  reg  [C_V - 1 : 0][C_H - 1 : 0] char_buf_q;

  ascii_rom #(
      .WIDTH(C_H * C_V),
      .DEPTH(128)
  ) ascii (
      .clk (clk),
      .addr(read_ascii[6:0]),
      .data(char_buf)
  );

  always @(posedge clk) char_buf_q <= char_buf;

  typedef enum {
    FILLED,
    HOLLOW
  } style_t;

  typedef struct packed {
    logic [10:0] x0;
    logic [10:0] y0;
    logic [10:0] x1;
    logic [10:0] y1;
    logic [23:0] color;
    style_t style;
  } rect_t;

  localparam unsigned HDR_H = 56;
  localparam unsigned CARD_X = 40;
  localparam unsigned CARD_Y = 80;
  localparam unsigned CARD_W = 570;
  localparam unsigned CARD_H = 580;

  localparam unsigned BT1_X = CARD_X + CARD_W + 72;
  localparam unsigned BT1_Y = 220;
  localparam unsigned BT1_W = 240;
  localparam unsigned BT1_H = 80;
  localparam unsigned BT2_X = BT1_X;
  localparam unsigned BT2_Y = BT1_Y + BT1_H + 60;
  localparam unsigned BT2_W = 240;
  localparam unsigned BT2_H = 60;
  localparam unsigned SHADOW = 6;

  localparam rect_t Rectangles[0:7] = '{
      '{0, 0, H, V, DARKBG, FILLED},
      '{0, 0, H, HDR_H, PANEL, FILLED},
      '{CARD_X, CARD_Y, CARD_X + CARD_W, CARD_Y + CARD_H, PANEL, FILLED},
      '{CARD_X, CARD_Y, CARD_X + CARD_W, CARD_Y + CARD_H, BORDER, HOLLOW},
      '{BT1_X - 30, CARD_Y, BT1_X + BT1_W + 30, CARD_Y + CARD_H, PANEL, FILLED},
      '{BT1_X - 30, CARD_Y, BT1_X + BT1_W + 30, CARD_Y + CARD_H, BORDER, HOLLOW},
      '{
          BT1_X + SHADOW,
          BT1_Y + SHADOW,
          BT1_X + BT1_W + SHADOW,
          BT1_Y + BT1_H + SHADOW,
          DARKBG,
          FILLED
      },
      '{
          BT2_X + SHADOW / 2,
          BT2_Y + SHADOW / 2,
          BT2_X + BT2_W + SHADOW / 2,
          BT2_Y + BT2_H + SHADOW / 2,
          DARKBG,
          FILLED
      }
  };

  function automatic draw(logic [N_H -1:0] x, logic [N_V -1:0] y, rect_t rect);
    unique case (rect.style)
      FILLED: begin
        draw = (x >= rect.x0 && x < rect.x1 && y >= rect.y0 && y < rect.y1);
      end
      HOLLOW: begin
        draw = (x >= rect.x0 &&
         x <  rect.x1 &&
         y >= rect.y0 &&
         y <  rect.y1) && (x == rect.x0 ||
         x ==  rect.x1 - 1 ||
         y == rect.y0 ||
         y ==  rect.y1 - 1);
      end
    endcase
  endfunction

  logic [23:0] pixel_color;

  always_comb begin
    pixel_color = DARKBG;
    foreach (Rectangles[i]) begin
      if (draw(x, y, Rectangles[i])) begin
        pixel_color = Rectangles[i].color;
      end
    end

    if (draw(x, y, '{BT1_X, BT1_Y, BT1_X + BT1_W, BT1_Y + BT1_H, 24'h000000, FILLED})) begin
      pixel_color = bi[0] ? BLUE : DARKBLUE;
    end
    if (draw(x, y, '{BT2_X, BT2_Y, BT2_X + BT2_W, BT2_Y + BT2_H, 24'h000000, FILLED})) begin
      pixel_color = bi[1] ? BLUE : BORDER;
    end
  end

  logic [7:0] out_r, out_g, out_b;
  logic [7:0] r, g, b;

  assign {r, g, b} = pixel_color;

  wire [$clog2(C_H) - 1:0] glyph_pixel_x_, glyph_pixel_y_;
  wire pixel_is_char = char_buf_q[glyph_pixel_y_][glyph_pixel_x_];

  always @(posedge clk) begin
    {vga_r, vga_g, vga_b} <= pixel_is_char ?
        (latency_area_d2 ? get_latency_color(measured_latency) :
         avg_area_d2 ? get_latency_color(latency_avg) : TEXTLIGHT) : {out_r, out_g, out_b};
  end

  pipe #(
      .STAGES(Latencies - 1),
      .M($clog2(C_H))
  ) gpx (
      .clk(clk),
      .rstn(rstn),
      .en(1),
      .x(glyph_pixel_x),
      .y(glyph_pixel_x_)
  );
  pipe #(
      .STAGES(Latencies - 1),
      .M($clog2(C_V))
  ) gpy (
      .clk(clk),
      .rstn(rstn),
      .en(1),
      .x(glyph_pixel_y),
      .y(glyph_pixel_y_)
  );
  pipe #(
      .STAGES(Latencies - 1),
      .M(8)
  ) r_ (
      .clk(clk),
      .rstn(rstn),
      .en(1),
      .x(r),
      .y(out_r)
  );
  pipe #(
      .STAGES(Latencies - 1),
      .M(8)
  ) g_ (
      .clk(clk),
      .rstn(rstn),
      .en(1),
      .x(g),
      .y(out_g)
  );
  pipe #(
      .STAGES(Latencies - 1),
      .M(8)
  ) b_ (
      .clk(clk),
      .rstn(rstn),
      .en(1),
      .x(b),
      .y(out_b)
  );

  pipe #(
      .STAGES(Latencies)
  ) hsync_ (
      .clk(clk),
      .rstn(rstn),
      .en(1),
      .x(hsync),
      .y(vga_hsync)
  );
  pipe #(
      .STAGES(Latencies)
  ) vsync_ (
      .clk(clk),
      .rstn(rstn),
      .en(1),
      .x(vsync),
      .y(vga_vsync)
  );
  pipe #(
      .STAGES(Latencies)
  ) active_ (
      .clk(clk),
      .rstn(rstn),
      .en(1),
      .x(hactive && vactive),
      .y(vga_active)
  );

endmodule
