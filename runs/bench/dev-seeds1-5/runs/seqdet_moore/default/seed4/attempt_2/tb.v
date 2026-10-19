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

    // Helper task to drive input and check output after the edge
    task check_bit(input bit expected_det, input bit current_din, input bit current_rst);
        begin
            @(posedge clk);
            #1; // Wait for signals to settle after clock edge
            if (detected !== expected_det) begin
                $display("FAIL: din=%b, rst=%b, expected detected=%b, actual detected=%b", current_din, current_rst, expected_det, detected);
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

        // Reset sequence: On rising edge with rst=1, detector forgets and din is ignored.
        // The state becomes S0 immediately after the edge.
        // Since it's a Moore machine, output depends on state.
        // After reset edge, state is S0, so detected must be 0.
        rst = 1; din = 1;
        @(posedge clk);
        #1;
        if (detected !== 0) begin
            $display("FAIL: rst=1, expected detected=0, actual detected=%b", detected);
            passed = passed - 1; total = total + 1;
        end else begin
            passed = passed + 1; total = total + 1;
        end

        // Test Case 1: Basic pattern 1-0-1-1
        rst = 0;
        din = 1; check_bit(0, 1, 0); // S1
        din = 0; check_bit(0, 0, 0); // S2
        din = 1; check_bit(0, 1, 0); // S3
        din = 1; check_bit(1, 1, 0); // S4 (Detected!)

        // Test Case 2: Overlapping pattern 1-0-1-1-0-1-1
        din = 0; check_bit(0, 0, 0); // S2
        din = 1; check_bit(0, 1, 0); // S3
        din = 1; check_bit(1, 1, 0); // S4 (Detected!)

        // Test Case 3: Reset mid-sequence
        din = 1; check_bit(0, 1, 0); // S1
        din = 0; check_bit(0, 0, 0); // S2
        rst = 1; din = 1;             // Trigger reset on next edge
        @(posedge clk); #1;           // Manual step to handle rst logic
        if (detected !== 0) begin
            $display("FAIL: rst=1, expected detected=0, actual detected=%b", detected);
            passed = passed - 1; total = total + 1;
        end else begin
            passed = passed + 1; total = total + 1;
        end
        rst = 0;

        // Test Case 4: No pattern
        din = 0; check_bit(0, 0, 0); // S0
        din = 0; check_bit(0, 0, 0); // S0
        din = 1; check_bit(0, 1, 0); // S1
        din = 1; check_bit(0, 1, 0); // S1
        din = 1; check_bit(0, 1, 0); // S1
        din = 0; check_bit(0, 0, 0); // S2
        din = 0; check_bit(0, 0, 0); // S0

        // Test Case 5: Partial pattern '101' then wrong bit
        din = 1; check_bit(0, 1, 0); // S1
        din = 0; check_bit(0, 0, 0); // S2
        din = 1; check_bit(0, 1, 0); // S3
        din = 0; check_bit(0, 0, 0); // S2 (Pattern was 1010, ends in 10)

        // Test Case 6: Sequence 1-0-1-1-1 (Overlapping/Transition test)
        din = 1; check_bit(0, 1, 0); // S3
        din = 1; check_bit(1, 1, 0); // S4
        din = 1; check_bit(0, 1, 0); // S1

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
