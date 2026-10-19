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
    reg [2:0] history; 

    integer passed;
    integer total;

    // Clock generation
    always #5 clk = ~clk;

    task check_output(input [127:0] msg);
        reg expected;
        begin
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

    task drive_bit(input b);
        begin
            din = b;
            #0.1; 
            check_output("Post-din change");
            
            @(posedge clk);
            // The bit is sampled here.
            // In a Mealy machine, the output 'detected' at the moment of the rising edge
            // depends on the state BEFORE the edge and the current 'din'.
            // After the edge, the state updates.
            
            #0.1; // Allow state to update
            history = {history[1:0], din}; 
            
            // Now check the output with the NEW history.
            check_output("Post-clk edge");
        end
    endtask

    task reset_dut();
        begin
            rst_n = 0;
            din = 0;
            history = 3'b000;
            #15; 
            rst_n = 1;
            #5;
        end
    endtask

    initial begin
        clk = 0;
        rst_n = 0;
        din = 0;
        passed = 0;
        total = 0;
        history = 3'b000;

        reset_dut();

        // Test Case 1: Basic sequence 1, 1, 0, 1
        drive_bit(1); 
        drive_bit(1); 
        drive_bit(0); 
        drive_bit(1); 

        // Test Case 2: Overlapping pattern 1, 1, 0, 1, 1, 0, 1
        drive_bit(1); 
        drive_bit(0); 
        drive_bit(1); 

        // Test Case 3: No pattern
        drive_bit(0);
        drive_bit(0);
        drive_bit(1);
        drive_bit(1);
        drive_bit(1); 

        // Test Case 4: Reset mid-sequence
        drive_bit(1);
        drive_bit(1);
        #2; 
        rst_n = 0;
        #5;
        rst_n = 1;
        #0.1;
        // Manual reset of history in TB to match DUT
        history = 3'b000;
        check_output("Post-reset");
        
        drive_bit(1);
        drive_bit(1);
        drive_bit(0);
        drive_bit(1); 

        // Test Case 5: Mealy behavior (din changes without clk)
        drive_bit(1); 
        drive_bit(1); 
        drive_bit(0); 
        
        din = 1;
        #0.1;
        check_output("Mealy transition (din 0->1)");
        
        @(posedge clk);
        #0.1;
        history = {history[1:0], din};
        check_output("Post-clk edge (Mealy stable)");

        // Test Case 6: Mealy behavior (din changes back to 0)
        din = 0;
        #0.1;
        check_output("Mealy transition (din 1->0)");

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
