```verilog
`timescale 1ns/1ps

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
    // We need to track the history of bits sampled on rising edges.
    // Since it's a Mealy machine, 'detected' depends on current din AND previous bits.
    // The pattern is 1, 1, 0, 1.
    // Let's maintain a shift register of the last 3 bits sampled at clock edges.
    reg [2:0] history; // [bit_n-1, bit_n-2, bit_n-3]

    integer passed;
    integer total;

    // Clock generation
    always #5 clk = ~clk;

    // Helper to check output
    task check_output;
        input expected;
        begin
            if (detected !== expected) begin
                $display("FAIL: din=%b, rst_n=%b, history=%b, expected detected=%b, actual detected=%b", 
                         din, rst_n, history, expected, detected);
                // We don't increment 'passed' here, but we must count the total check.
            end else begin
                passed = passed + 1;
            end
            total = total + 1;
        end
    endtask

    // Function to calculate expected Mealy output based on history and current din
    function detected_ref;
        input [2:0] hist;
        input d;
        begin
            // Pattern is 1, 1, 0 followed by current 1.
            // History stores bits in order: [bit_n-1, bit_n-2, bit_n-3]
            // So history[0] is n-1, history[1] is n-2, history[2] is n-3
            // We need sequence 1 (n-3), 1 (n-2), 0 (n-1) and current din=1.
            if (hist[2] == 1'b1 && hist[1] == 1'b1 && hist[0] == 1'b0 && d == 1'b1)
                detected_ref = 1'b1;
            else
                detected_ref = 1'b0;
        end
    endfunction

    initial begin
        // Initialize
        clk = 0;
        rst_n = 0;
        din = 0;
        history = 3'b000;
        passed = 0;
        total = 0;

        // Asynchronous Reset Test
        #12 rst_n = 1;
        
        // We must check 'detected' continuously because it is Mealy.
        // However, since we are driving din and checking in a procedural block, 
        // we will use a monitor-like approach or check after every change.

        // Test Case 1: Basic sequence 1, 1, 0, 1
        send_bit(1); // history becomes 001 (after edge)
        send_bit(1); // history becomes 011
        send_bit(0); // history becomes 110
        send_bit(1); // history becomes 101, detected should be 1 during this din=1

        // Test Case 2: Overlapping sequence 1, 1, 0, 1, 1, 0, 1
        // Current state after Case 1: history is 101 (from bits 1,0,1)
        // To get overlapping 1,1,0,1: we need to have just finished a pattern.
        // The sequence was ...1, 1, 0, 1. Next bits for overlap: 1, 0, 1.
        // Wait, the spec says: "For input 1 1 0 1 1 0 1, detected is 1 while 4th bit is on din and again while 7th bit is on din"
        // Let's just run that exact sequence.
        
        $display("Starting Sequence Test...");
        reset_system();
        send_bit(1); // 1
        send_bit(1); // 1, 1
        send_bit(0); // 1, 1, 0
        send_bit(1); // 1, 1, 0, 1 -> DETECTED!
        send_bit(1); // 1, 0, 1, 1
        send_bit(0); // 0, 1, 1, 0
        send_bit(1); // 1, 1, 0, 1 -> DETECTED!

        // Test Case 3: Reset during sequence
        reset_system();
        send_bit(1);
        send_bit(1);
        #2 rst_n = 0;
        // Check that detected is 0 immediately upon reset (if it was high, which it isn't here)
        // and history is cleared.
        #2 rst_n = 1;
        send_bit(1);
        send_bit(1);
        send_bit(0);
        send_bit(1); // Should not detect because reset wiped the first two 1s

        // Test Case 4: Mealy behavior (change din without clock)
        reset_system();
        send_bit(1);
        send_bit(1);
        send_bit(0);
        // Now history is 011. If we set din=1, detected should go high immediately.
        din = 1;
        #1; // Small delay to allow combinational propagation
        check_output(1);
        // If we change din back to 0, detected should go low immediately.
        din = 0;
        #1;
        check_output(0);
        // Now sync with clock to finish the bit
        @(posedge clk);
        update_history();

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

    // Task to send a bit synchronously and check output
    task send_bit;
        input b;
        begin
            din = b;
            // Mealy check: check before clock edge (for the current din)
            check_output(detected_ref(history, din));
            
            @(posedge clk);
            update_history();
            
            // Check after clock edge to ensure state updated correctly 
            // and output is still correct for the new state/din
            check_output(detected_ref(history, din));
        end
    endtask

    task update_history;
        begin
            // The history represents bits sampled on PREVIOUS rising edges.
            // When a rising edge occurs, the 'din' that was present is now the "newest" bit.
            // However, our send_bit task calls this AFTER the edge.
            // We need to capture the value of din that was present AT the edge.
            // Since we are in a testbench, we can track what we sent.
            // Let's use a temporary variable to store the bit being sampled.
        end
    endtask

    // Redefining logic for cleaner testbench:
    // We will manually control history and check output at every change of din or clk.
endmodule
```

Wait, I need to rewrite the testbench more robustly to handle the Mealy requirement (checking on any `din` change) and the asynchronous reset correctly.

```verilog
`timescale 1ns/1ps

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

    // Reference Model State
    // history[0] is bit n-1, history[1] is bit n-2, history[2] is bit n-3
    reg [2:0] history; 
    integer passed;
    integer total;

    function detected_ref;
        input [2:0] hist;
        input d;
        begin
            if (hist[2] == 1'b1 && hist[1] == 1'b1 && hist[0] == 1'b0 && d == 1'b1)
                detected_ref = 1'b1;
            else
                detected_ref = 1'b0;
        end
    endfunction

    // Monitor changes in din or detected to verify Mealy property
    // But since we are driving, we will check manually.

    task check_val;
        input expected;
        begin
            if (detected !== expected) begin
                $display("FAIL: din=%b, rst_n=%b, history=%b, expected detected=%b, actual detected=%b", 
                         din, rst_n, history, expected, detected);
            end else begin
                passed = passed + 1;
            end
            total = total + 1;
        end
    endtask

    // We'll use a more controlled approach.
    // Every time din changes OR clk rises, we check the output against the ref model.
    
    initial begin
        clk = 0;
        rst_n = 0;
        din = 0;
        history = 3'b000;
        passed = 0;
        total = 0;

        // Reset sequence
        #15 rst_n = 1;
        
        // Test Case: Overlapping pattern 1, 1, 0, 1, 1, 0, 1
        // We will drive din and check output at every change.
        
        apply_bit(1); // bit 1
        apply_bit(1); // bit 2
        apply_bit(0); // bit 3
        apply_bit(1); // bit 4 -> detected should be 1
        apply_bit(1); // bit 5
        apply_bit(0); // bit 6
        apply_bit(1); // bit 7 -> detected should be 1

        // Test Case: Reset mid-sequence
        apply_bit(1);
        apply_bit(1);
        #3 rst_n = 0;
        // Check immediate reset effect on output (should be 0)
        if (detected !== 1'b0) begin
             $display("FAIL: Reset failed to clear output. din=%b, expected=0, actual=%b", din, detected);
             total = total + 1; // Manual count for reset failure
        end else begin
             passed = passed + 1;
             total = total + 1;
        end
        // Reset history in ref model
        history = 3'b000;
        #5 rst_n = 1;

        // Test Case: Mealy combinational check
        // Sequence: 1, 1, 0. History becomes 011.
        apply_bit(1);
        apply_bit(1);
        apply_bit(0);
        // Now history is 011. If we change din to 1, detected must go high immediately.
        din = 1;
        #1; // Wait for combinational logic
        if (detected !== 1'b1) begin
            $display("FAIL: Mealy output did not respond to din change. din=%b, history=%b, expected=1, actual=%b", din, history, detected);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end
        // Change din to 0, detected must go low immediately.
        din = 0;
        #1;
        if (detected !== 1'b0) begin
            $display("FAIL: Mealy output did not respond to din change. din=%b, history=%b, expected=0, actual=%b", din, detected);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end
        // Sync with clock to finish the bit
        @(posedge clk);
        update_history(din);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

    task apply_bit;
        input b;
        begin
            din = b;
            // Check Mealy output immediately after din change
            if (detected !== detected_ref(history, din)) begin
                $display("FAIL: Mealy output mismatch on din change. din=%b, history=%b, expected=%b, actual=%b", 
                         din, history, detected_ref(history, din), detected);
                total = total + 1;
            end else begin
                passed = passed + 1;
                total = total + 1;
            end

            @(posedge clk);
            update_history(din);

            // Check output after clock edge (state transition)
            if (detected !== detected_ref(history, din)) begin
                $display("FAIL: Mealy output mismatch after clock. din=%b, history=%b, expected=%b, actual=%b", 
                         din, history, detected_ref(history, din), detected);
                total = total + 1;
            end else begin
                passed = passed + 1;
                total = total + 1;
            end
        end
    endtask

    task update_history;
        input b;
        begin
            // Shift in the bit that was just sampled at the rising edge
            history = {b, history[1:0]}; // This is wrong. History should be [n-1, n-2, n-3]
            // Let's fix: 
            // If current bit is b (at index n), then new history for next cycle is:
            // hist_new[0] = b
            // hist_new[1] = hist_old[0]
            // hist_new[2] = hist_old[1]
        end
    endtask

    // Let's rewrite the task logic one more time to be perfect.
endmodule
```

Final attempt at a clean, correct testbench:

```verilog
`timescale 1ns/1ps

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

    // Reference Model State: history[0]=bit_{n-1}, history[1]=bit_{n-2}, history[2]=bit_{n-3}
    reg [2:0] history; 
    integer passed;
    integer total;

    function detected_ref;
        input [2:0] hist;
        input d;
        begin
            if (hist[2] == 1'b1 && hist[1] == 1'b1 && hist[0] == 1'b0 && d == 1'b1)
                detected_ref = 1'b1;
            else
                detected_ref = 1'b0;
        end
    endfunction

    task check_val;
        input expected;
        begin
            if (detected !== expected) begin
                $display("FAIL: din=%b, rst_n=%b, history=%b, expected detected=%b, actual detected=%b", 
                         din, rst_n, history, expected, detected);
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
        history = 3'b000;
        passed = 0;
        total = 0;

        // Reset
        #12 rst_n = 1;

        // Test Case: Overlapping pattern 1, 1, 0, 1, 1, 0, 1
        // Sequence of bits to apply: 1, 1, 0, 1, 1, 0, 1
        apply_bit(1);
        apply_bit(1);
        apply_bit(0);
        apply_bit(1); // Should detect
        apply_bit(1);
        apply_bit(0);
        apply_bit(1); // Should detect

        // Test Case: Reset mid-sequence
        apply_bit(1);
        apply_bit(1);
        #3 rst_n = 0;
        if (detected !== 1'b0) begin
            $display("FAIL: Reset failed to clear output. din=%b, expected=0, actual=%b", din, detected);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end
        history = 3'b000; // Reset ref model history
        #5 rst_n = 1;

        // Test Case: Mealy combinational check
