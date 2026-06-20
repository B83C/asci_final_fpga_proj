`timescale 1ns / 1ps

module tb_top_basys3;
  localparam IDLE = 0;
  localparam INIT = 1;
  localparam TRIGGERED = 2;
  localparam MEASURING = 3;
  localparam MEASURED = 4;
  localparam SPAM = 5;

  logic clk = 0;
  logic rstn;
  logic btn_center, btn_up, btn_down, btn_left, btn_right;
  logic [ 3:0] an;
  logic [ 7:0] seg;
  logic [15:0] led;
  logic        buzz;

  top_basys3 #(
      .SIM_MODE(1)
  ) dut (
      .clk(clk),
      .rstn(rstn),
      .btn_center(btn_center),
      .btn_up(btn_up),
      .btn_down(btn_down),
      .btn_left(btn_left),
      .btn_right(btn_right),
      .an(an),
      .seg(seg),
      .led(led),
      .buzz(buzz)
  );

  always #5 clk = ~clk;

  `define CHECK(expr, msg) \
        if (!(expr)) $fatal(0, "FAIL %s at t=%0t", msg, $time); \
        else $display("PASS %s", msg)

  task wait_cycles(input int n);
    repeat (n) @(posedge clk);
  endtask

  task press_btn(ref logic btn);
    btn = 1;
    wait_cycles(300);  // > DB_MAX = 200 (counter-based debounce)
    btn = 0;
    wait_cycles(300);
  endtask

  task press_center;
    press_btn(btn_center);
  endtask

  task wait_for_state(input int target, input int timeout_ms);
    for (int i = 0; i < timeout_ms; i++) begin
      if (dut.sys_state == target) return;
      wait_cycles(100);  // poll every ~1 SIM ms
    end
    if (dut.sys_state != target) begin
      $display("DEBUG: state=%0d (want %0d) timed_out=%0d", dut.sys_state, target, dut.timed_out);
    end
  endtask

  initial begin
    $display("=== top_basys3 testbench (SIM_MODE=1) ===");
    rstn = 1;
    btn_center = 0;
    btn_up = 0;
    btn_down = 0;
    btn_left = 0;
    btn_right = 0;

    @(posedge clk);
    rstn = 0;
    wait_cycles(10);
    rstn = 1;
    wait_cycles(10);

    // ────────────────────────────────────────────────
    // 1. IDLE state: LED off, display active
    // ────────────────────────────────────────────────
    $display("--- 1. IDLE ---");
    `CHECK(dut.sys_state == IDLE, "starts in IDLE");
    `CHECK(led[0] == 0, "status LED off");
    `CHECK(an != 4'b1111, "display active (at least one anode on)");

    // ────────────────────────────────────────────────
    // 2. Press center → INIT (auto through to TRIGGERED)
    // ────────────────────────────────────────────────
    $display("--- 2. press center → INIT → TRIGGERED ---");
    press_center;
    wait_cycles(10);
    // Should be in INIT or TRIGGERED (INIT is 2 cycles, might pass quickly)
    `CHECK(dut.sys_state == TRIGGERED || dut.sys_state == INIT,
           "center triggered state transition");

    // ────────────────────────────────────────────────
    // 3. Wait for TRIGGERED → MEASURING (countdown finishes)
    // ────────────────────────────────────────────────
    $display("--- 3. TRIGGERED → MEASURING ---");
    wait_for_state(MEASURING, 10000);  // up to 10k polls = ~1M cycles
    `CHECK(dut.sys_state == MEASURING, "countdown done → MEASURING");
    // Wait for at least 2 ms ticks so latency > 0
    wait_cycles(250);

    // ────────────────────────────────────────────────
    // 4. Press center in MEASURING → MEASURED
    // ────────────────────────────────────────────────
    $display("--- 4. MEASURED ---");
    press_center;
    wait_cycles(10);
    `CHECK(dut.sys_state == MEASURED, "center → MEASURED");
    `CHECK(led[0] == 1, "status LED on");

    // ────────────────────────────────────────────────
    // 5. History and navigation
    // ────────────────────────────────────────────────
    $display("--- 5. history ---");
    `CHECK(dut.measured_latency > 0, "latency captured");
    press_btn(btn_up);
    `CHECK(dut.sys_state == MEASURED, "up: stays MEASURED");
    press_btn(btn_down);
    `CHECK(dut.sys_state == MEASURED, "down: stays MEASURED");

    // ────────────────────────────────────────────────
    // 6. Left button in MEASURED → back to IDLE
    // ────────────────────────────────────────────────
    $display("--- 6. back to IDLE ---");
    press_btn(btn_left);
    wait_cycles(10);
    `CHECK(dut.sys_state == IDLE, "MEASURED → IDLE");

    // ────────────────────────────────────────────────
    // 7. Timeout test
    // ────────────────────────────────────────────────
    $display("--- 7. timeout ---");
    press_center;
    wait_for_state(MEASURING, 10000);
    `CHECK(dut.sys_state == MEASURING, "timeout: in MEASURING");
    // TIMEOUT_MS = 15 in SIM_MODE → 1500 cycles
    wait_for_state(MEASURED, 200);
    `CHECK(dut.sys_state == MEASURED, "timeout: → MEASURED");
    `CHECK(dut.timed_out == 1, "timeout flag set");
    `CHECK(led[0] == 1, "status LED on after timeout");

    // ────────────────────────────────────────────────
    // 8. Memory check
    // ────────────────────────────────────────────────
    $display("--- 8. memory check ---");
    `CHECK(dut.hist_wr >= 2, "at least 2 history entries");

    $display("=== ALL TESTS PASSED ===");
    $finish;
  end

    initial begin
        if ($test$plusargs("trace")) begin
            $dumpfile("waveform.fst");
            $dumpvars(0, tb_top_basys3);
        end
    end
endmodule
