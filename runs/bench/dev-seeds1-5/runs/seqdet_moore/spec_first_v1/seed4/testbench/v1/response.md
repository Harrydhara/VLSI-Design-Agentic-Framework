```verilog
module tb;
    // Inputs
    reg clk;
    reg rst;
    reg din;

    // Outputs
    wire detected;

    // Instantiate the design under test
    seqdet_moore uut (
        .clk(clk),
        .rst(rst),
        .din(din),
        .detected(detected)
    );

    // Reference Model State Variables
    // The pattern is 1, 0, 1, 1
    // We use a shift register to track the last 4 bits
    reg [3:0] history;
    integer passed;
    integer total;

    // Clock generation
    always #5 clk = ~clk;

    // Task to drive input and check output
    task drive_bit(input bit_val);
        begin
            @(posedge clk);
            #1; // Wait for synchronous reset/input to settle after edge
            if (rst) begin
                history = 4'b0000;
            end else begin
                // Shift in the new bit. 
                // The spec says: "The bit on din at that [reset] edge is ignored."
                // This implies reset happens, then we start fresh.
                // We track history as [oldest, ..., newest]
                history = {history[2:0], bit_val};
            end
            din = bit_val;
            
            // The Moore output 'detected' depends on the state AFTER the edge.
            // Since it is a Moore machine, we check the output after the clock edge has passed.
            // We wait for the signal to stabilize (after the combinational logic settles).
            #0; 

            // Reference Model Logic:
            // Pattern is 1, 0, 1, 1.
            // Note: The history register above tracks bits. 
            // If rst was high at the edge, we ignore din and reset state.
            // However, 'detected' is Moore, so it reflects the state reached AFTER the edge.
            
            // We need to calculate what the expected output should be based on the sequence.
            // Because it's a Moore machine, if the pattern was completed at this edge, 
            // detected will be high in the next cycle.
            
            // Let's use a more robust reference model: a state-based one.
        end
    endtask

    // Refined Reference Model approach:
    // We simulate the FSM transitions to determine expected 'detected'.
    // States: 0 (IDLE), 1 (got 1), 2 (got 1,0), 3 (got 1,0,1), 4 (got 1,0,1,1)
    integer state;
    reg expected_detected;

    initial begin
        // Initialize
        clk = 0;
        rst = 0;
        din = 0;
        state = 0;
        expected_detected = 0;
        passed = 0;
        total = 0;
        history = 4'b0000;

        // Reset sequence
        @(posedge clk);
        rst = 1;
        din = 0;
        #10; // Wait for one cycle
        rst = 0;
        state = 0;
        expected_detected = 0;

        // Test Case 1: Basic pattern detection (1, 0, 1, 1)
        check_sequence({1, 0, 1, 1});

        // Test Case 2: Overlapping patterns (1, 0, 1, 1, 0, 1, 1)
        // Pattern ends at index 4 and index 7.
        check_sequence({1, 0, 1, 1, 0, 1, 1});

        // Test Case 3: Reset mid-sequence
        check_sequence({1, 0, 1, 1}); // complete first
        @(posedge clk);
        rst = 1; din = 1; // reset at edge. bit 1 ignored.
        #10;
        rst = 0; din = 0; // sequence: (reset) 0...
        check_sequence({1, 1}); // should not trigger

        // Test Case 4: Random noise
        check_sequence({0, 0, 0, 1, 1, 1, 0, 1, 1});

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

    // Helper to run a sequence of bits
    task check_sequence(input [7:0] seq);
        integer i;
        begin
            for (i = 7; i >= 0; i = i - 1) begin
                din = seq[i];
                @(posedge clk);
                #1; // Wait for synchronous logic to process din/rst
                
                // Update Reference Model State
                if (rst) begin
                    state = 0;
                end else begin
                    case (state)
                        0: if (din == 1) state = 1; else state = 0;
                        1: if (din == 0) state = 2; else state = 1;
                        2: if (din == 1) state = 3; else state = 0;
                        3: if (din == 1) state = 4; else if (din == 0) state = 2; else state = 0; // Wait, spec says 1,0,1,1. If we get 1,0,1,0 -> back to state 2? No, pattern is 1,0,1,1.
                           // Let's re-evaluate FSM for 1011:
                           // S0 --1--> S1 (1)
                           // S1 --0--> S2 (10)
                           // S1 --1--> S1 (1)
                           // S2 --1--> S3 (101)
                           // S2 --0--> S0 (0)
                           // S3 --1--> S4 (1011) -> detected=1
                           // S3 --0--> S2 (10 is suffix of 1010? No. 10 is suffix of 1010? Yes, "10" is at end.)
                           // Let's use the bit-shift method for the reference model to be safe.
                    endcase
                end

                // Re-implementing Reference Model using shift register logic (more reliable)
                // We need to track the sequence of bits received *excluding* the reset bit.
            end
        end
    endtask

    // Since the task above is getting complex, let's rewrite the testbench 
    // with a very simple, direct simulation-based reference model.

    // REWRITTEN TEST LOGIC
    initial begin
        clk = 0; rst = 0; din = 0;
        passed = 0; total = 0;
        
        // Reset
        @(posedge clk);
        rst = 1; din = 0;
        #10;
        rst = 0; din = 0;
        
        // Test Pattern: 1, 0, 1, 1 (Detect)
        run_test(1); run_test(0); run_test(1); run_test(1); // detected should be 1 after this
        
        // Test Overlap: ... 0, 1, 1 (Detect)
        run_test(0); run_test(1); run_test(1); // detected should be 1 after this

        // Test Reset mid-way: 1, 0, [RESET], 1, 1
        run_test(1); run_test(0);
        @(posedge clk); rst = 1; din = 1; // reset edge. bit 1 ignored.
        #10;
        rst = 0; din = 1;
        run_test(1);

        // Test pattern with wrong bits: 1, 0, 1, 0, 1, 1
        @(posedge clk); rst = 1; din = 0; #10; rst = 0;
        run_test(1); run_test(0); run_test(1); run_test(0); run_test(1); run_test(1);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

    reg [3:0] ref_history; // stores last 4 bits
    reg [3:0] ref_bits;    // used to track sequence for comparison

    task run_test(input bit_val);
        begin
            din = bit_val;
            @(posedge clk);
            #1; // Wait for synchronous update
            
            if (rst) begin
                ref_history <= 4'b0000;
            end else begin
                // Shift in the bit. The history represents the last 4 bits sampled.
                // We use a shift register to track the sequence of bits that were NOT ignored by reset.
                ref_history <= {ref_history[2:0], din};
            end

            // Calculate expected 'detected' based on ref_history
            // The pattern is 1, 0, 1, 1
            expected_detected = (ref_history == 4'b1011);

            // Check output
            total = total + 1;
            if (detected === expected_detected) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: din=%b, rst=%b, history=%b, expected=%b, actual=%b", 
                         bit_val, rst, ref_history, expected_detected, detected);
            end
        end
    endtask

endmodule
```

Wait, I see a potential flaw in my `run_test` logic regarding the timing of `expected_detected`. The spec says: "`detected` is 1 during the clock cycle right after the rising edge at which the last four bits sampled since the reset were 1, 0, 1, 1".
Since it's a Moore machine, if the pattern completes on the edge, the output becomes 1 immediately *after* that edge. My `run_test` checks `#1` after the edge, which is correct for a Moore machine.

Let me refine the testbench to be cleaner and strictly follow the rules.

```verilog
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
```

Wait, I need to be careful with the state transitions for `ref_state` in the task. Let's re-verify:
Pattern: 1, 0, 1, 1
S0 (init) --1--> S1 (1)
S1 --0--> S2 (10)
S1 --1--> S1 (1)
S2 --1--> S3 (101)
S2 --0--> S0 (0)
S3 --1--> S4 (1011) -> detected=1
S3 --0--> S2 (10 is suffix of 1010? Yes: 1,0,1,0 ends in 1,0. So state 2.)
S4 --0--> S2 (10 is suffix of 10110? Yes: 1,0)
S4 --1--> S1 (1 is suffix of 10111? Yes: 1)

Let's refine the `test_bit` task one last time to be absolutely sure.

```verilog
module tb;
    reg clk;
    reg rst;
    reg din;
    wire detected;

    seqdet_moore uut (
        .clk(clk),
        .rst(rst),