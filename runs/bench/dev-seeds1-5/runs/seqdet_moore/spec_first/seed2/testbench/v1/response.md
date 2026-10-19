```verilog
module tb;
    // Inputs
    reg clk;
    reg rst;
    reg din;

    // Outputs
    wire detected;

    // Instantiate the design under test
    seqdet_moore dut (
        .clk(clk),
        .rst(rst),
        .din(din),
        .detected(detected)
    );

    // Reference Model State
    // Pattern: 1, 0, 1, 1
    // States: S0 (init), S1 (1), S2 (10), S3 (101), S4 (1011 - detected)
    integer state;
    reg expected_detected;

    // Testbench variables
    integer passed;
    integer total;

    // Clock generation
    always #5 clk = ~clk;

    // Reference Model Logic
    // The model updates on the rising edge, simulating the synchronous behavior.
    // Since it's a Moore machine, 'detected' is determined by the state reached AFTER the transition.
    initial begin
        state = 0;
        expected_detected = 0;
    end

    always @(posedge clk) begin
        if (rst) begin
            state = 0;
            expected_detected = 0;
        end else begin
            // Transition logic based on din
            case (state)
                0: if (din == 1'b1) state = 1; else state = 0;
                1: if (din == 1'b0) state = 2; else state = 1;
                2: if (din == 1'b1) state = 3; else state = 0;
                3: if (din == 1'b1) state = 4; else if (din == 1'b0) state = 2; else state = 1;
                4: // Overlap logic for 1,0,1,1. If next is 0 -> 1,0. If next is 1 -> ?
                   // Looking at the pattern 1011... if we get a 0, it's like being in state S2 (10).
                   // If we get a 1, we check for overlap. The last bit was 1. 
                   // A sequence ending in ...1 followed by 1 is just the start of a new potential pattern? No.
                   // Let's trace: 1-0-1-1 (S4). Next bit is 0 -> 1-0 (S2). Next bit is 1 -> 1-0-1 (S3).
                   // If next bit is 1 -> 1-0-1-1 (S4).
                   // Wait, if we are in S4 and get a 1: the sequence ends in ...1. The new suffix is '1'. So state = 1.
                   // If we are in S4 and get a 0: the new suffix is '10'. So state = 2.
                   if (din == 1'b0) state = 2; else state = 1;
                default: state = 0;
            endcase

            // Moore output depends on current state
            if (state == 4) expected_detected = 1'b1;
            else           expected_detected = 1'b0;
        end
    end

    // Task to drive input and check output
    task drive_bit(input bit_val);
        begin
            din = bit_val;
            @(posedge clk);
            // After the rising edge, the state has updated. 
            // The Moore output 'detected' should match our expected_detected.
            // We use a small delay to allow the wire to settle after the clock edge.
            #1; 
            total = total + 1;
            if (detected !== expected_detected) begin
                $display("FAIL: din=%b, rst=%b, expected detected=%b, actual detected=%b", din, rst, expected_detected, detected);
                passed = passed + 0;
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        // Initialize
        clk = 0;
        rst = 0;
        din = 0;
        passed = 0;
        total = 0;

        // Reset sequence
        @(posedge clk);
        rst = 1;
        #1; // Wait for sync reset to take effect
        drive_bit(0); // din is ignored during rst edge, but we drive it anyway
        
        rst = 0;
        #1;

        // Test Case 1: Basic pattern 1, 0, 1, 1
        drive_bit(1);
        drive_bit(0);
        drive_bit(1);
        drive_bit(1); // Should detect here

        // Test Case 2: Overlapping patterns 1, 0, 1, 1, 0, 1, 1
        // We are currently at the end of the first pattern.
        // The sequence so far: ...1, 0, 1, 1 (detected=1)
        // Next bits to complete overlap: 0, 1, 1
        drive_bit(0);
        drive_bit(1);
        drive_bit(1); // Should detect here again

        // Test Case 3: No pattern
        drive_bit(0);
        drive_bit(0);
        drive_bit(1);
        drive_bit(1);
        drive_bit(1);
        drive_bit(0);

        // Test Case 4: Reset mid-sequence
        drive_bit(1);
        drive_bit(0);
        @(posedge clk);
        rst = 1;
        #1;
        drive_bit(1); // rst is high, din ignored. State should be 0.
        rst = 0;
        #1;
        drive_bit(0);
        drive_bit(1);
        drive_bit(1); // Should not detect because reset cleared the '1, 0'

        // Test Case 5: Rapid pattern
        drive_bit(1);
        drive_bit(0);
        drive_bit(1);
        drive_bit(1); // Detect

        // Final check of all bits
        #20;
        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```