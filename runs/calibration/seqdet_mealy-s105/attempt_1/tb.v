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

    task check_val(input reg expected);
        begin
            total = total + 1;
            if (detected !== expected) begin
                $display("FAIL: din=%b, rst_n=%b, expected=%b, actual=%b", din, rst_n, expected, detected);
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
        
        // Test Case 1: Basic pattern 1, 1, 0, 1
        // We must check 'detected' both when din changes and after clk edge.
        // Since it is Mealy, we check the value of detected relative to din.
        
        @(posedge clk); din = 1; // S0 -> S1 (at next edge)
        #1; check_val(0);
        @(posedge clk); din = 1; // S1 -> S2
        #1; check_val(0);
        @(posedge clk); din = 0; // S2 -> S3
        #1; check_val(0);
        // Now in S3, if din becomes 1, detected must go high immediately (Mealy)
        din = 1;
        #1; check_val(1);
        @(posedge clk); // Transition to S1
        #1; check_val(0);

        // Test Case 2: Overlapping pattern 1, 1, 0, 1, 1, 0, 1
        // Sequence so far (from previous): ...1 (at end of TC1)
        // We need to build up to the next 1101.
        // Current state is S1.
        @(posedge clk); din = 1; // S1 -> S2
        #1; check_val(0);
        @(posedge clk); din = 0; // S2 -> S3
        #1; check_val(0);
        din = 1;                // Mealy trigger
        #1; check_val(1);
        @(posedge clk);         // State becomes S1
        #1; check_val(0);
        @(posedge clk); din = 1; // S1 -> S2
        #1; check_val(0);
        @(posedge clk); din = 0; // S2 -> S3
        #1; check_val(0);
        din = 1;                // Mealy trigger
        #1; check_val(1);
        @(posedge clk);         // State becomes S1
        #1; check_val(0);

        // Test Case 3: Reset mid-sequence
        @(posedge clk); din = 1; // S1
        @(posedge clk); din = 1; // S2
        @(posedge clk); din = 0; // S3
        #1; check_val(0);
        rst_n = 0;               // Async reset
        #1;
        if (uut.state !== 2'd0) begin
             $display("FAIL: Reset failed to clear state");
             passed = passed - 1;
             total = total + 1;
        end else begin
             passed = passed + 1;
             total = total + 1;
        end
        din = 1;                 // Should not trigger because reset happened
        #1; check_val(0);
        rst_n = 1;

        // Test Case 4: Continuous 1s (S2 should stay S2)
        @(posedge clk); din = 1; // S0 -> S1
        @(posedge clk); din = 1; // S1 -> S2
        @(posedge clk); din = 1; // S2 -> S2
        #1; check_val(0);
        @(posedge clk); din = 1; // S2 -> S2
        #1; check_val(0);

        // Test Case 5: Pattern with extra zeros
        @(posedge clk); din = 0; // S2 -> S3 (if we were in S2) - wait, let's reset state manually for clarity
        // Let's just provide a clean sequence.
        @(posedge clk); din = 1; // S0->S1
        @(posedge clk); din = 1; // S1->S2
        @(posedge clk); din = 0; // S2->S3
        din = 1;                 // Mealy!
        #1; check_val(1);
        @(posedge clk); din = 0; // S1 -> S0
        #1; check_val(0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
