```verilog
module seqdet_moore(
    input   clk,
    input   rst,
    input   din,
    output  detected
);

    // State encoding for Moore machine
    // S0: Idle / Reset
    // S1: Detected '1'
    // S2: Detected '10'
    // S3: Detected '101'
    // S4: Detected '1011' (Output = 1)
    reg [2:0] state;

    localparam S0 = 3'd0;
    localparam S1 = 3'd1;
    localparam S2 = 3'd2;
    localparam S3 = 3'd3;
    localparam S4 = 3'd4;

    always @(posedge clk) begin
        if (rst) begin
            state <= S0;
        end else begin
            case (state)
                S0: begin
                    if (din == 1'b1) state <= S1;
                    else             state <= S0;
                end
                S1: begin
                    if (din == 1'b0) state <= S2;
                    else             state <= S1;
                end
                S2: begin
                    if (din == 1'b1) state <= S3;
                    else             state <= S0;
                end
                S3: begin
                    if (din == 1'b1) state <= S4;
                    else             state <= S2; // Pattern '1010', last two are '10' -> S2
                end
                S4: begin
                    // Overlapping pattern check for 1011...
                    // If next bit is 1, we have ...10111. The suffix is '1'. Go to S1.
                    // If next bit is 0, we have ...10110. The suffix is '10'. Go to S2.
                    if (din == 1'b1) state <= S1;
                    else             state <= S2;
                end
                default: state <= S0;
            endcase
        end
    end

    // Moore output depends only on current state
    assign detected = (state == S4);

endmodule
```

```verilog
module tb;
    reg clk;
    reg rst;
    reg din;
    wire detected;

    seqdet_moore uut (
        .clk(clk),
        .rst(rst),
        .din(din),
        .detected(detected)
    );

    always #5 clk = ~clk;

    integer passed;
    integer total;

    task check_output;
        input expected;
        begin
            total = total + 1;
            if (detected !== expected) begin
                $display("FAIL: din=%b, rst=%b, expected=%b, actual=%b", din, rst, expected, detected);
                passed = passed - 1;
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        // Initialize
        clk = 0;
        rst = 0;
        din = 0;
        passed = 0;
        total = 0;

        // Reset sequence
        @(posedge clk);
        rst = 1;
        din = 1; // Should be ignored per spec
        @(posedge clk);
        rst = 0;
        din = 0;
        #1; check_output(0);

        // Test Pattern: 1, 0, 1, 1 (Success)
        // T1: din=1 -> S1
        @(posedge clk); din = 1; #1; check_output(0);
        // T2: din=0 -> S2
        @(posedge clk); din = 0; #1; check_output(0);
        // T3: din=1 -> S3
        @(posedge clk); din = 1; #1; check_output(0);
        // T4: din=1 -> S4 (detected high)
        @(posedge clk); din = 1; #1; check_output(1);

        // Test Overlap: 1, 0, 1, 1, 0, 1, 1 (Success twice)
        // Current state is S4. Next bit is 0.
        // T5: din=0 -> S2 (suffix 10)
        @(posedge clk); din = 0; #1; check_output(0);
        // T6: din=1 -> S3
        @(posedge clk); din = 1; #1; check_output(0);
        // T7: din=1 -> S4 (detected high)
        @(posedge clk); din = 1; #1; check_output(1);

        // Test Reset mid-sequence
        // Current state is S4. Next bit is 1.
        // T8: din=1 -> S1
        @(posedge clk); din = 1; #1; check_output(0);
        // T9: din=0 -> S2
        @(posedge clk); din = 0; #1; check_output(0);
        // T10: din=1 (Trigger Reset)
        @(posedge clk); rst = 1; din = 1; #1; check_output(0);
        // T11: After reset, state should be S0. Next bit is ignored.
        @(posedge clk); rst = 0; din = 1; #1; check_output(0);

        // Test incorrect sequence: 1, 0, 1, 0 (Should go to S2)
        @(posedge clk); din = 1; #1; check_output(0); // S1
        @(posedge clk); din = 0; #1; check_output(0); // S2
        @(posedge clk); din = 1; #1; check_output(0); // S3
        @(posedge clk); din = 0; #1; check_output(0); // S2 (suffix 10)

        // Test complete sequence again to ensure recovery
        @(posedge clk); din = 1; #1; check_output(0); // S3
        @(posedge clk); din = 1; #1; check_output(1); // S4
        
        // Final cleanup
        @(posedge clk); din = 0; #1; check_output(0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```