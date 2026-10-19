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
    // Pattern: 1, 0, 1, 1
    // We use a shift register to track the last 4 bits seen (excluding reset cycles)
    reg [3:0] history;
    integer history_len;
    integer passed;
    integer total;

    // Clock generation
    always #5 clk = ~clk;

    // Task to drive input and check output
    task drive_bit(input bit_val);
        begin
            din = bit_val;
            @(posedge clk);
            // The specification says: "detected is 1 during the clock cycle right after 
            // the rising edge at which the last four bits sampled... were 1,0,1,1"
            // Since it's a Moore machine, we check 'detected' AFTER the edge.
            // However, rst is synchronous: "on a rising edge with rst=1 ... bit on din is ignored."
            
            if (rst) begin
                history <= 4'b0000;
                history_len <= 0;
            end else begin
                // Shift in the new bit
                history <= {history[2:0], bit_val};
                if (history_len < 4) 
                    history_len <= history_len + 1;
                else 
                    history_len <= 4;
            end

            // Calculate expected value based on the state AFTER the edge
            // The pattern is detected if the last 4 bits are 1011
            // Note: rst logic means we only update history if rst was 0 at the edge.
            // But the check happens after the edge. If rst was high, history resets.
            
            // We need to simulate the reference model's state transition carefully.
            // Let's use a separate procedural block or logic for the expected value.
        end
    endtask

    // Because of the synchronous reset and Moore output timing, 
    // it is cleaner to drive bits and then check the result in a controlled loop.

    reg [3:0] ref_history;
    integer ref_len;
    reg expected_detected;

    initial begin
        // Initialize
        clk = 0;
        rst = 0;
        din = 0;
        ref_history = 4'b0000;
        ref_len = 0;
        passed = 0;
        total = 0;

        // Reset sequence
        @(posedge clk);
        rst = 1;
        din = 1; // Should be ignored
        @(posedge clk);
        rst = 0;
        din = 0;
        
        // Test Case 1: Basic pattern 1, 0, 1, 1
        check_sequence({1, 0, 1, 1});

        // Test Case 2: Overlapping patterns 1, 0, 1, 1, 0, 1, 1
        // Pattern 1 ends at index 4. Pattern 2 ends at index 7.
        check_sequence({1, 0, 1, 1, 0, 1, 1});

        // Test Case 3: Reset mid-pattern
        check_sequence({1, 0, 1, 1}); // complete one
        @(posedge clk);
        rst = 1; din = 1; // reset at edge
        @(posedge clk);
        rst = 0; din = 0;
        check_sequence({1, 0, 1, 1});

        // Test Case 4: Random bits and no pattern
        check_sequence({0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 1, 0});

        // Final Summary
        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

    function void check_sequence(input [63:0] seq);
        integer i;
        reg [63:0] s;
        begin
            s = seq;
            // We don't know the length of 'seq' from a 64-bit vector easily, 
            // so we will pass it as an array or just hardcode specific tests.
            // Let's rewrite the test logic to be more robust.
        end
    endfunction

    // Refined Test Logic
    task run_test();
        integer i;
        reg [63:0] pattern;
        integer len;
        begin
            // Reset model
            ref_history = 4'b0000;
            ref_len = 0;

            // Test 1: 1,0,1,1
            pattern = 64'b1011; len = 4;
            for (i=0; i<len; i=i+1) begin
                apply_bit(pattern[len-1-i]);
            end

            // Test 2: Overlap 1,0,1,1,0,1,1
            // Note: The previous test left history at 1011. 
            // To be clean, let's reset before each major block.
            reset_model();
            pattern = 64'b1011011; len = 7;
            for (i=0; i<len; i=i+1) begin
                apply_bit(pattern[len-1-i]);
            end

            // Test 3: Reset mid-sequence
            reset_model();
            apply_bit(1); apply_bit(0); apply_bit(1); // history 101, len 3
            @(posedge clk); rst = 1; din = 1; // reset edge
            @(posedge clk); rst = 0; din = 0; // history 0, len 0
            pattern = 64'b1011; len = 4;
            for (i=0; i<len; i=i+1) begin
                apply_bit(pattern[len-1-i]);
            end

            // Test 4: Long sequence with multiple detections
            reset_model();
            // 1,0,1,1, 1,0,1,1 (two patterns, no overlap between these two)
            pattern = 64'b10111011; len = 8;
            for (i=0; i<len; i=i+1) begin
                apply_bit(pattern[len-1-i]);
            end
        end
    endtask

    // Helper to apply bit and check
    task apply_bit(input b);
        begin
            din = b;
            @(posedge clk);
            // After the edge, update reference model
            if (rst) begin
                ref_history = 4'b0000;
                ref_len = 0;
            end else begin
                ref_history = {ref_history[2:0], b};
                if (ref_len < 4) ref_len = ref_len + 1;
                else ref_len = 4;
            end

            // Determine expected Moore output
            expected_detected = (ref_len == 4 && ref_history == 4'b1011) ? 1'b1 : 1'b0;

            total = total + 1;
            if (detected !== expected_detected) begin
                $display("FAIL: din=%b, rst=%b, expected=%b, actual=%b", b, rst, expected_detected, detected);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    task reset_model();
        begin
            @(posedge clk);
            rst = 1; din = 0;
            @(posedge clk);
            rst = 0; din = 0;
            ref_history = 4'b0000;
            ref_len = 0;
        end
    endtask

    // Start the test execution
    initial begin
        // Wait for clock to stabilize
        #10;
        run_test();
        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```

Wait, I noticed a small error in my manual logic flow inside the `apply_bit` task. The Moore output depends on the state *after* the transition. My `apply_bit` task performs: 1) Set input, 2) Wait for edge, 3) Update reference model based on that edge, 4) Compare DUT output (which is now reflecting the new state). This matches the specification.

However, I need to ensure the `run_test` logic doesn't conflict with the `initial` block. I will consolidate it into one clean structure.

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

    reg [3:0] ref_history;
    integer ref_len;
    integer passed;
    integer total;

    always #5 clk = ~clk;

    task apply_bit(input b);
        begin
            din = b;
            @(posedge clk);
            // The synchronous reset happens at the edge. 
            // If rst was high at the rising edge, history is cleared and din ignored.
            if (rst) begin
                ref_history = 4'b0000;
                ref_len = 0;
            end else begin
                ref_history = {ref_history[2:0], b};
                if (ref_len < 4) ref_len = ref_len + 1;
                else ref_len = 4;
            end

            // Moore output is based on the state reached AFTER the edge.
            // We check 'detected' immediately after the edge.
            total = total + 1;
            if (ref_len == 4 && ref_history == 4'b1011) begin
                if (detected !== 1'b1) begin
                    $display("FAIL: din=%b, rst=%b, expected=1, actual=%b", b, rst, detected);
                end else begin
                    passed = passed + 1;
                end
            end else begin
                if (detected !== 1'b0) begin
                    $display("FAIL: din=%b, rst=%b, expected=0, actual=%b", b, rst, detected);
                end else begin
                    passed = passed + 1;
                end
            end
        end
    endtask

    task reset_dut();
        begin
            @(posedge clk);
            rst = 1; din = 0;
            @(posedge clk);
            rst = 0; din = 0;
            ref_history = 4'b0000;
            ref_len = 0;
        end
    endtask

    initial begin
        clk = 0; rst = 0; din = 0;
        passed = 0; total = 0;
        ref_history = 4'b0000; ref_len = 0;

        // Test Case 1: Simple pattern
        reset_dut();
        apply_bit(1); apply_bit(0); apply_bit(1); apply_bit(1); // Should detect

        // Test Case 2: Overlapping patterns (1,0,1,1,0,1,1)
        reset_dut();
        apply_bit(1); apply_bit(0); apply_bit(1); apply_bit(1); // Detects
        apply_bit(0); apply_bit(1); apply_bit(1);             // Detects again

        // Test Case 3: Reset mid-pattern
        reset_dut();
        apply_bit(1); apply_bit(0); apply_bit(1); // History 101
        @(posedge clk); rst = 1; din = 1;         // Reset edge (din ignored)
        @(posedge clk); rst = 0; din = 0;         // After reset, history is empty
        apply_bit(1); apply_bit(0); apply_bit(1); apply_bit(1); // Detects

        // Test Case 4: No pattern
        reset_dut();
        apply_bit(0); apply_bit(1); apply_bit(1); apply_bit(1); apply_bit(0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
```

Final check on the "overlapping" requirement: `1 0 1 1 0 1 1`.
Bits:
1: hist=1, len=1
2: hist=10, len=2
3: hist=101, len=3
4: hist=1011, len=4 -> detected=1
5: hist=0110, len=4 -> detected=0 (Wait, the pattern is 1011. If we shift in a 0, history becomes 0110)
6: hist=1101, len=4 -> detected=0
7: hist=1011, len=4 -> detected=1
This matches my `apply_bit` logic and the spec's example.

One detail: "The bit on din at that edge is ignored" during reset. My code handles this by checking `if (rst)` inside the task which executes *after* the edge has occurred, effectively simulating the synchronous behavior where the state transition for `rst=1` results in a reset state regardless of `din`.

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

    reg [3:0] ref_history;
    integer ref_len;
    integer passed;
    integer total;

    always #5 clk = ~clk;

    task apply_bit(input b);
        begin
            din = b;
            @(posedge clk);
            if (rst) begin
                ref_history = 4'b0000;
                ref_len = 0;
            end else begin
                ref_history = {ref_history[2:0], b};
                if (ref_len < 4) ref_len = ref_len + 1;
                else ref_len = 4;
            end

            total = total + 1;
            if (ref_len == 4 && ref_history == 4'b1011) begin
                if (detected !== 1'b1) begin
                    $display("FAIL: din=%b, rst=%b, expected=1, actual=%b", b, rst, detected);
                end else begin
                    passed = passed + 1;
                end
            end else begin
                if (detected !== 1'b0) begin
                    $display("FAIL: din=%b, rst=%b, expected=0, actual=%b", b, rst, detected);
                end else begin
                    passed = passed + 1;
                end
            end
        end
    endtask

    task reset_dut();
        begin
            @(posedge clk);
            rst = 1; din = 0;
            @(posedge clk);
            rst = 0; din = 0;
            ref_history = 4'b0000;
            ref_len = 0;
        end
    endtask

    initial begin
        clk = 0; rst = 0; din = 0;
        passed = 0; total = 0;
        ref_history = 4'b0000; ref_len = 0;

        reset_dut();
        apply_bit(1); apply_bit(0); apply_bit(1); apply_bit(1); 

        reset_dut();
        apply_bit(1); apply_bit(0); apply_bit(1); apply_bit(1); 
        apply_bit(0); apply_bit(1); apply_bit(1); 

        reset_dut();
        apply_bit(1); apply_bit(0); apply_bit(1); 
        @(posedge clk); rst = 1; din = 1;         
        @(posedge clk); rst = 0; din = 0;         
        apply_bit(1); apply_bit(0); apply_bit(1); apply_bit(1); 

        reset_dut();
        apply_bit(0); apply_bit(1); apply_bit(1); apply_bit(1); apply_bit(0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;