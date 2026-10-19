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
                    // Overlapping pattern check for 1,0,1,1...
                    // If next bit is 1: sequence becomes ...1,1. Last bit is 1 -> S1
                    // If next bit is 0: sequence becomes ...1,0. Last two bits are '10' -> S2
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

    integer i;
    integer passed;
    integer total;

    seqdet_moore uut (
        .clk(clk),
        .rst(rst),
        .din(din),
        .detected(detected)
    );

    always #5 clk = ~clk;

    task check_bit(input bit expected_det);
        begin
            @(posedge clk);
            // The Moore output changes at the edge, but we must sample 
            // after the edge has settled. In a simulation with zero delay, 
            #1; 
            if (detected !== expected_det) begin
                $display("FAIL: din=%b, rst=%b, expected detected=%b, actual detected=%b", din, rst, expected_det, detected);
                passed = passed - 1;
            end else begin
                passed = passed + 1;
            end
            total = total + 1;
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
        din = 1; // din is ignored during reset edge
        #1;
        if (detected !== 0) begin
            $display("FAIL: rst=1, expected detected=0, actual detected=%b", detected);
            passed = passed - 1; total = total + 1;
        end else begin
            passed = passed + 1; total = total + 1;
        end

        @(posedge clk);
        rst = 0;
        #1; // Wait for state transition
        // After reset, we are in S0. Output should be 0.
        if (detected !== 0) begin
            $display("FAIL: post-reset, expected detected=0, actual detected=%b", detected);
            passed = passed - 1; total = total + 1;
        end else begin
            passed = passed + 1; total = total + 1;
        end

        // Test Pattern 1: 1, 0, 1, 1 (Standard)
        din = 1; check_bit(0); // S1
        din = 0; check_bit(0); // S2
        din = 1; check_bit(0); // S3
        din = 1; check_bit(1); // S4 (Detected!)

        // Test Overlap: 1, 0, 1, 1, 0, 1, 1
        // Current state is S4. Next bit is 0.
        // Sequence so far: ...1, 0, 1, 1. New bit 0 makes it ...1, 0. (S2)
        din = 0; check_bit(0); // S2
        din = 1; check_bit(0); // S3
        din = 1; check_bit(1); // S4 (Detected!)

        // Test Reset mid-sequence: 1, 0, 1, [rst], 1
        din = 1; check_bit(0); // S1
        din = 0; check_bit(0); // S2
        din = 1; check_bit(0); // S3
        // Apply reset on the edge where din=1. The bit is ignored.
        @(posedge clk);
        rst = 1; din = 1;
        #1;
        if (detected !== 0) begin
            $display("FAIL: rst mid-seq, expected detected=0, actual detected=%b", detected);
            passed = passed - 1; total = total + 1;
        end else begin
            passed = passed + 1; total = total + 1;
        end

        // After reset, state is S0. Next bit 1 -> S1.
        @(posedge clk);
        rst = 0; din = 1;
        #1;
        if (detected !== 0) begin
            $display("FAIL: post-reset sequence start, expected detected=0, actual detected=%b", detected);
            passed = passed - 1; total = total + 1;
        end else begin
            passed = passed + 1; total = total + 1;
        end

        // Test No Pattern: 1, 1, 1, 0, 0, 0
        din = 1; check_bit(0); // S1
        din = 1; check_bit(0); // S1
        din = 1; check_bit(0); // S1
        din = 0; check_bit(0); // S2
        din = 0; check_bit(0); // S0
        din = 0; check_bit(0); // S0

        // Test Pattern with trailing bits: 1, 0, 1, 1, 1 (S4 -> S1)
        din = 1; check_bit(0); // S1
        din = 0; check_bit(0); // S2
        din = 1; check_bit(0); // S3
        din = 1; check_bit(1); // S4
        din = 1; check_bit(0); // S1

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```