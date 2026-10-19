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
    // The pattern is 1 -> 1 -> 0 -> 1.
    reg [3:0] history; // Stores the last 4 bits sampled at clk edges

    integer passed;
    integer total;

    // Clock generation
    always #5 clk = ~clk;

    // Helper to check output
    task check_output(input $display_msg);
        reg expected;
        begin
            // The pattern is 1, 1, 0, 1.
            // 'detected' is high if the sequence of bits sampled at clk edges (including current)
            // matches 1, 1, 0, 1.
            // Because it's Mealy, we check the condition based on history + current din.
            
            // Logic: If history contains [..., 1, 1, 0] and current din is 1, then detected = 1.
            // We use a sliding window of bits sampled at clock edges.
            // However, since it's Mealy, the output can change mid-cycle if din changes.
            // The spec says: "detected is 1 exactly when the last three bits sampled... were 1, 1, 0 and din is currently 1".
            
            if (history[2:0] == 3'b110 && din == 1'b1)
                expected = 1'b1;
            else
                expected = 1'b0;

            total = total + 1;
            if (detected !== expected) begin
                $display("FAIL: %s | din=%b, history_bits=%b, expected=%b, actual=%b", 
                         $display_msg, din, history[2:0], expected, detected);
                passed = passed + 0;
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    // Procedure to apply a bit and check immediately (Mealy)
    task drive_bit(input b);
        begin
            din = b;
            #0.1; // Small delay to allow Mealy output to propagate after din change
            check_output("Post-din change");
            
            @(posedge clk);
            // Update history on rising edge
            history = {history[2:0], din}; 
            // Note: we only care about the last 3 bits for the pattern check.
            // We'll use a 4-bit register to keep track of the sequence.
            // Let's refine history logic:
            // On rising edge, 'din' is sampled.
            // The "last three bits sampled" refers to the ones before this one.
            // So if we just sampled din at T, the last three are from T-1, T-2, T-3.
            // But the spec says: "detected is 1 exactly when the last three bits sampled... were 1, 1, 0 and din is currently 1".
            // This implies if we are at time T, and we just saw a rising edge, 
            // 'din' is the current bit. The previous ones were sampled at T-1, T-2, etc.
            
            #0.1; // Wait for Mealy to react to din (though it should be immediate)
            check_output("Post-clk edge");
        end
    endtask

    // Reset procedure
    task reset_dut();
        begin
            rst_n = 0;
            din = 0;
            history = 4'b0000;
            #15; // Asynchronous reset duration
            rst_n = 1;
            #5;
        end
    endtask

    initial begin
        // Initialize
        clk = 0;
        rst_n = 0;
        din = 0;
        passed = 0;
        total = 0;
        history = 4'b0000;

        reset_dut();

        // Test Case 1: Basic sequence 1, 1, 0, 1
        drive_bit(1); // history becomes ...1
        drive_bit(1); // history becomes ...11
        drive_bit(0); // history becomes ...110
        drive_bit(1); // history becomes ...1101 -> detected should be 1

        // Test Case 2: Overlapping pattern 1, 1, 0, 1, 1, 0, 1
        // Current state after Case 1: history ends in 1.
        drive_bit(1); // ...11
        drive_bit(0); // ...110
        drive_bit(1); // ...1101 -> detected should be 1

        // Test Case 3: No pattern
        drive_bit(0);
        drive_bit(0);
        drive_bit(1);
        drive_bit(1);
        drive_bit(1); // history ends in 111, no detection

        // Test Case 4: Reset mid-sequence
        drive_bit(1);
        drive_bit(1);
        #2; // Mid cycle
        rst_n = 0;
        #5;
        rst_n = 1;
        check_output("Post-reset");
        drive_bit(1);
        drive_bit(1);
        drive_bit(0);
        drive_bit(1); // Should detect now

        // Test Case 5: Mealy behavior (din changes without clk)
        // We need history to be 1, 1, 0.
        // To get history 1, 1, 0, we drive bits at edges.
        drive_bit(1); // hist ...1
        drive_bit(1); // hist ...11
        drive_bit(0); // hist ...110
        
        // Now din is 0. If we change din to 1 BEFORE clk, detected should go high immediately.
        din = 1;
        #0.1;
        check_output("Mealy transition (din 0->1)");
        
        @(posedge clk);
        // Now the bit is sampled. History becomes ...1101.
        // Since din is already 1, detected stays 1.
        #0.1;
        check_output("Post-clk edge (Mealy stable)");

        // Test Case 6: Mealy behavior (din changes back to 0)
        din = 0;
        #0.1;
        check_output("Mealy transition (din 1->0)");

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```