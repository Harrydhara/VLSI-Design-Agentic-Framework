```verilog
module tb;
    // Inputs
    reg clk;
    reg rst_n;
    reg din;

    // Outputs
    wire detected;

    // Instantiate the Design Under Test (DUT)
    seqdet_mealy dut (
        .clk(clk),
        .rst_n(rst_n),
        .din(din),
        .detected(detected)
    );

    // Reference Model State
    // The pattern is 1, 1, 0, 1.
    // Since it's a Mealy machine, the output depends on the current state AND din.
    // We track the history of bits to determine if the sequence was completed.
    reg [3:0] history; // Stores last 4 bits (though we only need 3 for state)

    integer passed;
    integer total;

    // Clock generation
    always #5 clk = ~clk;

    // Helper function to check the Mealy output based on specification
    // Specification: "detected is 1 exactly when the last three bits sampled... 
    // were 1, 1, 0 and din is currently 1"
    functionally_check(input current_din, input [3:0] hist);
        reg expected;
        begin
            // The history contains bits sampled on previous clock edges.
            // To detect 1-1-0-1:
            // If the last three bits (before this din) were 1, 1, 0 AND current din is 1.
            // We use a sliding window approach in the testbench logic.
            expected = (hist[2] == 1'b1 && hist[1] == 1'b1 && hist[0] == 1'b0 && current_din == 1'b1);
            
            if (detected !== expected) begin
                $display("FAIL: din=%b, history=%b[2:0], expected=%b, actual=%b", 
                         current_din, hist[2:0], expected, detected);
                total = total + 1; // This is handled by the caller logic to avoid double counting
            end else begin
                passed = passed + 1;
            end
            total = total + 1;
        end
    endfunction

    // Because Mealy output changes immediately with din, we must check 
    // whenever din changes OR clk rises.
    
    task check_output();
        reg expected;
        begin
            // The "history" for the Mealy logic is the sequence of bits sampled on previous edges.
            // We track this in a shift register 'hist' updated only on rising edges.
            expected = (history[2] == 1'b1 && history[1] == 1'b1 && history[0] == 1'b0 && din == 1'b1);
            if (detected !== expected) begin
                $display("FAIL: din=%b, hist_bits=%b%b%b, expected=%b, actual=%b", 
                         din, history[2], history[1], history[0], expected, detected);
                total = total + 1;
            end else begin
                passed = passed + 1;
                total = total + 1;
            end
        end
    endtask

    // Since the requirement is to count checks: we will check every time din changes 
    // and every time clk rises (to capture state transitions).
    // However, a simpler way for a testbench is to monitor 'detected' continuously.

    initial begin
        // Initialize
        clk = 0;
        rst_n = 0;
        din = 0;
        history = 4'b0000;
        passed = 0;
        total = 0;

        // Reset sequence
        #15 rst_n = 1;

        // Test Case 1: Basic pattern 1, 1, 0, 1
        // We must check 'detected' whenever din changes (Mealy property)
        apply_bit(1); // hist becomes 0001
        apply_bit(1); // hist becomes 0011
        apply_bit(0); // hist becomes 0110
        apply_bit(1); // hist becomes 1101 -> detected should be 1 here

        // Test Case 2: Overlapping pattern 1, 1, 0, 1, 1, 0, 1
        // Resetting to clear history for clean test
        apply_bit(0); // hist becomes 1010 (not relevant)
        apply_bit(1); // 1
        apply_bit(1); // 11
        apply_bit(0); // 110
        apply_bit(1); // 1101 -> detected=1
        apply_bit(1); // 1011
        apply_bit(0); // 0110
        apply_bit(1); // 1101 -> detected=1

        // Test Case 3: Reset during pattern
        apply_bit(1);
        apply_bit(1);
        #2 rst_n = 0; // Async reset
        #2 rst_n = 1;
        // After reset, history should be cleared. din=1 shouldn't trigger anything.
        apply_bit(1); 

        // Test Case 4: Corner cases - rapid changes
        apply_bit(0);
        apply_bit(1);
        apply_bit(1);
        apply_bit(0);
        apply_bit(1); // Should trigger

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

    // Task to apply a bit and verify output
    task apply_bit(input b);
        begin
            din = b;
            // Check Mealy output immediately when din changes
            check_mealy();
            
            @(posedge clk);
            // On clock edge, the history updates. 
            // But we must check BEFORE updating history for the current bit? 
            // No, the specification says "last three bits sampled... and din is currently 1".
            // So 'history' should represent the bits sampled on PREVIOUS edges.
            
            // Update history: shift in the bit that was just sampled
            history = {history[2:0], din};
            
            // Check output again after clock edge (in case state changed)
            check_mealy();
        end
    endtask

    task check_mealy();
        reg expected;
        begin
            // The history bits are the ones sampled on PREVIOUS rising edges.
            // If we just applied din, and we haven't hit the next posedge yet,
            // 'history' contains the 3 previous bits.
            expected = (history[2] == 1'b1 && history[1] == 1'b1 && history[0] == 1'b0 && din == 1'b1);
            if (detected !== expected) begin
                $display("FAIL: din=%b, hist_bits=%b%b%b, expected=%b, actual=%b", 
                         din, history[2], history[1], history[0], expected, detected);
                total = total + 1;
            end else begin
                passed = passed + 1;
                total = total + 1;
            end
        end
    endtask

    // Monitor for asynchronous reset impact on output
    always @(negedge rst_n) begin
        // When rst_n goes low, the detector forgets. 
        // The specification says "immediately forgets". 
        // This implies 'detected' should go to 0 if it was 1.
        if (detected !== 0) begin
            $display("FAIL: Async reset failed to clear detected. din=%b, detected=%b", din, detected);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end
        // Reset history for the testbench model
        history = 4'b0000;
    end

endmodule
```

Wait, I see a logic error in my `apply_bit` and `check_mealy` interaction regarding how many times I increment `total`. Let me rewrite the testbench to be much cleaner and strictly follow the "Apply inputs and compare every output" rule.

```verilog
module tb;
    reg clk;
    reg rst_n;
    reg din;
    wire detected;

    seqdet_mealy dut (
        .clk(clk),
        .rst_n(rst_n),
        .din(din),
        .detected(detected)
    );

    integer passed;
    integer total;
    reg [3:0] history; // bits sampled on previous clock edges

    always #5 clk = ~clk;

    // The reference model for Mealy output:
    // detected is 1 if (last three bits were 1,1,0) AND current din is 1.
    functionally_check();
    
    // We will use a continuous monitor to catch any change in 'detected'
    // and compare it against our reference model.
    // However, the specification says "Apply inputs and compare every output".
    // A more robust way: check whenever din changes OR clk rises.

    initial begin
        clk = 0;
        rst_n = 0;
        din = 0;
        history = 4'b0000;
        passed = 0;
        total = 0;

        // Reset
        #15 rst_n = 1;
        
        // Test Sequence: 1, 1, 0, 1, 1, 0, 1 (Overlapping)
        // Pattern bits: 1 -> 1 -> 0 -> 1 (detect) -> 1 -> 0 -> 1 (detect)
        run_test(1);
        run_test(1);
        run_test(0);
        run_test(1); // Should detect
        run_test(1);
        run_test(0);
        run_test(1); // Should detect

        // Test Reset during pattern: 1, 1, (reset), 0, 1
        run_test(1);
        run_test(1);
        #2 rst_n = 0;
        #2 rst_n = 1;
        run_test(0);
        run_test(1);

        // Test rapid din changes (Mealy)
        run_test(1);
        run_test(1);
        run_test(0);
        run_test(1); // detect

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

    task run_test(input b);
        begin
            din = b;
            // 1. Check Mealy output immediately after din change
            check_output();
            
            // 2. Wait for clock edge to sample the bit
            @(posedge clk);
            
            // 3. Update history: The bit 'b' is now part of the "sampled" bits
            history = {history[2:0], din};
            
            // 4. Check output again after state transition (if any)
            check_output();
        end
    endtask

    task check_output();
        reg expected;
        begin
            // The history contains bits sampled on previous clock edges.
            // For a Mealy machine, the 'state' is determined by the last 3 bits.
            // If we are between clock edges, 'history[2:0]' represents the 3 most recent bits.
            expected = (history[2] == 1'b1 && history[1] == 1'b1 && history[0] == 1'b0 && din == 1'b1);
            
            if (detected !== expected) begin
                $display("FAIL: din=%b, hist=%b%b%b, exp=%b, act=%b", din, history[2], history[1], history[0], expected, detected);
                total = total + 1;
            end else begin
                passed = passed + 1;
                total = total + 1;
            end
        end
    endtask

    // Handle asynchronous reset check
    always @(negedge rst_n) begin
        // When reset happens, history is cleared and output must be 0.
        history = 4'b0000;
        if (detected !== 1'b0) begin
            $display("FAIL: Async reset failed to clear detected. din=%b, det=%b", din, detected);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end
    end

endmodule
```

Wait, the `check_output` logic in my second attempt is slightly flawed because I'm incrementing `total` inside a task that might be called multiple times for one "event". Let me refine it into a single clean module.

```verilog
module tb;
    reg clk;
    reg rst_n;
    reg din;
    wire detected;

    seqdet_mealy dut (
        .clk(clk),
        .rst_n(rst_n),
        .din(din),
        .detected(detected)
    );

    integer passed;
    integer total;
    reg [2:0] history; // Stores the last 3 bits sampled on clock edges

    always #5 clk = ~clk;

    // Reference model for Mealy output
    functionally_check();

    initial begin
        clk = 0;
        rst_n = 0;
        din = 0;
        history = 3'b000;
        passed = 0;
        total = 0;

        // Initial Reset
        #15 rst_n = 1;

        // Test Case: Overlapping pattern 1, 1, 0, 1, 1, 0, 1
        // Bits: 1 (h:001), 1 (h:011), 0 (h:110), 1 (h:101, det=1), 1 (h:011), 0 (h:110), 1 (h:101, det=1)
        // Wait, the history logic is: if din=1 and last three were 1,1,0.
        // Let's trace carefully:
        // Edge 1: din=1 -> hist becomes 001
        // Edge 2: din=1 -> hist becomes 011
        // Edge 3: din=0 -> hist becomes 110
        // Edge 4: din=1 -> history is 110, din is 1 -> DETECTED!
        
        apply_bit(1); // h:001
        apply_bit(1); // h:011
        apply_bit(0); // h:110
        apply_bit(1); // h:101, det=1
        apply_bit(1); // h:011
        apply_bit(0); // h:110
        apply_bit(1); // h:101, det=1

        // Test Case: Reset mid-sequence
        apply_bit(1);
        apply_bit(1);
        #2 rst_n = 0; // Async reset
        #2 rst_n = 1;
        apply_bit(0);
        apply_bit(1);

        // Test Case: No pattern
        apply_bit(0);
        apply_bit(0);
        apply_bit(1);
        apply_bit(1);
        apply_bit(1);
        apply_bit(0);
        apply_bit(0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

    task apply_bit(input b);
    begin
        din = b;
        // Check Mealy output immediately on din change
        verify();
        @(posedge clk);
        history = {history[1:0], din};
        // Check after clock edge (state might have changed)
        verify();
    end
    endtask

    task verify();
    begin
        reg expected;
        expected = (history[2] == 1'b1 && history[1] == 1'b1 && history[0] == 1'b0 && din == 1'b1);
        if (detected !== expected) begin
            $display("FAIL: din=%b, hist=%b%b%b, exp=%b, act=%b", din, history[2], history[1], history[0], expected, detected);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end
    end
    endtask

    // Monitor async reset
    always @(negedge rst_n) begin
        history = 3'b000;
        if (detected !== 1'b0) begin
            $display("FAIL: Async reset failed to clear detected. din=%b, det=%b", din, detected);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end
    end

endmodule
```

Final check on the history logic:
If `history` is