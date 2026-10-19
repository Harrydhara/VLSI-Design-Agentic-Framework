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
    // S4: Detected '1011' (Output = 1)
    reg [2:0] state;

    parameter S0 = 3'd0;
    parameter S1 = 3'd1;
    parameter S2 = 3'd2;
    parameter S3 = 3'd3;
    parameter S4 = 3'd4;

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

    task check_bit(input bit expected_detected);
        begin
            @(posedge clk);
            // The output 'detected' is a Moore output, it changes at the edge.
            // We must sample after the edge has settled to see the result of the current din.
            #1; 
            if (detected !== expected_detected) begin
                $display("FAIL: din=%b, rst=%b, expected detected=%b, actual=%b", din, rst, expected_detected, detected);
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
        #1; // Wait for edge to settle
        // After reset, state should be S0. Output is 0.
        if (detected !== 1'b0) begin
            $display("FAIL: Reset failed. din=%b, rst=%b, expected detected=0, actual=%b", din, rst, detected);
            passed = passed - 1;
        end else begin
            passed = passed + 1;
        end
        total = total + 1;

        rst = 0;
        @(posedge clk); // Transition to stable state after reset

        // Test Case 1: Simple pattern 1, 0, 1, 1
        // Sequence: din=1 (S1), din=0 (S2), din=1 (S3), din=1 (S4)
        din = 1; check_bit(0); // S1
        din = 0; check_bit(0); // S2
        din = 1; check_bit(0); // S3
        din = 1; check_bit(1); // S4 (Detected!)

        // Test Case 2: Overlapping pattern 1, 0, 1, 1, 0, 1, 1
        // We are currently in S4.
        // Next bit din=0 -> sequence ends ...1,0 -> state S2
        din = 0; check_bit(0); // S2
        // Next bit din=1 -> sequence ends ...1,0,1 -> state S3
        din = 1; check_bit(0); // S3
        // Next bit din=1 -> sequence ends ...1,0,1,1 -> state S4 (Detected!)
        din = 1; check_bit(1); // S4

        // Test Case 3: Reset mid-sequence
        // Current state is S4. Let's go to S1 then reset.
        din = 1; check_bit(0); // S1
        rst = 1; @(posedge clk); #1;
        // After rst, state should be S0 regardless of din
        din = 1; // This bit is ignored during reset edge
        if (detected !== 1'b0) begin
            $display("FAIL: Reset mid-sequence failed. din=%b, rst=%b, expected detected=0, actual=%b", din, rst, detected);
            passed = passed - 1;
        end else begin
            passed = passed + 1;
        end
        total = total + 1;
        rst = 0;

        // Test Case 4: No pattern
        din = 0; check_bit(0);
        din = 0; check_bit(0);
        din = 1; check_bit(0);
        din = 1; check_bit(0);
        din = 0; check_bit(0);

        // Test Case 5: Partial pattern and wrong bit
        // 1, 0, 1, 0 (should go to S2)
        din = 1; check_bit(0); // S1
        din = 0; check_bit(0); // S2
        din = 1; check_bit(0); // S3
        din = 0; check_bit(0); // S2

        // Test Case 6: Pattern with overlapping '1's
        // 1, 1, 0, 1, 1
        din = 1; check_bit(0); // S1
        din = 1; check_bit(0); // S1
        din = 0; check_bit(0); // S2
        din = 1; check_bit(0); // S3
        din = 1; check_bit(1); // S4

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```