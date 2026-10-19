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

    task check_bit(input reg expected_det);
        begin
            @(posedge clk);
            // The output 'detected' is Moore, so it updates at the same time as state.
            // However, we must wait for the signal to stabilize after the edge.
            #1; 
            if (detected !== expected_det) begin
                $display("FAIL: din=%b, rst=%b, expected detected=%b, actual=%b", din, rst, expected_det, detected);
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
            $display("FAIL: rst=1, expected detected=0, actual=%b", detected);
            passed = passed - 1; total = total + 1;
        end else begin
            passed = passed + 1; total = total + 1;
        end

        rst = 0;
        @(posedge clk); // State is S0 now. din=1 was ignored, so we are at S0 or S1 depending on implementation.
        // According to spec: "The bit on din at that edge is ignored."
        // So after rst=1 edge, state becomes S0. 
        // On next rising edge (rst=0), if din=1, it should go to S1.

        // Test Case 1: Basic pattern 1-0-1-1
        din = 1; check_bit(0); // S1
        din = 0; check_bit(0); // S2
        din = 1; check_bit(0); // S3
        din = 1; check_bit(1); // S4 (Detected!)

        // Test Case 2: Overlap pattern 1-0-1-1-0-1-1
        // Current state is S4. Next bit is 0.
        din = 0; check_bit(0); // S2 (from S4 via '0')
        din = 1; check_bit(0); // S3
        din = 1; check_bit(1); // S4 (Detected!)

        // Test Case 3: Reset mid-sequence
        din = 1; check_bit(0); // S1
        din = 0; check_bit(0); // S2
        rst = 1; // Trigger reset
        @(posedge clk); #1;
        if (detected !== 0) begin
            $display("FAIL: rst=1 mid-seq, expected detected=0, actual=%b", detected);
            passed = passed - 1; total = total + 1;
        end else begin
            passed = passed + 1; total = total + 1;
        end

        // Test Case 4: No pattern
        rst = 0;
        din = 0; check_bit(0);
        din = 0; check_bit(0);
        din = 1; check_bit(0);
        din = 1; check_bit(0);
        din = 1; check_bit(0);

        // Test Case 5: Partial pattern and wrong bit
        din = 1; check_bit(0); // S1
        din = 0; check_bit(0); // S2
        din = 0; check_bit(0); // S0 (Pattern broken)
        din = 1; check_bit(0); // S1
        din = 0; check_bit(0); // S2
        din = 1; check_bit(0); // S3
        din = 0; check_bit(0); // S2 (Pattern broken, but '10' is prefix)

        // Test Case 6: Complete pattern again
        din = 1; check_bit(0); // S3
        din = 1; check_bit(1); // S4

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
