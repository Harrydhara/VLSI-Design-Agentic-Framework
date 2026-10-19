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

    always #5 clk = ~clk;

    integer passed;
    integer total;

    task check_output;
        input expected;
        begin
            total = total + 1;
            if (detected !== expected) begin
                $display("FAIL: din=%b, rst=%b, expected=%b, actual=%b", din, rst, expected, detected);
                passed = passed - 1;
            end else begin
                passed = passed + 1;
            end
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
        din = 1; // Should be ignored per spec
        @(posedge clk);
        rst = 0;
        din = 0;
        #1; check_output(0);

        // Test Pattern: 1, 0, 1, 1 (Success)
        // T1: din=1 -> S1
        @(posedge clk); din = 1; #1; check_output(0);
        // T2: din=0 -> S2
        @(posedge clk); din = 0; #1; check_output(0);
        // T3: din=1 -> S3
        @(posedge clk); din = 1; #1; check_output(0);
        // T4: din=1 -> S4 (detected high)
        @(posedge clk); din = 1; #1; check_output(1);

        // Test Overlap: 1, 0, 1, 1, 0, 1, 1 (Success twice)
        // Current state is S4. Next bit is 0.
        // T5: din=0 -> S2 (suffix 10)
        @(posedge clk); din = 0; #1; check_output(0);
        // T6: din=1 -> S3
        @(posedge clk); din = 1; #1; check_output(0);
        // T7: din=1 -> S4 (detected high)
        @(posedge clk); din = 1; #1; check_output(1);

        // Test Reset mid-sequence
        // Current state is S4. Next bit is 1.
        // T8: din=1 -> S1
        @(posedge clk); din = 1; #1; check_output(0);
        // T9: din=0 -> S2
        @(posedge clk); din = 0; #1; check_output(0);
        // T10: din=1 (Trigger Reset)
        @(posedge clk); rst = 1; din = 1; #1; check_output(0);
        // T11: After reset, state should be S0. Next bit is ignored.
        @(posedge clk); rst = 0; din = 1; #1; check_output(0);

        // Test incorrect sequence: 1, 0, 1, 0 (Should go to S2)
        @(posedge clk); din = 1; #1; check_output(0); // S1
        @(posedge clk); din = 0; #1; check_output(0); // S2
        @(posedge clk); din = 1; #1; check_output(0); // S3
        @(posedge clk); din = 0; #1; check_output(0); // S2 (suffix 10)

        // Test complete sequence again to ensure recovery
        @(posedge clk); din = 1; #1; check_output(0); // S3
        @(posedge clk); din = 1; #1; check_output(1); // S4
        
        // Final cleanup
        @(posedge clk); din = 0; #1; check_output(0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
