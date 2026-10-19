module tb;
    reg clk;
    reg rst_n;
    reg din;
    wire detected;

    integer i;
    integer passed;
    integer total;

    seqdet_mealy uut (
        .clk(clk),
        .rst_n(rst_n),
        .din(din),
        .detected(detected)
    );

    always #5 clk = ~clk;

    task check_bit(input bit expected_det, input bit in_val);
        begin
            // Since it's Mealy, 'detected' reacts immediately to 'din'.
            // However, in a testbench with a clock, we must be careful about 
            // race conditions between din change and detected change.
            // We will check the output after a tiny delay to allow combinational propagation.
            #1; 
            if (detected !== expected_det) begin
                $display("FAIL: din=%b, expected detected=%b, actual detected=%b", in_val, expected_det, detected);
                passed = passed - 1;
            end else begin
                passed = passed + 1;
            end
            total = total + 1;
            
            // Prepare for next cycle: apply din and wait for clock edge
            din = in_val;
        end
    endtask

    initial begin
        // Initialize
        clk = 0;
        rst_n = 0;
        din = 0;
        passed = 0;
        total = 0;

        // Reset
        #15 rst_n = 1;
        @(posedge clk);

        // Test Case 1: Simple pattern 1, 1, 0, 1
        // Sequence: 1 (S1), 1 (S2), 0 (S3), 1 (Detected!)
        check_bit(0, 1); // S0 -> S1
        @(posedge clk);
        check_bit(0, 1); // S1 -> S2
        @(posedge clk);
        check_bit(0, 0); // S2 -> S3
        @(posedge clk);
        check_bit(1, 1); // S3 -> S1 (Detected)
        @(posedge clk);

        // Test Case 2: Overlapping pattern 1, 1, 0, 1, 1, 0, 1
        // We are currently at S1.
        // Sequence from here: 1 (S2), 0 (S3), 1 (Det!), 1 (S2), 0 (S3), 1 (Det!)
        check_bit(0, 1); // S1 -> S2
        @(posedge clk);
        check_bit(0, 0); // S2 -> S3
        @(posedge clk);
        check_bit(1, 1); // S3 -> S1 (Detected)
        @(posedge clk);
        check_bit(0, 1); // S1 -> S2
        @(posedge clk);
        check_bit(0, 0); // S2 -> S3
        @(posedge clk);
        check_bit(1, 1); // S3 -> S1 (Detected)
        @(posedge clk);

        // Test Case 3: Reset during sequence
        // Sequence: 1, 1, (reset), 0, 1
        check_bit(0, 1); // S0 -> S1
        @(posedge clk);
        check_bit(0, 1); // S1 -> S2
        #2 rst_n = 0;    // Async reset
        #5 rst_n = 1;    // Release reset
        @(posedge clk);
        check_bit(0, 0); // Should be in S0
        @(posedge clk);
        check_bit(0, 1); // S0 -> S1

        // Test Case 4: Extra 1s (S2 should stay S2)
        // Sequence: 1, 1, 1, 1, 0, 1
        check_bit(0, 1); // S1 -> S2
        @(posedge clk);
        check_bit(0, 1); // S2 -> S2
        @(posedge clk);
        check_bit(0, 1); // S2 -> S2
        @(posedge clk);
        check_bit(0, 0); // S2 -> S3
        @(posedge clk);
        check_bit(1, 1); // S3 -> S1 (Detected)
        @(posedge clk);

        // Test Case 5: No pattern
        check_bit(0, 0);
        check_bit(0, 0);
        check_bit(0, 1);
        check_bit(0, 0);
        check_bit(0, 1);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
