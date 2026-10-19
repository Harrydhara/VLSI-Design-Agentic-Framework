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

    integer passed, total;

    task check_output(input expected);
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
        clk = 0;
        rst = 0;
        din = 0;
        passed = 0;
        total = 0;

        // Reset sequence
        @(posedge clk);
        rst = 1;
        din = 1; // din is ignored during reset
        @(posedge clk);
        rst = 0;
        #1; // Wait for combinational logic
        check_output(0);

        // Test Case 1: Simple pattern 1, 0, 1, 1
        // T=0: din=1 -> S1 (detected=0)
        @(posedge clk); din = 1; #1; check_output(0);
        // T=1: din=0 -> S2 (detected=0)
        @(posedge clk); din = 0; #1; check_output(0);
        // T=2: din=1 -> S3 (detected=0)
        @(posedge clk); din = 1; #1; check_output(0);
        // T=3: din=1 -> S4 (detected=1)
        @(posedge clk); din = 1; #1; check_output(1);

        // Test Case 2: Overlapping pattern 1, 0, 1, 1, 0, 1, 1
        // We are at S4. Next bit is 0.
        // T=4: din=0 -> S2 (detected=0)
        @(posedge clk); din = 0; #1; check_output(0);
        // T=5: din=1 -> S3 (detected=0)
        @(posedge clk); din = 1; #1; check_output(0);
        // T=6: din=1 -> S4 (detected=1)
        @(posedge clk); din = 1; #1; check_output(1);

        // Test Case 3: Reset mid-sequence
        // Current state is S4. Let's go to S1 then reset.
        // T=7: din=1 -> S1 (detected=0)
        @(posedge clk); din = 1; #1; check_output(0);
        // T=8: din=0 -> S2 (detected=0)
        @(posedge clk); din = 0; #1; check_output(0);
        // T=9: rst=1. State should go to S0 immediately at edge.
        @(posedge clk); rst = 1; din = 1; #1; check_output(0);
        
        // Test Case 4: Resetting from S4 directly
        rst = 0;
        @(posedge clk); din = 1; #1; check_output(0); // S1
        @(posedge clk); din = 0; #1; check_output(0); // S2
        @(posedge clk); din = 1; #1; check_output(0); // S3
        @(posedge clk); din = 1; #1; check_output(1); // S4
        @(posedge clk); rst = 1; din = 1; #1; check_output(0); // Reset to S0

        // Test Case 5: Corner case - sequence of all 1s
        @(posedge clk); din = 1; #1; check_output(0); // S1
        @(posedge clk); din = 1; #1; check_output(0); // S1
        @(posedge clk); din = 1; #1; check_output(0); // S1

        // Test Case 6: Corner case - sequence of all 0s
        @(posedge clk); din = 0; #1; check_output(0); // S0
        @(posedge clk); din = 0; #1; check_output(0); // S0

        // Test Case 7: Pattern with '1010' (should go to S2)
        @(posedge clk); din = 1; #1; check_output(0); // S1
        @(posedge clk); din = 0; #1; check_output(0); // S2
        @(posedge clk); din = 1; #1; check_output(0); // S3
        @(posedge clk); din = 0; #1; check_output(0); // S2 (last two bits '10')
        @(posedge clk); din = 1; #1; check_output(0); // S3
        @(posedge clk); din = 1; #1; check_output(1); // S4

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
