```verilog
module seqdet_moore(
    input   clk,
    input   rst,
    input   din,
    output  detected
);

    // State encoding for Moore machine
    // S0: Idle/Reset
    // S1: Detected '1'
    // S2: Detected '10'
    // S3: Detected '101'
    // S4: Detected '1011' (Output 1)
    reg [2:0] state;
    parameter S0 = 3'd0, S1 = 3'd1, S2 = 3'd2, S3 = 3'd3, S4 = 3'd4;

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
                    else             state <= S2; // Pattern '1010', last two bits are '10' -> S2
                end
                S4: begin
                    // Overlapping pattern check for 1011...
                    // If next bit is 1, we have ...10111. Last four: 0111 (No) or 111? No.
                    // Actually, if state is S4, the last bits were 1011.
                    // If din=1, sequence ends in 11. Next possible start is '1'.
                    // If din=0, sequence ends in 10.
                    if (din == 1'b0) state <= S2; // ...10110 -> last two are 10
                    else             state <= S1; // ...10111 -> last one is 1
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

    integer passed;
    integer total;

    seqdet_moore uut (
        .clk(clk),
        .rst(rst),
        .din(din),
        .detected(detected)
    );

    always #5 clk = ~clk;

    task check_val(input reg expected);
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
        din = 1; // din ignored during reset
        @(posedge clk);
        rst = 0;
        #1; // Wait for state to settle after edge
        check_val(0);

        // Test Pattern: 1, 0, 1, 1 (Success)
        din = 1; @(posedge clk); #1; check_val(0); // S1
        din = 0; @(posedge clk); #1; check_val(0); // S2
        din = 1; @(posedge clk); #1; check_val(0); // S3
        din = 1; @(posedge clk); #1; check_val(1); // S4 (Detected!)

        // Test Overlap: 1, 0, 1, 1, 0, 1, 1 (Success twice)
        // Current state is S4. Next bits: 0, 1, 1
        din = 0; @(posedge clk); #1; check_val(0); // S2
        din = 1; @(posedge clk); #1; check_val(0); // S3
        din = 1; @(posedge clk); #1; check_val(1); // S4 (Detected!)

        // Test Reset mid-sequence
        // Current state is S4. Sequence: 1, 0, 1, 1...
        din = 1; @(posedge clk); #1; check_val(0); // S1
        din = 0; @(posedge clk); #1; check_val(0); // S2
        rst = 1; @(posedge clk); #1; // Reset at edge. din=1 ignored.
        check_val(0); // Should be S0

        // Test non-matching sequence: 1, 1, 1, 0, 1, 1
        rst = 0;
        din = 1; @(posedge clk); #1; check_val(0); // S1
        din = 1; @(posedge clk); #1; check_val(0); // S1
        din = 1; @(posedge clk); #1; check_val(0); // S1
        din = 0; @(posedge clk); #1; check_val(0); // S2
        din = 1; @(posedge clk); #1; check_val(0); // S3
        din = 1; @(posedge clk); #1; check_val(1); // S4

        // Test sequence with wrong bit: 1, 0, 1, 0 (should go to S2)
        rst = 0;
        din = 1; @(posedge clk); #1; check_val(0); // S1
        din = 0; @(posedge clk); #1; check_val(0); // S2
        din = 1; @(posedge clk); #1; check_val(0); // S3
        din = 0; @(posedge clk); #1; check_val(0); // S2 (Pattern was 1010, last two are 10)

        // Final sequence: 1, 1
        din = 1; @(posedge clk); #1; check_val(0); // S3
        din = 1; @(posedge clk); #1; check_val(1); // S4

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```