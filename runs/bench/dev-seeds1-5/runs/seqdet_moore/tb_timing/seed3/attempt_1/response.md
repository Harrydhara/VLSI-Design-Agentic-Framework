```verilog
module seqdet_moore(
    input   clk,
    input   rst,
    input   din,
    output  detected
);

    // State encoding for Moore machine
    // S0: Idle / Reset state
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
                    else             state <= S2; // Pattern '1010', last two bits are '10' -> S2
                end
                S4: begin
                    // Overlapping patterns: pattern is 1011.
                    // If next bit is 1, sequence becomes ...10111. Last bit is '1', so go to S1.
                    // If next bit is 0, sequence becomes ...10110. Last two bits are '10', so go to S2.
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

    integer passed, total;
    reg model_detected;

    // Reference Model
    // The model tracks the state transitions exactly like the RTL to predict 'detected'
    reg [2:0] model_state;
    localparam S0 = 3'd0, S1 = 3'd1, S2 = 3'd2, S3 = 3'd3, S4 = 3'd4;

    always @(posedge clk) begin
        if (rst) begin
            model_state <= S0;
        end else begin
            case (model_state)
                S0: if (din) model_state <= S1; else model_state <= S0;
                S1: if (!din) model_state <= S2; else model_state <= S1;
                S2: if (din) model_state <= S3; else model_state <= S0;
                S3: if (din) model_state <= S4; else model_state <= S2;
                S4: if (din) model_state <= S1; else model_state <= S2;
                default: model_state <= S0;
            endcase
        end
        model_detected <= (model_state == S4);
    end

    task check;
        begin
            total = total + 1;
            if (detected !== model_detected) begin
                $display("FAIL: time=%0d expected=%b actual=%b din=%b rst=%b", $time, model_detected, detected, din, rst);
                passed = passed; // no increment
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        // Initialize
        clk = 0;
        rst = 1;
        din = 0;
        passed = 0;
        total = 0;

        // Reset sequence
        @(negedge clk);
        rst = 1;
        din = 0;
        @(posedge clk); #1; // Wait for sync reset edge
        
        // Check reset state
        if (detected !== 0) begin
            $display("FAIL: Reset failed. expected=0 actual=%b", detected);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end

        rst = 0;

        // Test Case 1: Simple pattern 1, 0, 1, 1
        // Cycle 1: din=1 -> S1
        @(negedge clk); din = 1; @(posedge clk); #1 check;
        // Cycle 2: din=0 -> S2
        @(negedge clk); din = 0; @(posedge clk); #1 check;
        // Cycle 3: din=1 -> S3
        @(negedge clk); din = 1; @(posedge clk); #1 check;
        // Cycle 4: din=1 -> S4 (detected should be 1)
        @(negedge clk); din = 1; @(posedge clk); #1 check;

        // Test Case 2: Overlapping pattern 1, 0, 1, 1, 0, 1, 1
        // We are currently in S4. Next bit is 0.
        // Cycle 5: din=0 -> S2 (from S4)
        @(negedge clk); din = 0; @(posedge clk); #1 check;
        // Cycle 6: din=1 -> S3
        @(negedge clk); din = 1; @(posedge clk); #1 check;
        // Cycle 7: din=1 -> S4 (detected should be 1)
        @(negedge clk); din = 1; @(posedge clk); #1 check;

        // Test Case 3: Reset mid-sequence
        // Current state is S4. Let's go to S1, then reset.
        @(negedge clk); din = 1; @(posedge clk); #1 check; // S1
        @(negedge clk); rst = 1; @(posedge clk); #1 check; // Reset (S0)
        rst = 0;

        // Test Case 4: No pattern
        @(negedge clk); din = 0; @(posedge clk); #1 check;
        @(negedge clk); din = 0; @(posedge clk); #1 check;
        @(negedge clk); din = 1; @(posedge clk); #1 check;
        @(negedge clk); din = 1; @(posedge clk); #1 check; // S1

        // Test Case 5: Partial pattern then wrong bit
        // Pattern is 1011. Try 1010...
        @(negedge clk); din = 0; @(posedge clk); #1 check; // S2
        @(negedge clk); din = 1; @(posedge clk); #1 check; // S3
        @(negedge clk); din = 0; @(posedge clk); #1 check; // S2 (not detected)

        // Final pattern to ensure we can recover
        @(negedge clk); din = 1; @(posedge clk); #1 check; // S3
        @(negedge clk); din = 1; @(posedge clk); #1 check; // S4 (detected)

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```