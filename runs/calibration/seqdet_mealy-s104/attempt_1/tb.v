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

    task check_bit(input expected_det);
        begin
            // Since it's Mealy, we must check 'detected' immediately when 'din' changes
            // and also after the clock edge to ensure stability if needed.
            // However, the spec says "changes as soon as din changes".
            if (detected !== expected_det) begin
                $display("FAIL: din=%b, state_after_clk=%b, expected detected=%b, actual detected=%b", 
                         din, uut.state, expected_det, detected);
                passed = passed - 1;
            end else begin
                passed = passed + 1;
            end
            total = total + 1;
        end
    endtask

    initial begin
        clk = 0;
        rst_n = 0;
        din = 0;
        passed = 0;
        total = 0;

        // Reset sequence
        #12 rst_n = 1;

        // Test Case 1: Simple pattern 1, 1, 0, 1
        // We drive din and check detected. Since it's Mealy, we check after setting din.
        
        // Input: 1
        din = 1; #10; // Clock edge
        check_bit(0);
        // Input: 1
        din = 1; #10;
        check_bit(0);
        // Input: 0
        din = 0; #10;
        check_bit(0);
        // Input: 1 (Pattern complete)
        din = 1; 
        #2; // Small delay to check Mealy response before clock edge
        check_bit(1);
        #8; // Finish the clock cycle
        check_bit(1);

        // Test Case 2: Overlapping pattern 1, 1, 0, 1, 1, 0, 1
        // Current state should be S1 (from previous 1).
        // Input: 1
        din = 1; #10;
        check_bit(0); // State becomes S2
        // Input: 0
        din = 0; #10;
        check_bit(0); // State becomes S3
        // Input: 1 (Pattern complete)
        din = 1;
        #2;
        check_bit(1);
        #8;
        check_bit(1); // State becomes S1

        // Test Case 3: Reset during sequence
        // Current state is S1.
        din = 1; #10; // State becomes S2
        rst_n = 0;    // Async reset
        #2;
        if (uut.state !== 2'b00) begin
            $display("FAIL: Reset failed, state=%b", uut.state);
            passed = passed - 1;
        end else begin
            passed = passed + 1;
        end
        total = total + 1;
        rst_n = 1;

        // Test Case 4: No pattern
        din = 0; #10; check_bit(0);
        din = 1; #10; check_bit(0);
        din = 0; #10; check_bit(0);
        din = 0; #10; check_bit(0);

        // Test Case 5: Multiple 1s (1, 1, 1, 0, 1)
        din = 1; #10; // S1
        din = 1; #10; // S2
        din = 1; #10; // S2
        din = 0; #10; // S3
        din = 1; #2; check_bit(1); #8; check_bit(1);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
