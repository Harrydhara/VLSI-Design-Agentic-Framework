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
    // States: S0 (init), S1 (1), S2 (10), S3 (101), S4 (1011 - detected)
    integer state;
    reg expected_detected;

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Reference Model Logic
    // We model the Moore machine behavior: 
    // The output depends on the state reached AFTER the clock edge.
    task update_ref_model();
        case (state)
            0: begin // S0
                if (din == 1'b1) state = 1;
                else             state = 0;
            end
            1: begin // S1 (saw 1)
                if (din == 1'b0) state = 2;
                else             state = 1;
            end
            2: begin // S2 (saw 1, 0)
                if (din == 1'b1) state = 3;
                else             state = 0;
            end
            3: begin // S3 (saw 1, 0, 1)
                if (din == 1'b1) state = 4;
                else             state = 2;
            end
            4: begin // S4 (saw 1, 0, 1, 1) - Moore output is high here
                // Overlap check for 1, 0, 1, 1...
                // If next bit is 0, we go to state 2 (saw 1, 0)
                // If next bit is 1, we go to state 1 (saw 1)
                if (din == 1'b0) state = 2;
                else             state = 1;
            end
        endcase

        if (state == 4) expected_detected = 1'b1;
        else            expected_detected = 1'b0;
    endtask

    // Testbench control
    integer passed;
    integer total;
    integer i;

    initial begin
        passed = 0;
        total = 0;
        clk = 0;
        rst = 0;
        din = 0;
        state = 0;
        expected_detected = 0;

        // Reset sequence
        @(posedge clk);
        rst = 1;
        din = 0; // din ignored during reset
        state = 0;
        expected_detected = 0;
        @(posedge clk);
        rst = 0;
        
        // Verification loop for a sequence of bits
        // We will feed a specific pattern and check every cycle.
        // Pattern: 1, 0, 1, 1 (detect), 0, 1, 1 (detect) -> Overlap test
        // Then reset mid-way.
        
        check_bit(1); // S1
        check_bit(0); // S2
        check_bit(1); // S3
        check_bit(1); // S4 (Detected!)
        check_bit(0); // S2 (Overlap: 1, 0)
        check_bit(1); // S3
        check_bit(1); // S4 (Detected!)
        check_bit(0); // S2
        check_bit(0); // S0
        check_bit(1); // S1
        
        // Test Reset
        @(posedge clk);
        din = 1;
        rst = 1; // Should reset state to 0 and ignore din=1
        @(posedge clk);
        rst = 0;
        // After sync reset, we should be in S0. 
        // Let's verify by sending a partial pattern.
        check_bit(1); // S1
        check_bit(0); // S2
        check_bit(1); // S3
        check_bit(1); // S4 (Detected!)

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

    // Helper task to apply input and check output
    task check_bit(input bit b);
        begin
            din = b;
            @(posedge clk);
            // The Moore output changes right after the rising edge.
            // In a real simulation, we must wait a tiny delta or 
            // ensure the reference model and DUT are evaluated at the same time.
            #1; 
            update_ref_model();
            
            total = total + 1;
            if (detected === expected_detected) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: din=%b, rst=%b, expected=%b, actual=%b", din, rst, expected_detected, detected);
            end
        end
    endtask

endmodule
```