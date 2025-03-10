// Clock Divider
module clock_divider(
    input clk,         // Fast clock (e.g., 100 MHz)
    input reset,
    output reg clk_1hz
);
    reg [25:0] counter;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 0;
            clk_1hz <= 0;
        end else if (counter == 26'd49_999_999) begin // Fixed to 26-bit
            counter <= 0;
            clk_1hz <= ~clk_1hz;
        end else begin
            counter <= counter + 1;
        end
    end
endmodule

// Debouncer (reintroduced)
module debounce (
    input wire clk,       // Fast clock
    input wire reset,
    input wire button_in,
    output reg button_out
);
    reg [19:0] count;
    reg button_prev;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            count <= 20'b0;
            button_prev <= 1'b0;
            button_out <= 1'b0;
        end else begin
            button_prev <= button_in;
            if (button_prev != button_in) begin
                count <= 20'b0;
            end else if (count == 20'hFFFFF) begin
                button_out <= button_prev;
            end else begin
                count <= count + 1;
            end
        end
    end
endmodule

// Seven Segment Display (unchanged)
module seven_segment_display(
    input [3:0] digit,
    output reg [6:0] seg
);
    always @(*) begin
        case (digit)
            4'd0: seg = 7'b1000000; // 0
            4'd1: seg = 7'b1111001; // 1
            4'd2: seg = 7'b0100100; // 2
            4'd3: seg = 7'b0110000; // 3
            4'd4: seg = 7'b0011001; // 4
            4'd5: seg = 7'b0010010; // 5
            4'd6: seg = 7'b0000010; // 6
            4'd7: seg = 7'b1111000; // 7
            4'd8: seg = 7'b0000000; // 8
            4'd9: seg = 7'b0010000; // 9
            default: seg = 7'b1111111; // Blank
        endcase
    end
endmodule

// Stopwatch
module stopwatch(
    input clk,         // Fast clock (e.g., 100 MHz)
    input btnC,        // Reset
    input btnU,        // Start/Stop
    output reg [3:0] an,
    output reg [6:0] seg
);
    reg [5:0] sec_counter;
    reg [5:0] min_counter;
    reg running;
    wire clk_1hz;
    wire debounced_btnU;
    reg btnU_prev;

    clock_divider clk1 (.clk(clk), .reset(btnC), .clk_1hz(clk_1hz));
    debounce d0 (.clk(clk), .reset(btnC), .button_in(btnU), .button_out(debounced_btnU));

    // Fast button toggle
    always @(posedge clk or posedge btnC) begin
        if (btnC) begin
            running <= 0;
            btnU_prev <= 0;
        end else begin
            btnU_prev <= debounced_btnU;
            if (debounced_btnU && !btnU_prev) begin
                running <= ~running;
            end
        end
    end

    // Slow counter
    always @(posedge clk_1hz or posedge btnC) begin
        if (btnC) begin
            sec_counter <= 6'd0;
            min_counter <= 6'd0;
        end else if (running) begin
            if (sec_counter == 6'd59) begin
                sec_counter <= 6'd0;
                if (min_counter == 6'd59) begin
                    min_counter <= 6'd0;
                end else begin
                    min_counter <= min_counter + 1;
                end
            end else begin
                sec_counter <= sec_counter + 1;
            end
        end
    end

    // Display logic
    wire [3:0] min_tens = min_counter / 10;
    wire [3:0] min_ones = min_counter % 10;
    wire [3:0] sec_tens = sec_counter / 10;
    wire [3:0] sec_ones = sec_counter % 10;

    wire [6:0] seg0, seg1, seg2, seg3;
    seven_segment_display seg0_disp(min_tens, seg3);
    seven_segment_display seg1_disp(min_ones, seg2);
    seven_segment_display seg2_disp(sec_tens, seg1);
    seven_segment_display seg3_disp(sec_ones, seg0);

    // Multiplexing clock (~1 kHz)
    reg [16:0] mux_clk_div;
    reg mux_clk;
    always @(posedge clk) begin
        if (mux_clk_div == 17'd99_999) begin
            mux_clk_div <= 0;
            mux_clk <= ~mux_clk;
        end else begin
            mux_clk_div <= mux_clk_div + 1;
        end
    end

    reg [1:0] mux_count = 0;
    always @(posedge mux_clk) begin
        case (mux_count)
            2'd0: begin seg <= seg0; an <= 4'b1110; end // Active-low anodes
            2'd1: begin seg <= seg1; an <= 4'b1101; end
            2'd2: begin seg <= seg2; an <= 4'b1011; end
            2'd3: begin seg <= seg3; an <= 4'b0111; end
        endcase
        mux_count <= mux_count + 1;
    end
endmodule


//module tb_stopwatch;
//    reg clk;
//    reg btnC;
//    reg btnU;
//    wire [3:0] an;
//    wire [6:0] seg;

//    stopwatch uut (
//        .clk(clk),
//        .btnC(btnC),
//        .btnU(btnU),
//        .an(an),
//        .seg(seg)
//    );

//    // Clock generation (100 MHz = 10 ns period)
//    initial begin
//        clk = 0;
//        forever #5 clk = ~clk;
//    end

//    // Stimulus
//    initial begin
//        btnC = 1; btnU = 0;
//        #20 btnC = 0;          // Release reset
//        #100 btnU = 1;         // Press start
//                 // Release start
//        #1_000_000_000 btnU = 1; // Press stop after ~10 seconds
//        #100 btnU = 0;
//        #1_000_000_000 $finish;  // Run for another 10 seconds
//    end

//    initial begin
//        $monitor("Time=%0t, sec=%d, min=%d, running=%b, an=%b, seg=%b",
//                 $time, uut.sec_counter, uut.min_counter, uut.running, an, seg);
//    end
//endmodule