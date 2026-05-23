`timescale 1ns / 1ps
`include "defs.svh"

module tb_state;
  logic         clk;
  logic         ready;
  logic         halt;
  logic   [1:0] bi;
  state_t       sys_state;

  state dut (.*);

  always #5 clk = ~clk;

  // ─── check helper ─────────────────────────────────────
  `define CHECK(expr, msg) \
    if (!(expr)) $fatal(0, "FAIL %s", msg); \
    else $display("PASS %s", msg)

  initial begin
    $display("=== state testbench ===");
    clk = 0;
    ready = 0;
    halt = 0;
    bi = 0;

    repeat (2) @(posedge clk);

    // ────────────────────────────────────────────────────
    // 1. normal cycle: pulse ready for each transition.
    //    Every transition sets hold=1, so the next
    //    transition needs ready 1→0→1 (handshake).
    //    The first IDLE→INIT is special because hold=0.
    // ────────────────────────────────────────────────────
    $display("--- normal cycle ---");

    ready = 1;  @(posedge clk);  // IDLE -> INIT (hold=0, fires immediately)
    `CHECK(sys_state == INIT, "IDLE -> INIT after ready assertion");
    ready = 0;  @(posedge clk);  // INIT: hold clears   (ready=0, hold=1)
    @(posedge clk);             // INIT -> TRIGGERED    (hold=0)
    `CHECK(sys_state == TRIGGERED, "INIT -> TRIGGERED");

    ready = 1;  @(posedge clk);  // first pulse blocked (hold=1)
    ready = 0;  @(posedge clk);  // hold clears
    ready = 1;  @(posedge clk);  // TRIGGERED -> MEASURING (hold=0)
    `CHECK(sys_state == MEASURING, "TRIGGERED -> MEASURING");

    // hold=1 from transition, clear it
    ready = 0;  @(posedge clk);  // hold clears   (hold=1 → hold<=0)
    ready = 1;  @(posedge clk);  // MEASURING -> MEASURED (hold=0)
    `CHECK(sys_state == MEASURED, "MEASURING -> MEASURED");

    // hold=1 from transition, clear it
    ready = 0;  @(posedge clk);  // hold clears
    ready = 1;  @(posedge clk);  // MEASURED -> IDLE (hold=0)
    `CHECK(sys_state == IDLE, "MEASURED -> IDLE");
    ready = 0;  @(posedge clk);  // hold clears

    // ────────────────────────────────────────────────────
    // 2. long press: hold ready high for many cycles
    //    INIT now waits for ready deassert; once in
    //    TRIGGERED+ handshake prevents spurious transitions
    // ────────────────────────────────────────────────────
    $display("--- long press ---");

    ready = 1;  @(posedge clk);  // IDLE -> INIT
    `CHECK(sys_state == INIT, "long-press: IDLE -> INIT");

    // hold ready high — INIT must NOT transition to TRIGGERED
    repeat (10) @(posedge clk);
    `CHECK(sys_state == INIT, "long-press: stays in INIT while ready high");

    // release to allow INIT -> TRIGGERED
    ready = 0;  @(posedge clk);  // hold clears
    @(posedge clk);             // INIT -> TRIGGERED (hold=1)

    // hold ready high again — TRIGGERED handshake prevents spurious transition
    ready = 1;
    repeat (10) @(posedge clk);
    `CHECK(sys_state == TRIGGERED, "long-press: no spurious transition in TRIGGERED");

    ready = 0;  @(posedge clk);  // hold clears
    `CHECK(sys_state == TRIGGERED, "long-press: still TRIGGERED after ready deassert");

    // TRIGGERED -> MEASURING (hold is 0, fires immediately)
    ready = 1;  @(posedge clk);
    `CHECK(sys_state == MEASURING, "long-press: TRIGGERED -> MEASURING");
    ready = 0;  @(posedge clk);  // hold clears

    // MEASURING -> MEASURED (hold is 0, fires immediately)
    ready = 1;  @(posedge clk);
    `CHECK(sys_state == MEASURED, "long-press: MEASURING -> MEASURED");
    repeat (10) @(posedge clk);
    `CHECK(sys_state == MEASURED, "long-press: no spurious transition from MEASURED");
    ready = 0;  @(posedge clk);  // hold clears

    // MEASURED -> IDLE (hold is 0, fires immediately)
    ready = 1;  @(posedge clk);
    `CHECK(sys_state == IDLE, "long-press: MEASURED -> IDLE after deassert");
    ready = 0;  @(posedge clk);  // hold clears

    // ────────────────────────────────────────────────────
    // 3. rapid pulses
    // ────────────────────────────────────────────────────
    $display("--- rapid pulses ---");

    ready = 1;  @(posedge clk);  // IDLE -> INIT
    ready = 0;  @(posedge clk);  // hold clears
    @(posedge clk);             // INIT -> TRIGGERED
    `CHECK(sys_state == TRIGGERED, "rapid: IDLE -> TRIGGERED");

    ready = 1;  @(posedge clk);  // blocked (hold=1)
    ready = 0;  @(posedge clk);  // hold clears
    ready = 1;  @(posedge clk);  // TRIGGERED -> MEASURING
    ready = 0;  @(posedge clk);  // hold clears
    ready = 1;  @(posedge clk);  // MEASURING -> MEASURED
    ready = 0;  @(posedge clk);  // hold clears
    ready = 1;  @(posedge clk);  // MEASURED -> IDLE
    `CHECK(sys_state == IDLE, "rapid: full cycle back to IDLE");
    ready = 0;  @(posedge clk);  // clear hold

    // ────────────────────────────────────────────────────
    // 4. halt: assert halt during TRIGGERED -> SPAM
    // ────────────────────────────────────────────────────
    $display("--- halt / SPAM ---");

    // get to TRIGGERED
    ready = 1;  @(posedge clk);  // IDLE -> INIT
    ready = 0;  @(posedge clk);  // hold clears
    @(posedge clk);             // INIT -> TRIGGERED
    `CHECK(sys_state == TRIGGERED, "halt: in TRIGGERED");

    // assert halt -> should go to SPAM
    halt = 1;  @(posedge clk);
    `CHECK(sys_state == SPAM, "halt: TRIGGERED -> SPAM via halt");

    // halt stays high, but already in SPAM -> should stay SPAM
    @(posedge clk);
    `CHECK(sys_state == SPAM, "halt: stays in SPAM while halt is high");

    // deassert halt, SPAM stays
    halt = 0;  @(posedge clk);
    `CHECK(sys_state == SPAM, "halt: stays in SPAM after halt deasserted");

    // assert ready to leave SPAM -> IDLE (handshake)
    ready = 1;  @(posedge clk);
    `CHECK(sys_state == IDLE, "halt: SPAM -> IDLE via ready");
    ready = 0;  @(posedge clk);  // clear hold

    // ────────────────────────────────────────────────────
    // 5. halt ignored outside TRIGGERED
    // ────────────────────────────────────────────────────
    $display("--- halt ignored in IDLE ---");

    `CHECK(sys_state == IDLE, "halt-ignore: in IDLE");
    halt = 1;  @(posedge clk);
    `CHECK(sys_state == IDLE, "halt-ignore: halt ignored in IDLE");
    halt = 0;

    $display("=== ALL TESTS PASSED ===");
    $finish;
  end

  initial begin
    if ($test$plusargs("trace")) begin
      $dumpfile("tests/tb_state.fst");
      $dumpvars(0, tb_state);
    end
  end
endmodule
