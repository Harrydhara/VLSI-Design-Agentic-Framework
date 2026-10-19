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

    task check_val(input reg expected);
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
        din = 1; // din ignored during reset
        @(posedge clk);
        rst = 0;
        #1; // Wait for state to settle after edge
        check_val(0);

        // Test Pattern: 1, 0, 1, 1 (Success)
        din = 1; @(posedge clk); #1; check_val(0); // S1
        din = 0; @(posedge clk); #1; check_val(0); // S2
        din = 1; @(posedge clk); #1; check_val(0); // S3
        din = 1; @(posedge clk); #1; check_val(1); // S4 (Detected!)

        // Test Overlap: 1, 0, 1, 1, 0, 1, 1 (Success twice)
        // Current state is S4. Next bits: 0, 1, 1
        din = 0; @(posedge clk); #1; check_val(0); // S2
        din = 1; @(posedge clk); #1; check_val(0); // S3
        din = 1; @(posedge clk); #1; check_val(1); // S4 (Detected!)

        // Test Reset mid-sequence
        // Current state is S4. Sequence: 1, 0, 1, 1...
        din = 1; @(posedge clk); #1; check_val(0); // S1
        din = 0; @(posedge clk); #1; check_val(0); // S2
        rst = 1; @(posedge clk); #1; // Reset at edge. din=1 ignored.
        check_val(0); // Should be S0

        // Test non-matching sequence: 1, 1, 1, 0, 1, 1
        rst = 0;
        din = 1; @(posedge clk); #1; check_val(0); // S1
        din = 1; @(posedge clk); #1; check_val(0); // S1
        din = 1; @(posedge clk); #1; check_val(0); // S1
        din = 0; @(posedge clk); #1; check_val(0); // S2
        din = 1; @(posedge clk); #1; check_val(0); // S3
        din = 1; @(posedge clk); #1; check_val(1); // S4

        // Test sequence with wrong bit: 1, 0, 1, 0 (should go to S2)
        rst = 0;
        din = 1; @(posedge clk); #1; check_val(0); // S1
        din = 0; @(posedge clk); #1; check_val(0); // S2
        din = 1; @(posedge clk); #1; check_val(0); // S3
        din = 0; @(posedge clk); #1; check_val(0); // S2 (Pattern was 1010, last two are 10)

        // Final sequence: 1, 1
        din = 1; @(posedge clk); #1; check_val(0); // S3
        din = 1; @(posedge clk); #1; check_val(1); // S4

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
