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

    task check_bit(input expected_detected);
        begin
            total = total + 1;
            // Since it's Mealy, we must check the output immediately after din changes
            // or at any point. However, in a testbench driven by clock edges, 
            // we check right after the assignment to din.
            if (detected !== expected_detected) begin
                $display("FAIL: din=%b, state_approx=?, expected detected=%b, actual=%b", din, expected_detected, detected);
                passed = passed - 1;
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        clk = 0;
        rst_n = 0;
        din = 0;
        passed = 0;
        total = 0;

        // Reset sequence
        #15 rst_n = 1;

        // Test Case 1: Basic pattern 1, 1, 0, 1
        // Sequence: 1 (S1), 1 (S2), 0 (S3), 1 (Detected!)
        @(posedge clk); din = 1; check_bit(0); // S0 -> S1
        @(posedge clk); din = 1; check_bit(0); // S1 -> S2
        @(posedge clk); din = 0; check_bit(0); // S2 -> S3
        // Mealy: detected depends on din. When din becomes 1, it should trigger immediately.
        #0; din = 1; check_bit(1);             // S3 + din=1 -> Detected!
        @(posedge clk);                         // Transition to S1 (last bit was 1)
        check_bit(0);

        // Test Case 2: Overlapping pattern 1, 1, 0, 1, 1, 0, 1
        // We are currently at S1.
        // Sequence needed from S1: 1 (S2), 0 (S3), 1 (Detected!)
        @(posedge clk); din = 1; check_bit(0); // S1 -> S2
        @(posedge clk); din = 0; check_bit(0); // S2 -> S3
        #0; din = 1; check_bit(1);             // Detected! (S3 + din=1)
        @(posedge clk);                         // Transition to S1
        check_bit(0);

        // Test Case 3: Reset during sequence
        @(posedge clk); din = 1; check_bit(0); // S1 -> S2
        @(posedge clk); din = 1; check_bit(0); // S2 -> S2 (stay)
        #2 rst_n = 0;                          // Async reset
        #1;
        if (uut.state !== 2'b00) begin
            $display("FAIL: Reset failed to clear state");
            passed = passed - 1; total = total + 1;
        end else begin
            passed = passed + 1; total = total + 1;
        end
        rst_n = 1;

        // Test Case 4: No pattern (0, 0, 0)
        @(posedge clk); din = 0; check_bit(0);
        @(posedge clk); din = 0; check_bit(0);
        @(posedge clk); din = 0; check_bit(0);

        // Test Case 5: Partial pattern (1, 1, 1)
        @(posedge clk); din = 1; check_bit(0); // S1
        @(posedge clk); din = 1; check_bit(0); // S2
        @(posedge clk); din = 1; check_bit(0); // S2 (stay)
        @(posedge clk); din = 0; check_bit(0); // S3

        // Test Case 6: Pattern with extra bits at start (0, 1, 1, 0, 1)
        @(posedge clk); din = 0; check_bit(0); // S0
        @(posedge clk); din = 1; check_bit(0); // S1
        @(posedge clk); din = 1; check_bit(0); // S2
        @(posedge clk); din = 0; check_bit(0); // S3
        #0; din = 1; check_bit(1);             // Detected!
        @(posedge clk);                         // Transition to S1
        check_bit(0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
