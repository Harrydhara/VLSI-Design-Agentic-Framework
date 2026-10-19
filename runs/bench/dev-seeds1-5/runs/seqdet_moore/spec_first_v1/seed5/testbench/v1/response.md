```verilog
module tb;
    reg clk;
    reg rst;
    reg din;
    wire detected;

    // Instantiate the Design Under Test (DUT)
    seqdet_moore dut (
        .clk(clk),
        .rst(rst),
        .din(din),
        .detected(detected)
    );

    // Reference Model State Variables
    // The pattern is 1, 0, 1, 1
    // States: 0 (init), 1 (got 1), 2 (got 10), 3 (got 101), 4 (got 1011)
    integer state;
    reg expected_detected;

    // Simulation parameters
    integer passed;
    integer total;

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Reference Model Logic
    // The reference model updates on the rising edge, just like a synchronous circuit.
    // Since it's Moore, 'detected' is determined by the state reached AFTER the transition.
    always @(posedge clk) begin
        if (rst) begin
            state <= 0;
        end else begin
            case (state)
                0: if (din == 1) state <= 1; else state <= 0;
                1: if (din == 0) state <= 2; else state <= 1;
                2: if (din == 1) state <= 3; else state <= 0;
                3: if (din == 1) state <= 4; else if (din == 0) state <= 2; else state <= 1; // Note: overlap logic
                   // Wait, let's re-evaluate the pattern transition for overlapping 1011.
                   // If we are in state 3 (got 101) and get a 1 -> state 4 (got 1011).
                   // From state 4 (got 1011), if next bit is 0: sequence becomes ...110 -> pattern 10... so state 2.
                   // If next bit is 1: sequence becomes ...111 -> pattern 1... so state 1.
                   // Let's refine the FSM for overlapping 1,0,1,1:
                   // State 0: ""
                   // State 1: "1"
                   // State 2: "10"
                   // State 3: "101"
                   // State 4: "1011" (Detected)
                end
            endcase
        end
    end

    // Corrected Reference Model Logic for Overlapping 1,0,1,1
    // Pattern: 1 -> 0 -> 1 -> 1
    // Transitions:
    // S0 --(1)--> S1, --(0)--> S0
    // S1 --(0)--> S2, --(1)--> S1
    // S2 --(1)--> S3, --(0)--> S0
    // S3 --(1)--> S4, --(0)--> S2
    // S4 (Moore output 1):
    //   If next is 1: sequence ends in ...11. Pattern "1" is state 1.
    //   If next is 0: sequence ends in ...110. Pattern "10" is state 2.
    // Wait, the spec says overlapping 1 0 1 1 0 1 1 -> detected at 4th and 7th bit.
    // Let's trace 1 0 1 1 0 1 1:
    // Bits: 1 (S1), 0 (S2), 1 (S3), 1 (S4, det=1), 0 (S2), 1 (S3), 1 (S4, det=1).
    // This matches the spec.

    reg [3:0] history; // To track bits for reference model calculation

    task check_output;
        begin
            if (detected !== expected_detected) begin
                $display("FAIL: din=%b, rst=%b, expected detected=%b, actual detected=%b", din, rst, expected_detected, detected);
                total = total + 1;
            end else begin
                passed = passed + 1;
                total = total + 1;
            end
        end
    endtask

    // We will use a simpler approach for the reference model: 
    // Maintain a shift register of the last 4 bits and check it.
    // However, 'rst' resets the history.
    reg [3:0] ref_history;
    integer history_len;

    initial begin
        clk = 0;
        rst = 1;
        din = 0;
        passed = 0;
        total = 0;
        ref_history = 4'b0000;
        history_len = 0;

        // Reset sequence
        #10 rst = 0;
    end

    // Reference Model Update Logic
    always @(posedge clk) begin
        if (rst) begin
            ref_history <= 4'b0000;
            history_len <= 0;
            expected_detected <= 0;
        end else begin
            // Shift in din, but only if rst was not high at this edge.
            // The spec says: "on a rising edge with rst = 1 ... the bit on din at that edge is ignored."
            // This means we update history based on the state of rst *at* the edge.
            // Since rst is synchronous, if rst=1 at posedge, we reset.
            // If rst=0 at posedge, we shift.
            
            // We need to know what the 'expected_detected' will be for the NEXT cycle.
            // Because it's Moore, detected depends on current state.
            // Let's simulate the FSM transitions.
        end
    end

    // Re-writing testbench with a more robust driver/monitor approach
    // Using a task to drive bits and check results.
    
    task drive_bit(input b);
        begin
            din = b;
            @(posedge clk);
            #1; // Wait for signals to settle after edge
            // Update reference model manually based on the bit just sampled
            if (rst) begin
                history_len = 0;
                ref_history = 4'b0000;
            end else begin
                history_len = history_len + 1;
                ref_history = {ref_history[2:0], b};
                if (history_len > 4) history_len = 4;
            end

            // Calculate expected Moore output for the state we just entered
            // The output 'detected' is high if the last 4 bits were 1,0,1,1
            if (history_len == 4 && ref_history == 4'b1011)
                expected_detected = 1;
            else
                expected_detected = 0;

            // Check DUT output against reference model
            // Note: The Moore output changes right after the rising edge.
            // Since we are at #1 after posedge, 'detected' should reflect the new state.
            if (detected !== expected_detected) begin
                $display("FAIL: din=%b, rst=%b, expected detected=%b, actual detected=%b", b, rst, expected_detected, detected);
                total = total + 1;
            end else begin
                passed = passed + 1;
                total = total + 1;
            end
        end
    endtask

    // Redefining the test logic to avoid confusion with 'always' blocks
    initial begin
        // Wait for initial reset
        @(posedge clk);
        #1;
        rst = 1;
        din = 0;
        @(posedge clk);
        #1;
        rst = 0;
        
        // Test Case 1: Basic pattern 1, 0, 1, 1
        drive_bit(1);
        drive_bit(0);
        drive_bit(1);
        drive_bit(1); // Should detect

        // Test Case 2: Overlapping pattern 1, 0, 1, 1, 0, 1, 1
        // We are currently at the end of 1011. Next bits should be 0, 1, 1
        drive_bit(0);
        drive_bit(1);
        drive_bit(1); // Should detect again

        // Test Case 3: Reset mid-sequence
        drive_bit(1);
        drive_bit(0);
        @(posedge clk);
        #1;
        rst = 1;
        @(posedge clk);
        #1;
        rst = 0;
        // After reset, history is gone.
        drive_bit(1);
        drive_bit(0);
        drive_bit(1);
        drive_bit(1); // Should detect

        // Test Case 4: Random bits and no detection
        drive_bit(0);
        drive_bit(0);
        drive_bit(1);
        drive_bit(1);
        drive_bit(1);
        drive_bit(0);

        // Test Case 5: Corner case - all ones
        drive_bit(1);
        drive_bit(1);
        drive_bit(1);
        drive_bit(1); // Should not detect (pattern is 1011)
        
        // Test Case 6: Pattern at the very end of a stream
        drive_bit(1);
        drive_bit(0);
        drive_bit(1);
        drive_bit(1);

        #20;
        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

    // Override the previous logic to use a clean single-loop approach
    // The 'always' blocks above are messy. Let's restart the simulation logic inside this block.
endmodule
```

Wait, I must provide exactly one code block and follow all rules. Let me rewrite the testbench properly from scratch in the final response format.

```verilog
module tb;
    reg clk;
    reg rst;
    reg din;
    wire detected;

    seqdet_moore dut (
        .clk(clk),
        .rst(rst),
        .din(din),
        .detected(detected)
    );

    integer passed;
    integer total;
    
    // Reference Model variables
    reg [3:0] ref_history;
    integer history_len;
    reg expected_det;

    initial begin
        clk = 0;
        rst = 0;
        din = 0;
        passed = 0;
        total = 0;
        ref_history = 4'b0000;
        history_len = 0;
        expected_det = 0;

        // Reset the system
        @(posedge clk);
        rst = 1;
        din = 0;
        @(posedge clk);
        #1; // Wait for sync reset to take effect
        rst = 0;
        history_len = 0;
        ref_history = 4'b0000;
        expected_det = 0;

        // Test sequence: 1, 0, 1, 1 (Detection)
        apply_input(1);
        apply_input(0);
        apply_input(1);
        apply_input(1); // Detected here

        // Test sequence: Overlap 1, 0, 1, 1, 0, 1, 1 (Detection at 4th and 7th)
        // Current state is end of 1011. Next bits are 0, 1, 1
        apply_input(0);
        apply_input(1);
        apply_input(1); // Detected here

        // Test sequence: Reset mid-pattern
        apply_input(1);
        apply_input(0);
        @(posedge clk);
        #1;
        rst = 1;
        din = 1; // This bit should be ignored per spec
        @(posedge clk);
        #1;
        rst = 0;
        history_len = 0;
        ref_history = 4'b0000;
        expected_det = 0;

        // After reset, start pattern again
        apply_input(1);
        apply_input(0);
        apply_input(1);
        apply_input(1); // Detected here

        // Test sequence: No detection (1, 1, 1, 1)
        apply_input(1);
        apply_input(1);
        apply_input(1);
        apply_input(1);

        // Test sequence: Pattern with extra bits at start (0, 1, 0, 1, 1)
        apply_input(0);
        apply_input(1);
        apply_input(0);
        apply_input(1);
        apply_input(1); // Detected here

        #50;
        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

    task apply_input(input b);
        begin
            din = b;
            @(posedge clk);
            // The bit is sampled on the rising edge. 
            // We update our reference model immediately after the edge.
            if (rst) begin
                history_len = 0;
                ref_history = 4'b0000;
                expected_det = 0;
            end else begin
                history_len = history_len + 1;
                if (history_len > 4) history_len = 4;
                ref_history = {ref_history[2:0], b};
                
                if (history_len == 4 && ref_history == 4'b1011)
                    expected_det = 1;
                else
                    expected_det = 0;
            end

            // Check the output. Since it is Moore, 'detected' should be stable 
            // and reflect the state reached after the edge.
            #1; // Small delay to allow DUT to update its output
            if (detected !== expected_det) begin
                $display("FAIL: din=%b, rst=%b, expected detected=%b, actual detected=%b", b, rst, expected_det, detected);
                total = total + 1;
            end else begin
                passed = passed + 1;
                total = total + 1;
            end
        end
    endtask

    always #5 clk = ~clk;

endmodule
```

Wait, I need to make sure the `apply_input` task handles the `rst` correctly. The spec says: "on a rising edge with rst = 1 ... the bit on din at that edge is ignored." My task applies `din`, then waits for `posedge clk`. If `rst` was high during that edge, it resets. This matches.

One detail: In my `apply_input` task, I check `if (rst)`. But `rst` is the value *at* the rising edge. Since I am calling this task after a `#1` delay in previous calls or at the start, I need to be careful about when `rst` is set.

Let's refine the testbench one last time to ensure it's perfect.

```verilog
module tb;
    reg clk;
    reg rst;
    reg din;
    wire detected;

    seqdet_moore dut (
        .clk(clk),
        .rst(rst),
        .din(din),
        .detected(detected)
    );

    integer passed;
    integer total;
    
    // Reference Model variables
    reg [3:0] ref_history;
    integer history_len;
    reg expected_det;

    always #5 clk = ~clk;

    task apply_input(input b);
        begin
            din = b;
            @(posedge clk);
            // After the edge, we evaluate what happened.
            // If rst was 1 at the edge, history is reset and din ignored.
            if (rst) begin
                history_len = 0;
                ref_history = 4'b0000;
                expected_det = 0;
            end else begin
                history_len = history_len + 1;
                if (history_len > 4) history_len = 4;
                ref_history = {ref_history[2:0], b};
                
                if (history_len == 4 && ref_history == 4'b1011)
                    expected_det = 1;
                else
                    expected_det = 0;
            end

            #1; // Wait for Moore output to settle
            if (detected !== expected_det) begin
                $display("FAIL: din=%b, rst=%b, expected detected=%b, actual detected=%b", b, rst, expected_det, detected);
                total = total + 1;
            end else begin
                passed = passed + 1;
                total = total + 1;
            end
        end
    endtask

    initial begin
        // Initialize
        clk = 0;
        rst = 0;
        din = 0;
