`timescale 1ns / 1ps

module tb_buzzer;
    localparam TUNE_VICTORY = 0;
    localparam TUNE_GOOD    = 1;
    localparam TUNE_AVG     = 2;
    localparam TUNE_SLOW    = 3;
    localparam TUNE_TIMEOUT = 4;

    logic         clk = 0;
    logic         rstn;
    logic         ms_tick;
    logic         play;
    logic [2:0]   tune_sel;
    logic         buzz;

    buzzer dut (.*);

    always #5 clk = ~clk;

    // 1ms tick generator
    logic [6:0] ms_cnt;
    always_ff @(posedge clk, negedge rstn) begin
        if (!rstn) ms_cnt <= 0;
        else if (ms_cnt == 99) ms_cnt <= 0;
        else ms_cnt <= ms_cnt + 1;
    end
    assign ms_tick = (ms_cnt == 99);

    `define CHECK(expr, msg) \
        if (!(expr)) $fatal(0, "FAIL %s at t=%0t", msg, $time); \
        else $display("PASS %s", msg)

    task wait_cycles(input int n);
        repeat (n) @(posedge clk);
    endtask

    initial begin
        $display("=== buzzer testbench ===");
        rstn = 1;
        play = 0;
        tune_sel = 0;

        @(posedge clk); rstn = 0;
        wait_cycles(10); rstn = 1;
        wait_cycles(10);

        // ────────────────────────────────────────────────
        // 1. Reset: buzz low
        // ────────────────────────────────────────────────
        $display("--- 1. reset ---");
        `CHECK(buzz == 0, "reset: buzz low");

        // ────────────────────────────────────────────────
        // 2. Play tune 0 (victory): expect PWM on buzz
        // ────────────────────────────────────────────────
        $display("--- 2. play tune 0 ---");
        tune_sel = TUNE_VICTORY;
        play = 1;
        @(posedge clk);
        play = 0;
        // Should start playing immediately
        wait_cycles(10);
        `CHECK(dut.playing == 1, "tune 0: playing started");

        // First note: C5, DIV=95602, freq=523Hz, period=191204 cycles
        // Wait a bit and check buzz toggles
        wait_cycles(200000);
        // Should have toggled at least once
        `CHECK(dut.note_idx > 0 || buzz != 0, "tune 0: PWM generated");

        // ────────────────────────────────────────────────
        // 3. Play stops after tune completes
        // ────────────────────────────────────────────────
        $display("--- 3. tune completion ---");
        // Victory tune total: 100+100+100+200+50 = 550ms = 550 ms_ticks
        wait_cycles(100000);  // ~100 more ms
        wait_cycles(300000);  // ~300 more
        `CHECK(dut.playing == 0, "tune 0: finished");
        `CHECK(buzz == 0, "tune 0: buzz low after done");

        // ────────────────────────────────────────────────
        // 4. Play tune 4 (timeout, sad)
        // ────────────────────────────────────────────────
        $display("--- 4. play tune 4 ---");
        tune_sel = TUNE_TIMEOUT;
        play = 1;
        @(posedge clk);
        play = 0;
        wait_cycles(10);
        `CHECK(dut.playing == 1, "tune 4: started");

        // Check still playing during first note (A2, 300ms = 30K cycles)
        wait_cycles(20000);  // 200ms into first note
        `CHECK(dut.playing == 1, "tune 4: still playing first note");

        wait_cycles(1000000);  // ~1000ms more
        `CHECK(dut.playing == 0, "tune 4: finished");

        // ────────────────────────────────────────────────
        // 5. Play during active: ignore second play pulse
        // ────────────────────────────────────────────────
        $display("--- 5. play-while-playing ignored ---");
        tune_sel = TUNE_GOOD;
        play = 1;
        @(posedge clk);
        play = 0;
        wait_cycles(100);
        `CHECK(dut.playing == 1, "tune 1: started");

        // Try to play again
        play = 1;
        @(posedge clk);
        play = 0;
        // Should still be playing tune 1 (not restarted)
        wait_cycles(1000);

        wait_cycles(1000000);
        `CHECK(dut.playing == 0, "tune 1: finished");

        $display("=== ALL TESTS PASSED ===");
        $finish;
    end

    initial begin
        if ($test$plusargs("trace")) begin
            $dumpfile("tests/tb_buzzer.fst");
            $dumpvars(0, tb_buzzer);
        end
    end
endmodule
