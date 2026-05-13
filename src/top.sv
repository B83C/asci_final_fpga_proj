`timescale 1ns / 1ps

typedef enum {
  IDLE,
  INIT,
  TRIGGERED,
  MEASURING,
  MEASURED
} state_t;

module top_vga #(
    parameter unsigned CLK_HZ = 75000000
) (
    input clk,
    input rstn,

    input [1:0] buttons,

    output reg [1:0] leds,

    vga_if vga
);
  wire [1:0] bi;
  wire [1:0] button_interrupt;
  wire interrupted = |button_interrupt;
  generate
    genvar j;
    for (j = 0; j < 2; j++) begin : gen_debouncer
      debouncer #(
      // .CYCLES(2)
      ) db (
          .rstn(rstn),
          .clk(clk),
          .raw_input(buttons[j]),
          .triggered(button_interrupt[j]),
          .debounced_output(bi[j])
      );
      // assign bi[j] = ~buttons[j];  // TODO: temporary test
    end
  endgenerate

  state_t state = IDLE;

  // Should last only 1 pulse
  wire reset_counter = (state == MEASURED) && (bi[0] & bi[1] == 1);

  wire ms_passed;
  generic_counter #(
      .MAX(CLK_HZ / 1000)
  ) ms_generator (
      .clk(clk),
      .rstn(rstn && !reset_counter),
      .en(state == MEASURING || state == TRIGGERED),
      .ending(ms_passed),
      .x()
  );


  // Maximum of 10s
  wire ms_done;
  wire [$clog2(30000) - 1:0] ms_elapsed;

  generic_counter #(
      .MAX(30000),
      .ONESHOT(1)
  ) ms_counter (
      .clk(clk),
      .rstn(rstn && !reset_counter),
      .en(ms_passed && state == MEASURING),
      .ending(ms_done),
      .x(ms_elapsed)
  );

  // In milliseconds
  logic [$clog2(10000) - 1:0] randomised_delay;
  lfsr #(
      .MAX(4),
      .MIN(1)
  ) rand_gen (
      .clk (clk),
      .rstn(rstn),
      .en  (state == IDLE && bi[0]),
      .out (randomised_delay)
  );

  wire countdown_done;

  generic_countdown_counter #(
      .MAX(10000)
  ) ms_countdown (
      .clk(clk),
      .rstn(rstn && !reset_counter),
      .load_val(randomised_delay),
      .load(state == INIT),
      .en(ms_passed && state == TRIGGERED),
      .done(countdown_done)
  );

  // wire measure_now = randomised_delay == ms_elapsed;

  logic [$clog2(30000) - 1:0] measured_latency;

  always @(posedge clk) begin
    unique case (state)
      IDLE: begin
        if (bi[0]) begin
          state <= INIT;
        end
      end
      INIT: begin
        state <= TRIGGERED;
      end
      TRIGGERED: begin
        if (countdown_done && ms_passed) begin
          state <= MEASURING;
        end
      end
      MEASURING: begin
        if (bi[1] || ms_done) begin
          state <= MEASURED;
          measured_latency <= ms_elapsed;
        end
      end
      MEASURED: begin
        if (bi[1] & bi[0]) begin
          state <= IDLE;
        end
      end
    endcase
    for (int i = 0; i < 2; i++) begin
      leds[i] <= bi[i];
    end
  end

  wire hsync, hblank, vsync, vblank, active, fsync;

  integer count;
  parameter unsigned H = 1280;
  parameter unsigned V = 720;
  parameter unsigned N_H = $clog2(H);
  parameter unsigned N_V = $clog2(V);

  wire [N_H - 1:0] x;
  wire [N_V - 1:0] y;

  logic [1:0] sw;

  wire xc_end, yc_end, hactive, vactive;

  parameter unsigned C_H = 8;
  parameter unsigned C_V = 8;
  parameter unsigned SCALE_X = 2;
  parameter unsigned SCALE_Y = 2;

  parameter unsigned HCC = H / (C_H * SCALE_X);
  parameter unsigned VCC = V / (C_V * SCALE_Y);
  parameter unsigned X_BOUND = HCC * (C_H * SCALE_X) + 1;
  parameter unsigned Y_BOUND = VCC * (C_V * SCALE_Y) + 1;

  timing_counter #(
      .DISP(1280),
      .FP(110),
      .SW(40),
      .BP(220),
      .N(N_H)
  ) xc (
      .pixclk(clk),
      .rstn(rstn),
      .en(1),

      .sync(hsync),
      .x(x),
      .active(hactive),
      .ending(xc_end)
  );

  timing_counter #(
      .DISP(720),
      .FP(5),
      .SW(5),
      .BP(20),
      .N(N_V)
  ) yc (
      .pixclk(clk),
      .rstn(rstn),
      .en(xc_end),

      .sync(vsync),
      .x(y),
      .active(vactive),
      .ending(yc_end)
  );

  assign active = hactive && vactive;


  logic [7:0] r, g, b;

  logic [$clog2(C_H) - 1:0] x_cntr = 0;
  logic [$clog2(C_V) - 1:0] y_cntr = 0;
  logic [$clog2(HCC) - 1:0] c_x = 0;
  logic [$clog2(VCC) - 1:0] c_y = 0;

  logic [$clog2(SCALE_X) - 1:0] scale_cntr_x = 0;
  logic [$clog2(SCALE_Y) - 1:0] scale_cntr_y = 0;

  logic [7:0] text_buffer[VCC][HCC];
  logic [7:0] read_ascii;

  wire rstn_x, rstn_y;
  logic [$clog2(C_H) - 1:0] glyph_pixel_x;
  logic [$clog2(C_V) - 1:0] glyph_pixel_y;
  logic [$clog2(X_BOUND) - 1:0] ascii_x;
  logic [$clog2(Y_BOUND) - 1:0] ascii_y;
  wire sx_ending, cx_ending;
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
  wire sy_ending, cy_ending;
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

  // 1 Latency
  always @(posedge clk) begin
    read_ascii <= text_buffer[ascii_y][ascii_x];
  end

  function automatic int D(int x, int y, logic [7:0] Str[]);
    foreach (Str[i]) begin
      text_buffer[y][x+i] = Str[i];
    end
    D = x + Str.size();
  endfunction


  typedef enum {
    CENTER,
    LEFT,
    RIGHT
  } anchor_t;

  typedef struct {
    int x;
    int y;
  } pos_t;

  function automatic pos_t DS(int x, int y, string Str, anchor_t anchor = LEFT);
    int shift = 0;
    case (anchor)
      CENTER: shift = -Str.len() / 2;
      RIGHT:  shift = -Str.len();
    endcase
    foreach (Str[i]) begin
      text_buffer[y][x+i+shift] = unsigned'(Str[i]);
    end
    DS.x = x + Str.len() + shift;
    DS.y = y;
    // D(x + shift, y, {<<8{Str}});
    // D(x + shift, y, string_t'(Str));
  endfunction

  localparam unsigned Mid = HCC / 2;
  localparam unsigned Q1 = HCC / 4;
  localparam unsigned Q2 = 3 * HCC / 4;

  localparam unsigned Midy = VCC / 2;
  localparam unsigned Q1y = VCC / 4;
  localparam unsigned Q2y = 3 * VCC / 4;

  localparam unsigned Gap = 6;
  localparam unsigned TextHeight = C_V * SCALE_Y;

  // pos_t p[];
  pos_t p0, p1, p2, p3, p4, p5;
  initial begin
    p0 = DS(Mid, Q1y - 2, "Human glitch tester", CENTER);
    p1 = DS(Mid, p0.y + 1, "Current state", RIGHT);
    p2 = DS(Mid, p1.y + 1, "Measured Latencies:", RIGHT);
    p3 = DS(Mid, p2.y + 1, "Press Now!", CENTER);

    p4 = DS(Q2, Q2y, "RREActtTT", CENTER);
    p5 = DS(Q1, Q2y, "Start Test", CENTER);
  end

  logic [7:0] buffer[10];
  always_comb begin
    case (state)
      IDLE: buffer = {>>8{"      IDLE"}};
      INIT: buffer = {>>8{"      INIT"}};
      TRIGGERED: buffer = {>>8{"      TRIG"}};
      MEASURING: buffer = {>>8{" MEASURING"}};
      MEASURED: buffer = {>>8{"  MEASURED"}};
    endcase
  end

  logic [7:0] measured_latency_bcd[4];

  assign measured_latency_bcd = {
    "0" + 8'(measured_latency[14:12]),
    "0" + 8'(measured_latency[11:8]),
    "0" + 8'(measured_latency[7:4]),
    "0" + 8'(measured_latency[3:0])
  };

  always @(posedge clk) begin
    void'(D(p1.x, p1.y, buffer));
    void'(D(p2.x, p2.y, measured_latency_bcd));
  end

  // R, G, B
  localparam logic [7:0][2:0] TextFG = 24'hFF9800;

  // ASCII (8th bit maps to invert highlight)
  wire [C_V - 1 : 0][C_H - 1 : 0] char_buf;

  // 1 Latency
  ram #(
      .WIDTH(C_H * C_V),
      .DEPTH(128),
      .BINARY_FILE("ascii.rom")
  ) ascii (
      .clk (clk),
      .addr(read_ascii[6:0]),
      .data(char_buf)
  );


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

  localparam unsigned MidP = H / 2;
  localparam unsigned Q1P = H / 4;
  localparam unsigned Q2P = 3 * H / 4;

  localparam unsigned MidyP = V / 2;
  localparam unsigned Q1yP = V / 4;
  localparam unsigned Q2yP = 3 * V / 4;

  function automatic rect_t M(rect_t r, logic [10:0] q);
    M = r;
    M.x0 = r.x0 + q;
    M.y0 = r.y0 + q;
    M.x1 = r.x1 - q;
    M.y1 = r.y1 - q;
  endfunction

  localparam rect_t Rectangles[0:3] = '{
      M('{0, 0, H, MidyP, 24'h000000, HOLLOW}, 10),
      M('{0, 0, H, MidyP, 24'h74c3e6, FILLED}, 15),
      '{0, MidyP, MidP, V, 24'h00FF00, FILLED},
      M('{(MidP) + 2, (MidyP) + 2, H - 2, V - 2, 24'h000000, HOLLOW}, 10)
  // '{(H / 2) + 2, (V / 2) + 2, H - 2, V - 2, bi[0] ? 24'hFF0000 : 24'hFF0000, FILLED}
  };  // parameter Rectangles = {

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
    pixel_color = 24'hFFFFFF;

    foreach (Rectangles[i]) begin
      static logic condition = 0;
      if (draw(x, y, Rectangles[i])) begin
        pixel_color = Rectangles[i].color;
      end
    end
  end

  always @(posedge clk) begin
    rect_t test[] = '{
        '{MidP + 6, MidyP + 6, H - 6, V - 6, bi[0] ? 24'h7bb5e3 : 24'h0690FF, FILLED},
        '{6, MidyP + 6, MidP - 6, V - 6, bi[1] ? 24'h7bb5e3 : 24'h0690FF, FILLED}
    };
    {r, g, b} <= pixel_color;
    foreach (test[i]) begin
      if (draw(x, y, test[i])) begin
        {r, g, b} <= test[i].color;
      end
    end
    // if (draw(x, y, t)) begin
    //   {r, g, b} <= t.color;
    // end else begin
    //   {r, g, b} <= pixel_color;
    // end
  end

  logic [7:0] out_r, out_g, out_b;

  logic [$clog2(C_H) - 1:0] glyph_pixel_x_, glyph_pixel_y_;

  wire pixel_is_char = char_buf[glyph_pixel_y_][glyph_pixel_x_];
  assign {vga.r, vga.g, vga.b} = pixel_is_char ? TextFG : {out_r, out_g, out_b};

  localparam int Latencies = 2;
  pipe #(
      .STAGES(Latencies),
      .M($clog2(C_H))
  ) gpx (
      .clk(clk),
      .rstn(rstn),
      .en(1),
      .x(glyph_pixel_x),
      .y(glyph_pixel_x_)
  );
  pipe #(
      .STAGES(Latencies),
      .M($clog2(C_V))
  ) gpy (
      .clk(clk),
      .rstn(rstn),
      .en(1),
      .x(glyph_pixel_y),
      .y(glyph_pixel_y_)
  );

  pipe #(
      .STAGES(Latencies),
      .M(8)
  ) r_ (
      .clk(clk),
      .rstn(rstn),
      .en(1),
      .x(r),
      .y(out_r)
  );
  pipe #(
      .STAGES(Latencies),
      .M(8)
  ) g_ (
      .clk(clk),
      .rstn(rstn),
      .en(1),
      .x(g),
      .y(out_g)
  );
  pipe #(
      .STAGES(Latencies),
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
      .y(vga.hsync)
  );
  pipe #(
      .STAGES(Latencies)
  ) vsync_ (
      .clk(clk),
      .rstn(rstn),
      .en(1),
      .x(vsync),
      .y(vga.vsync)
  );
  pipe #(
      .STAGES(Latencies)
  ) hblank_ (
      .clk(clk),
      .rstn(rstn),
      .en(1),
      .x(hblank),
      .y(vga.hblank)
  );
  pipe #(
      .STAGES(Latencies)
  ) vblank_ (
      .clk(clk),
      .rstn(rstn),
      .en(1),
      .x(vblank),
      .y(vga.vblank)
  );
  pipe #(
      .STAGES(Latencies)
  ) fsync_ (
      .clk(clk),
      .rstn(rstn),
      .en(1),
      .x(fsync),
      .y(vga.fsync)
  );
  pipe #(
      .STAGES(Latencies)
  ) active_ (
      .clk(clk),
      .rstn(rstn),
      .en(1),
      .x(active),
      .y(vga.active)
  );
endmodule

module top_dvi (
    input pixclk,
    input serdes_clk,
    input rstn,
    vga_if vga,
    tmds_bus_if tmds_output
);
  wire [1:0] ctl[3];
  wire [7:0] pdata[3];
  wire [9:0] tmds_data[3];

  wire active = vga.active;

  assign pdata[2] = vga.r;
  assign pdata[1] = vga.g;
  assign pdata[0] = vga.b;

  assign ctl[0]   = {vga.vsync, vga.hsync};
  assign ctl[1]   = 2'b00;
  assign ctl[2]   = 2'b00;

  generate
    genvar i;

    for (i = 0; i < 3; i = i + 1) begin : gen_tmds

      wire [9:0] tmds_p;
      tmds_encoder encoder (
          .clk(pixclk),
          .video_data(pdata[i]),
          .control_data(ctl[i]),
          .video_data_enable(active),
          .TMDS(tmds_p)
      );

      tmds_serdes serdes (
          .pixclk(pixclk),
          .serdes_clk(serdes_clk),
          .rstn(rstn),
          .tmds_p(tmds_p),
          .tmds_tx_serial_n(tmds_output.tmds_tx_data_n[i]),
          .tmds_tx_serial_p(tmds_output.tmds_tx_data_p[i])
      );

    end
  endgenerate

  tmds_serdes serdes (
      .pixclk(pixclk),
      .serdes_clk(serdes_clk),
      .rstn(rstn),
      .tmds_p(10'b1111100000),
      .tmds_tx_serial_n(tmds_output.tmds_tx_clk_n),
      .tmds_tx_serial_p(tmds_output.tmds_tx_clk_p)
  );
endmodule

module top (
    input clk50,
    input rstn_,

    input [1:0] buttons,

    output reg [1:0] leds,

    output logic tmds_tx_clk_n,
    output logic tmds_tx_clk_p,

    output logic [2:0] tmds_tx_data_p,
    output logic [2:0] tmds_tx_data_n
);

  wire rstn;
  reg [7:0] rstncnt;
  wire pixclk, serdes_clk;
  wire locked;
  always @(posedge pixclk or negedge locked) begin
    if (~locked) begin
      rstncnt <= 0;
    end else begin
      if (rstncnt != 8'hff) begin
        rstncnt <= rstncnt + 1;
      end
    end
  end

  assign rstn = (rstncnt == 8'hff) ? 1'b0 : 1'b1;

  clk_wiz_0 cl_inst (
      // Clock out ports
      .clk_375(serdes_clk),
      .clk_75 (pixclk),
      // Status and control signals
      .reset  (0),
      .locked (locked),
      // Clock in ports
      .clk_in1(clk50)
  );

  vga_if vga_bus ();
  tmds_bus_if tmds_bus ();

  top_dvi dvi (
      .pixclk(pixclk),
      .serdes_clk(serdes_clk),
      .rstn(rstn),
      .vga(vga_bus.consumer),
      .tmds_output(tmds_bus)
  );

  top_vga vga_ (
      .clk(pixclk),
      .rstn(rstn),
      .leds(leds),
      .buttons(buttons),
      .vga(vga_bus.producer)
  );

  assign tmds_tx_clk_n  = tmds_bus.tmds_tx_clk_n;
  assign tmds_tx_clk_p  = tmds_bus.tmds_tx_clk_p;

  assign tmds_tx_data_p = tmds_bus.tmds_tx_data_p;
  assign tmds_tx_data_n = tmds_bus.tmds_tx_data_n;

endmodule

module top_simulation (
    input clk,
    input rstn,

    input [1:0] buttons,

    output reg [1:0] leds,

    output hsync,
    output hblank,
    output vsync,
    output vblank,
    output active,
    output fsync,

    output logic [7:0] r,
    output logic [7:0] g,
    output logic [7:0] b
);
  vga_if vga_bus ();

  top_vga #(
  // .CLK_HZ(30)
  ) vga_ (
      .clk(clk),
      .rstn(rstn),
      .leds(leds),
      .buttons(buttons),
      .vga(vga_bus.producer)
  );

  assign hsync = vga_bus.hsync;
  assign hblank = vga_bus.hblank;
  assign vsync = vga_bus.vsync;
  assign vblank = vga_bus.vblank;
  assign active = vga_bus.active;
  assign fsync = vga_bus.fsync;

  assign r = vga_bus.r;
  assign g = vga_bus.g;
  assign b = vga_bus.b;


endmodule
