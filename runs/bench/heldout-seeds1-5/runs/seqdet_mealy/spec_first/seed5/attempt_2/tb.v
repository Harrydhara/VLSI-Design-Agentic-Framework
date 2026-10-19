`timescale 1ns/1ps
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
    reg [2:0] history; // Stores the last 3 bits sampled at rising edges
    integer passed;
    integer total;
    integer i;

    // Clock generation
    always #5 clk = ~clk;

    // Monitor for Mealy output
    // The specification says detected is 1 if (last three bits were 1,1,0) AND din is 1.
    // We must check this whenever 'din' changes OR 'history' changes.
    always @(detected or din or history) begin
        if (rst_n) begin
            reg expected;
            expected = (history == 3'b110) && (din == 1'b1);
            if (detected !== expected) begin
                $display("FAIL: din=%b, hist=%b, expected=%b, actual=%b", din, history, expected, detected);
                // We don't increment 'total' here to avoid double counting.
                // Instead, we will count failures in a separate way or just use passed/total logic.
            end
        end
    end

    // Since the requirement is "Count the checks", I will implement 
    // a manual check at every possible transition point.

    task check_output();
        reg expected;
        expected = (history == 3'b110) && (din == 1'b1);
        total = total + 1;
        if (detected !== expected) begin
            $display("FAIL: din=%b, hist=%b, expected=%b, actual=%b", din, history, expected, detected);
        end else begin
            passed = passed + 1;
        end
    endtask

    // A more reliable way to drive the testbench:
    task drive_din(input b);
        begin
            din = b;
            #0.1; // Small delay for combinational propagation
            check_output(); // Check after din changes (Mealy)
            @(posedge clk);
            // After rising edge, the bit is sampled and history updates
            if (rst_n) begin
                history = {history[1:0], b};
            end else begin
                history = 3'b000;
            end
            #0.1; // Small delay for combinational propagation after state change
            check_output(); // Check after history changes (Mealy)
        end
    endtask

    initial begin
        // Initialization
        clk = 0;
        rst_n = 0;
        din = 0;
        history = 3'b000;
        passed = 0;
        total = 0;

        // Reset
        #15 rst_n = 1;
        check_output(); // Check initial state

        // Test Case 1: Pattern 1, 1, 0, 1
        drive_din(1); // hist: 001
        drive_din(1); // hist: 011
        drive_din(0); // hist: 110
        drive_din(1); // hist: 101 (detected should be 1 during this drive)

        // Test Case 2: Overlapping pattern 1, 1, 0, 1, 1, 0, 1
        // Current history is 101. To get 1101 again, we need bits 1, 0, 1... no.
        // Let's reset to a clean state for the overlap test.
        drive_din(0); // hist: 010
        drive_din(1); // hist: 101
        drive_din(1); // hist: 011
        drive_din(0); // hist: 110
        drive_din(1); // hist: 101 (Match 1)
        drive_din(1); // hist: 011
        drive_din(0); // hist: 110
        drive_din(1); // hist: 101 (Match 2)

        // Test Case 3: Reset mid-sequence
        drive_din(1);
        drive_din(1);
        #7 rst_n = 0; // Async reset
        check_output();
        history = 3'b000; // Manual sync of ref model
        #5 rst_n = 1;
        check_output();
        drive_din(1);
        drive_din(1);
        drive_din(0);
        drive_din(1);

        // Test Case 4: Corner case - all zeros
        drive_din(0);
        drive_din(0);
        drive_din(0);

        // Test Case 5: Corner case - all ones
        drive_din(1);
        drive_din(1);
        drive_din(1);
        drive_din(1);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
