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

    // Reference Model State
    // We track the sequence of bits accepted by the detector.
    // Since it's a Moore machine, we can model its state transitions.
    // States: 0 (none), 1 (1), 2 (10), 3 (101), 4 (1011)
    integer ref_state;
    integer passed;
    integer total;

    always #5 clk = ~clk;

    initial begin
        // Initialize
        clk = 0;
        rst = 0;
        din = 0;
        ref_state = 0;
        passed = 0;
        total = 0;

        // Apply synchronous reset
        @(posedge clk);
        rst = 1;
        din = 0;
        #1; // Wait for logic to settle
        ref_state = 0; // Reset state
        
        // The bit on din at the reset edge is ignored.
        // So we move to next cycle.
        @(posedge clk);
        rst = 0;
        din = 0;
        #1;

        // Test Case 1: Simple pattern 1, 0, 1, 1
        test_bit(1); // state -> 1
        test_bit(0); // state -> 2
        test_bit(1); // state -> 3
        test_bit(1); // state -> 4 (detected should be 1)

        // Test Case 2: Overlap 1, 0, 1, 1, 0, 1, 1
        // Current state is 4. Next bit is 0.
        // From state 4, if we get 0, what happens?
        // The sequence was ...1, 0, 1, 1. If next is 0, the new suffix is "1, 0".
        // So state should go to 2.
        test_bit(0); // state -> 2 (suffix 10)
        test_bit(1); // state -> 3 (suffix 101)
        test_bit(1); // state -> 4 (suffix 1011)

        // Test Case 3: Reset mid-sequence
        test_bit(1); // state -> 1
        test_bit(0); // state -> 2
        @(posedge clk);
        rst = 1; din = 1; // reset edge. bit 1 ignored.
        #1;
        ref_state = 0; // Reset model
        // After this, rst is 0.
        @(posedge clk);
        rst = 0; din = 1;
        #1;
        // state should be 1 (since we just saw a '1')
        
        test_bit(1); // state -> 1
        test_bit(0); // state -> 2
        test_bit(1); // state -> 3
        test_bit(1); // state -> 4

        // Test Case 4: Wrong bits
        @(posedge clk); rst = 1; din = 0; #1; ref_state = 0;
        @(posedge clk); rst = 0; din = 0; #1;
        test_bit(1); test_bit(1); test_bit(0); test_bit(1); test_bit(1); // 1,1,0,1,1 -> detects at end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

    task test_bit(input bit_val);
        begin
            din = bit_val;
            @(posedge clk);
            #1; // Wait for synchronous logic to settle
            
            // Update Reference Model State Machine
            if (rst) begin
                ref_state = 0;
            end else begin
                case (ref_state)
                    0: if (din == 1) ref_state = 1; else ref_state = 0;
                    1: if (din == 0) ref_state = 2; else ref_state = 1;
                    2: if (din == 1) ref_state = 3; else ref_state = 0;
                    3: if (din == 1) ref_state = 4; else if (din == 0) ref_state = 2; else ref_state = 0;
                    4: if (din == 0) ref_state = 2; else if (din == 1) ref_state = 1; else ref_state = 0;
                    // Wait, state 4 is "1011". If next bit is 0, suffix is "10", so state 2.
                    // If next bit is 1, suffix is "1", so state 1.
                    default: ref_state = 0;
                endcase
            end

            // Moore output check
            // The spec says detected=1 during the cycle right after the edge.
            // Since we are checking #1 after the edge, 'detected' should match our ref_state.
            begin
                reg expected;
                expected = (ref_state == 4);
                total = total + 1;
                if (detected !== expected) begin
                    $display("FAIL: din=%b, rst=%b, state=%0d, expected=%b, actual=%b", 
                             din, rst, ref_state, expected, detected);
                end else begin
                    passed = passed + 1;
                end
            end
        end
    endtask

endmodule
