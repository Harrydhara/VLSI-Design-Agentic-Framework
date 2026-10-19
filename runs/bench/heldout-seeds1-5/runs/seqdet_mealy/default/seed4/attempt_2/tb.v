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

    // Task to apply input and check output at the end of the cycle
    task drive_and_check(input expected_det);
        begin
            total = total + 1;
            #10; // Wait for clock edge and state transition
            if (detected !== expected_det) begin
                $display("FAIL: din=%b, expected detected=%b, actual=%b", din, expected_det, detected);
                passed = passed - 1;
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    // Task to check Mealy behavior (immediate change)
    task check_mealy(input expected_det);
        begin
            total = total + 1;
            #0.1; // Tiny delay to allow combinational propagation
            if (detected !== expected_det) begin
                $display("FAIL: Mealy din=%b, expected detected=%b, actual=%b", din, expected_det, detected);
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

        // Reset
        #15 rst_n = 1;
        #5; // Wait for reset to settle

        // Test Case 1: Basic sequence 1, 1, 0, 1
        din = 1; drive_and_check(0); // S1
        din = 1; drive_and_check(0); // S2
        din = 0; drive_and_check(0); // S3
        din = 1; drive_and_check(1); // Detected! -> S1

        // Test Case 2: Overlapping pattern 1, 1, 0, 1, 1, 0, 1
        // Current state is S1. Next bits: 1, 0, 1... wait, the sequence was 1101.
        // To get 1101101, we need to feed 1, 1, 0, 1, 1, 0, 1 starting from S0.
        // Let's reset for a clean overlap test.
        rst_n = 0; #10; rst_n = 1; #5;
        din = 1; drive_and_check(0); // S1
        din = 1; drive_and_check(0); // S2
        din = 0; drive_and_check(0); // S3
        din = 1; drive_and_check(1); // Detected! -> S1 (Sequence: 1,1,0,1)
        din = 1; drive_and_check(0); // S2 (Sequence part: ...1,1)
        din = 0; drive_and_check(0); // S3 (Sequence part: ...1,1,0)
        din = 1; drive_and_check(1); // Detected! -> S1 (Sequence: 1,1,0,1,1,0,1)

        // Test Case 3: Reset during sequence
        din = 1; #5; // S1
        din = 1; #5; // S2
        rst_n = 0;   // Async reset
        #5 rst_n = 1;
        #5;          // Wait for state to be S0
        if (uut.state !== 2'b00) begin
             $display("FAIL: Reset failed, state=%b", uut.state);
             passed = passed - 1; total = total + 1;
        end else begin
             passed = passed + 1; total = total + 1;
        end

        // Test Case 4: Mealy behavior check
        // Get to S3
        din = 1; #10; // S1
        din = 1; #10; // S2
        din = 0; #10; // S3
        // Now in S3, detected is 0. Change din to 1.
        din = 1;
        check_mealy(1);
        #5; // Complete the cycle

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
