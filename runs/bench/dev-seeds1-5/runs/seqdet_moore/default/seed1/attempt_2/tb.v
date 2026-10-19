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

    // Helper to check output after the clock edge has occurred and state has settled
    task check_output(input bit expected_det, input string msg);
        begin
            #1; // Wait for combinational logic/state update to settle
            if (detected !== expected_det) begin
                $display("FAIL: %s | din=%b, rst=%b, expected detected=%b, actual=%b", msg, din, rst, expected_det, detected);
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
        din = 1; // din is ignored during reset
        check_output(0, "Resetting");

        rst = 0;
        @(posedge clk); 
        check_output(0, "Post-reset idle");

        // Test Case 1: Simple pattern 1, 0, 1, 1
        din = 1; @(posedge clk); check_output(0, "Pattern bit 1"); // S1
        din = 0; @(posedge clk); check_output(0, "Pattern bit 2"); // S2
        din = 1; @(posedge clk); check_output(0, "Pattern bit 3"); // S3
        din = 1; @(posedge clk); check_output(1, "Pattern bit 4 (Match)"); // S4

        // Test Case 2: Overlap pattern 1, 0, 1, 1, 0, 1, 1
        // Current state is S4. Next bit 0 -> S2. Then 1 -> S3. Then 1 -> S4.
        din = 0; @(posedge clk); check_output(0, "Overlap bit 5"); // S2
        din = 1; @(posedge clk); check_output(0, "Overlap bit 6"); // S3
        din = 1; @(posedge clk); check_output(1, "Overlap bit 7 (Match)"); // S4

        // Test Case 3: Reset mid-sequence
        // Sequence: 1, 0, 1 -> reset -> 1, 1
        din = 1; @(posedge clk); check_output(0, "Seq bit 8"); // S1 (from S4)
        din = 0; @(posedge clk); check_output(0, "Seq bit 9"); // S2
        din = 1; @(posedge clk); check_output(0, "Seq bit 10"); // S3
        // Trigger reset on next edge. din=1 is ignored.
        rst = 1; din = 1; @(posedge clk); check_output(0, "Resetting mid-seq"); 
        rst = 0;

        // Test Case 4: Wrong bits (1, 0, 1, 0)
        din = 1; @(posedge clk); check_output(0, "Wrong bit 1"); // S1
        din = 0; @(posedge clk); check_output(0, "Wrong bit 2"); // S2
        din = 1; @(posedge clk); check_output(0, "Wrong bit 3"); // S3
        din = 0; @(posedge clk); check_output(0, "Wrong bit 4 (Pattern broken)"); // S2

        // Test Case 5: Corner case - all ones
        din = 1; @(posedge clk); check_output(0, "All ones 1"); // S3 -> S4? No, S2->S3. Wait.
        // Let's re-trace: Current state is S2 (from bit 4). din=1 -> S3.
        din = 1; @(posedge clk); check_output(0, "All ones 2"); // S3
        din = 1; @(posedge clk); check_output(1, "All ones 3 (Match)"); // S4
        din = 1; @(posedge clk); check_output(0, "All ones 4"); // S1

        // Test Case 6: All zeros
        din = 0; @(posedge clk); check_output(0, "All zeros 1"); // S0
        din = 0; @(posedge clk); check_output(0, "All zeros 2"); // S0

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
