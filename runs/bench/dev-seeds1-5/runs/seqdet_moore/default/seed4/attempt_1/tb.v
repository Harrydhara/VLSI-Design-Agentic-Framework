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
            // The output 'detected' is a Moore output, it reflects the state 
            // reached AFTER the rising edge. We must wait for the signal to stabilize.
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

        // Test Case 1: Basic pattern 1-0-1-1
        rst = 0;
        din = 1; check_bit(0); // S1
        din = 0; check_bit(0); // S2
        din = 1; check_bit(0); // S3
        din = 1; check_bit(1); // S4 (Detected!)

        // Test Case 2: Overlapping pattern 1-0-1-1-0-1-1
        // Current state is S4. Next bit 0 -> S2. Then 1 -> S3, then 1 -> S4.
        din = 0; check_bit(0); // S2
        din = 1; check_bit(0); // S3
        din = 1; check_bit(1); // S4 (Detected!)

        // Test Case 3: Reset mid-sequence
        // Current state is S4. Next bit 1 -> S1.
        din = 1; check_bit(0); // S1
        din = 0; check_bit(0); // S2
        rst = 1; din = 1; check_bit(0); // Reset to S0, ignore din=1
        
        // Test Case 4: No pattern
        din = 0; check_bit(0); // S0
        din = 0; check_bit(0); // S0
        din = 1; check_bit(0); // S1
        din = 1; check_bit(0); // S1
        din = 1; check_bit(0); // S1
        din = 0; check_bit(0); // S2
        din = 0; check_bit(0); // S0

        // Test Case 5: Partial pattern '101' then wrong bit
        din = 1; check_bit(0); // S1
        din = 0; check_bit(0); // S2
        din = 1; check_bit(0); // S3
        din = 0; check_bit(0); // S2 (Pattern was 1010, ends in 10)

        // Test Case 6: Sequence 1-0-1-1-1 (Overlapping/Transition test)
        // From S2:
        din = 1; check_bit(0); // S3
        din = 1; check_bit(1); // S4
        din = 1; check_bit(0); // S1

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
