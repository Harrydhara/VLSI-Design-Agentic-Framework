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
    // We need to track the history of bits to determine if 'detected' should be 1.
    // The pattern is 1, 1, 0, 1.
    // Since it is a Mealy machine, detected depends on current din AND previous bits.
    // Specifically: detected = (history == 3'b110) && (din == 1).
    reg [2:0] history;

    // Testbench variables
    integer passed;
    integer total;
    integer i;

    // Clock generation
    always #5 clk = ~clk;

    // Task to drive input and check output immediately (Mealy property)
    task drive_din(input bit val);
        begin
            din = val;
            // Mealy output must be checked immediately after din changes
            // because it is combinational relative to din.
            #0; // Small delay to allow combinational propagation in simulation
            check_output();
        end
    endtask

    // Task to check the current state of 'detected' against reference model
    task check_output();
        reg expected;
        begin
            total = total + 1;
            // The pattern is 1, 1, 0, 1. 
            // If history (last 3 bits) was 1, 1, 0 and current din is 1, detected is 1.
            expected = (history == 3'b110) && (din == 1'b1);
            
            if (detected !== expected) begin
                $display("FAIL: din=%b, history=%b, expected=%b, actual=%b", din, history, expected, detected);
                passed = passed - 1;
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    // Task to handle clock edge (sampling)
    task tick();
        begin
            @(posedge clk);
            // Update history based on the bit that was just sampled
            history = {history[1:0], din};
        end
    endtask

    initial begin
        // Initialize
        clk = 0;
        rst_n = 0;
        din = 0;
        history = 3'b000;
        passed = 0;
        total = 0;

        // Asynchronous Reset Test
        #15 rst_n = 1;
        
        // Test Case 1: Simple sequence 1, 1, 0, 1
        drive_din(1); tick(); // history becomes 001
        drive_din(1); tick(); // history becomes 011
        drive_din(0); tick(); // history becomes 110
        drive_din(1); tick(); // history becomes 101, detected should have been 1 during drive_din(1)

        // Test Case 2: Overlapping patterns (1, 1, 0, 1, 1, 0, 1)
        // We are currently at end of Case 1. History is 101.
        drive_din(1); tick(); // history becomes 011
        drive_din(0); tick(); // history becomes 110
        drive_din(1); tick(); // history becomes 101, detected should be 1

        // Test Case 3: Reset mid-sequence
        drive_din(1); tick(); // hist 011
        drive_din(1); tick(); // hist 111
        #2 rst_n = 0;         // Async reset
        #1 rst_n = 1;         // Release reset
        // After reset, history should be cleared. In our model, we manually clear it.
        history = 3'b000; 
        drive_din(1); tick(); // hist 001

        // Test Case 4: Random bits and no pattern
        drive_din(0); tick();
        drive_din(0); tick();
        drive_din(1); tick();
        drive_din(1); tick();
        drive_din(1); tick(); // hist 111
        drive_din(0); tick(); // hist 110
        drive_din(0); tick(); // hist 100

        // Test Case 5: Edge case - pattern at the very end of a stream
        history = 3'b000;
        drive_din(1); tick();
        drive_din(1); tick();
        drive_din(0); tick();
        drive_din(1); tick();

        // Final check for any hanging signals
        #20;
        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

    // Monitor reset to clear history in reference model
    always @(negedge rst_n) begin
        history = 3'b000;
    end

endmodule
