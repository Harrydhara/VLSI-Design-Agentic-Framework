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

    task check_bit(input bit expected_det, input bit current_din);
        begin
            total = total + 1;
            if (detected !== expected_det) begin
                $display("FAIL: din=%b, expected detected=%b, actual detected=%b", current_din, expected_det, detected);
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

        // Test Case 1: Simple pattern 1, 1, 0, 1
        // Sequence: din=1 (S1), din=1 (S2), din=0 (S3), din=1 (Detected!)
        @(posedge clk); din = 1; // S0 -> S1
        #1; check_bit(0, 1);
        @(posedge clk); din = 1; // S1 -> S2
        #1; check_bit(0, 1);
        @(posedge clk); din = 0; // S2 -> S3
        #1; check_bit(0, 0);
        @(posedge clk); din = 1; // S3 -> S1 (Mealy output happens here)
        #1; check_bit(1, 1);

        // Test Case 2: Overlapping pattern 1, 1, 0, 1, 1, 0, 1
        // We are at S1. Next bits: 1 (S2), 0 (S3), 1 (Det/S1), 1 (S2), 0 (S3), 1 (Det/S1)
        @(posedge clk); din = 1; // S1 -> S2
        #1; check_bit(0, 1);
        @(posedge clk); din = 0; // S2 -> S3
        #1; check_bit(0, 0);
        @(posedge clk); din = 1; // S3 -> S1 (Detected)
        #1; check_bit(1, 1);
        @(posedge clk); din = 1; // S1 -> S2
        #1; check_bit(0, 1);
        @(posedge clk); din = 0; // S2 -> S3
        #1; check_bit(0, 0);
        @(posedge clk); din = 1; // S3 -> S1 (Detected)
        #1; check_bit(1, 1);

        // Test Case 3: Asynchronous Reset
        @(posedge clk); din = 1; // Move to some state
        #2 rst_n = 0;            // Assert reset mid-cycle
        #1; if (detected !== 0) begin
             $display("FAIL: Async reset failed. detected=%b", detected);
             passed = passed - 1; total = total + 1;
        end else begin
             passed = passed + 1; total = total + 1;
        end
        #10 rst_n = 1;

        // Test Case 4: Mealy behavior (output changes immediately with din)
        // Get to S3 first
        @(posedge clk); din = 1; // S0 -> S1
        @(posedge clk); din = 1; // S1 -> S2
        @(posedge clk); din = 0; // S2 -> S3
        #1; check_bit(0, 0);     // In S3, but din is 0
        
        // Change din to 1 without waiting for clock edge
        din = 1;
        #1; check_bit(1, 1);     // Should detect immediately (Mealy)

        // Test Case 5: Multiple 1s in a row
        @(posedge clk); din = 1; // S3 -> S1 (from previous state transition logic)
        // Wait, let's reset to be sure.
        @(posedge clk); din = 0; rst_n = 0; #5 rst_n = 1;
        @(posedge clk); din = 1; // S0 -> S1
        @(posedge clk); din = 1; // S1 -> S2
        @(posedge clk); din = 1; // S2 -> S2 (stay in S2)
        #1; check_bit(0, 1);
        @(posedge clk); din = 0; // S2 -> S3
        #1; check_bit(0, 0);
        @(posedge clk); din = 1; // S3 -> S1 (Detected)
        #1; check_bit(1, 1);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
