module tb;
    reg clk;
    reg rst_n;
    reg din;
    wire detected;

    integer passed;
    integer total;

    seqdet_mealy uut (
        .clk(clk),
        .rst_n(rst_n),
        .din(din),
        .detected(detected)
    );

    always #5 clk = ~clk;

    // A task to drive din and check the Mealy output immediately.
    // In a Mealy machine, 'detected' is a combinational function of state AND din.
    task drive_and_check(input bit in_val, input bit expected_det);
        begin
            din = in_val;
            #1; // Wait for combinational propagation
            total = total + 1;
            if (detected !== expected_det) begin
                $display("FAIL: din=%b, expected detected=%b, actual detected=%b", in_val, expected_det, detected);
                passed = passed - 1;
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        // Initialize
        clk = 0;
        rst_n = 0;
        din = 0;
        passed = 0;
        total = 0;

        // Reset sequence
        #15 rst_n = 1;
        @(posedge clk);

        // Test Case 1: Simple pattern 1, 1, 0, 1
        // State transitions: S0 --(1)--> S1 --(1)--> S2 --(0)--> S3 --(1)--> S1 (Det!)
        drive_and_check(1, 0); // din=1, state becomes S1 on next edge
        @(posedge clk);
        drive_and_check(1, 0); // din=1, state becomes S2 on next edge
        @(posedge clk);
        drive_and_check(0, 0); // din=0, state becomes S3 on next edge
        @(posedge clk);
        drive_and_check(1, 1); // din=1, detected=1 (Mealy), state becomes S1 on next edge
        @(posedge clk);

        // Test Case 2: Overlapping pattern 1, 1, 0, 1, 1, 0, 1
        // Current state is S1.
        drive_and_check(1, 0); // din=1, state becomes S2 on next edge
        @(posedge clk);
        drive_and_check(0, 0); // din=0, state becomes S3 on next edge
        @(posedge clk);
        drive_and_check(1, 1); // din=1, detected=1 (Mealy), state becomes S1 on next edge
        @(posedge clk);
        drive_and_check(1, 0); // din=1, state becomes S2 on next edge
        @(posedge clk);
        drive_and_check(0, 0); // din=0, state becomes S3 on next edge
        @(posedge clk);
        drive_and_check(1, 1); // din=1, detected=1 (Mealy), state becomes S1 on next edge
        @(posedge clk);

        // Test Case 3: Reset during sequence
        // Sequence: 1, 1, (reset), 0, 1
        drive_and_check(1, 0); // S0 -> S1
        @(posedge clk);
        drive_and_check(1, 0); // S1 -> S2
        #2 rst_n = 0;          // Async reset
        #5 rst_n = 1;          // Release reset
        @(posedge clk);
        drive_and_check(0, 0); // Should be in S0
        @(posedge clk);
        drive_and_check(1, 0); // S0 -> S1

        // Test Case 4: Extra 1s (S2 should stay S2)
        // Sequence: 1, 1, 1, 1, 0, 1
        drive_and_check(1, 0); // S1 -> S2
        @(posedge clk);
        drive_and_check(1, 0); // S2 -> S2
        @(posedge clk);
        drive_and_check(1, 0); // S2 -> S2
        @(posedge clk);
        drive_and_check(0, 0); // S2 -> S3
        @(posedge clk);
        drive_and_check(1, 1); // S3 -> S1 (Detected)
        @(posedge clk);

        // Test Case 5: No pattern
        drive_and_check(0, 0);
        drive_and_check(0, 0);
        drive_and_check(1, 0);
        drive_and_check(0, 0);
        drive_and_check(1, 0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
