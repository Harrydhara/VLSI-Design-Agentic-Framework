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
    // history[2:0] stores the last three bits sampled at clock edges.
    reg [2:0] history; 

    integer passed;
    integer total;

    // Clock generation
    always #5 clk = ~clk;

    // Helper to check output
    task check_output(input [127:0] msg);
        reg expected;
        begin
            // The pattern is 1, 1, 0, 1.
            // 'detected' is high if the sequence of bits sampled at clk edges (including current)
            // matches 1, 1, 0, 1.
            // Because it's Mealy, we check the condition based on history + current din.
            if (history == 3'b110 && din == 1'b1)
                expected = 1'b1;
            else
                expected = 1'b0;

            total = total + 1;
            if (detected !== expected) begin
                $display("FAIL: %s | din=%b, history_bits=%b, expected=%b, actual=%b", 
                         msg, din, history, expected, detected);
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
            // Update history on rising edge: the current 'din' is now part of the history for the NEXT bit.
            history = {history[1:0], din}; 
            
            #0.1; // Wait for Mealy to react to any potential state change/din stability
            check_output("Post-clk edge");
        end
    endtask

    // Reset procedure
    task reset_dut();
        begin
            rst_n = 0;
            din = 0;
            history = 3'b000;
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
        history = 3'b000;

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
        // After reset, history must be cleared. We check it manually here.
        history = 3'b000;
        #0.1;
        check_output("Post-reset");
        
        drive_bit(1);
        drive_bit(1);
        drive_bit(0);
        drive_bit(1); // Should detect now

        // Test Case 5: Mealy behavior (din changes without clk)
        // Get history to 1, 1, 0.
        drive_bit(1); // ...1
        drive_bit(1); // ...11
        drive_bit(0); // ...110
        
        // Now din is 0. If we change din to 1 BEFORE clk, detected should go high immediately.
        din = 1;
        #0.1;
        check_output("Mealy transition (din 0->1)");
        
        @(posedge clk);
        // On the rising edge, 'din' is sampled into history.
        // The spec says: "detected is 1 exactly when the last three bits sampled... were 1, 1, 0 and din is currently 1".
        // At this exact moment (the rising edge), the "last three bits sampled" are indeed 1, 1, 0.
        // The current bit 'din' is also 1. So detected must be 1.
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
