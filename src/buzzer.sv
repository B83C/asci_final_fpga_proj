`timescale 1ns / 1ps

module buzzer (
    input  logic       clk,
    input  logic       rstn,
    input  logic       ms_tick,
    input  logic       play,
    input  logic [2:0] tune_sel,
    output logic       buzz
);

    // Note frequency divisors for 100MHz clock (50% duty PWM)
    // divisor = CLK_HZ / (2 * freq)
    localparam [18:0] DIV_REST = 0;
    localparam [18:0] DIV_C3  = 381679;
    localparam [18:0] DIV_E3  = 303030;
    localparam [18:0] DIV_A2  = 454545;
    localparam [18:0] DIV_C4  = 190839;
    localparam [18:0] DIV_E4  = 151515;
    localparam [18:0] DIV_F4  = 143266;
    localparam [18:0] DIV_G4  = 127551;
    localparam [18:0] DIV_A4  = 113636;
    localparam [18:0] DIV_C5  =  95602;
    localparam [18:0] DIV_E5  =  75873;
    localparam [18:0] DIV_G5  =  63776;
    localparam [18:0] DIV_C6  =  47732;

    function automatic void get_note(
        input  logic [2:0] tune,
        input  logic [3:0] idx,
        output logic [18:0] o_div,
        output logic [9:0]  o_dur
    );
        case ({tune, idx})
            {3'd0, 4'd0}: begin o_div = DIV_C5;   o_dur = 100; end
            {3'd0, 4'd1}: begin o_div = DIV_E5;   o_dur = 100; end
            {3'd0, 4'd2}: begin o_div = DIV_G5;   o_dur = 100; end
            {3'd0, 4'd3}: begin o_div = DIV_C6;   o_dur = 200; end
            {3'd0, 4'd4}: begin o_div = DIV_REST; o_dur =  50; end

            {3'd1, 4'd0}: begin o_div = DIV_G4;   o_dur = 150; end
            {3'd1, 4'd1}: begin o_div = DIV_C5;   o_dur = 150; end
            {3'd1, 4'd2}: begin o_div = DIV_E5;   o_dur = 300; end

            {3'd2, 4'd0}: begin o_div = DIV_C4;   o_dur = 200; end
            {3'd2, 4'd1}: begin o_div = DIV_E4;   o_dur = 200; end
            {3'd2, 4'd2}: begin o_div = DIV_G4;   o_dur = 400; end

            {3'd3, 4'd0}: begin o_div = DIV_C4;   o_dur = 250; end
            {3'd3, 4'd1}: begin o_div = DIV_A4;   o_dur = 250; end
            {3'd3, 4'd2}: begin o_div = DIV_F4;   o_dur = 250; end

            {3'd4, 4'd0}: begin o_div = DIV_A2;   o_dur = 300; end
            {3'd4, 4'd1}: begin o_div = DIV_C3;   o_dur = 300; end
            {3'd4, 4'd2}: begin o_div = DIV_E3;   o_dur = 300; end

            default:       begin o_div = DIV_REST; o_dur = 0;   end
        endcase
    endfunction

    logic        playing;
    logic [3:0]  note_idx;
    logic [9:0]  dur_timer;
    logic [18:0] cur_div;
    logic [9:0]  cur_dur;
    logic        play_prev;
    logic [18:0] freq_cnt;

    always_ff @(posedge clk, negedge rstn) begin
        if (!rstn) begin
            playing   <= 0;
            note_idx  <= 0;
            dur_timer <= 0;
            cur_div   <= 0;
            cur_dur   <= 0;
            play_prev <= 0;
            freq_cnt  <= 0;
            buzz      <= 0;
        end else begin
            play_prev <= play;

            if (play && !play_prev && !playing) begin
                playing  <= 1;
                note_idx <= 0;
                get_note(tune_sel, 0, cur_div, cur_dur);
                dur_timer <= 0;
                freq_cnt  <= 0;
                buzz      <= 0;
            end

            if (playing) begin
                if (ms_tick) begin
                    if (dur_timer >= cur_dur - 1) begin
                        note_idx <= note_idx + 1;
                        get_note(tune_sel, note_idx + 1, cur_div, cur_dur);
                        dur_timer <= 0;
                        freq_cnt  <= 0;
                        buzz      <= 0;
                        if (cur_dur == 0) playing <= 0;
                    end else begin
                        dur_timer <= dur_timer + 1;
                    end
                end

                if (cur_div != 0) begin
                    if (freq_cnt >= cur_div) begin
                        freq_cnt <= 0;
                        buzz <= ~buzz;
                    end else begin
                        freq_cnt <= freq_cnt + 1;
                    end
                end
            end else begin
                buzz <= 0;
            end
        end
    end

endmodule
