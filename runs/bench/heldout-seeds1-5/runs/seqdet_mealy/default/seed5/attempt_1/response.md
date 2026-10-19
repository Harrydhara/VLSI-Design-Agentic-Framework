```verilog
module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    // State encoding for the sequence 1 -> 1 -> 0 (Mealy output on next 1)
    // S0: Idle / Reset
    // S1: Saw '1'
    // S2: Saw '1, 1'
    // S3: Saw '1, 1, 0'
    reg [1:0] state;

    localparam S0 = 2'd0;
    localparam S1 = 2'd1;
    localparam S2 = 2'd2;
    localparam S3 = 2'd3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S0;
        end else begin
            case (state)
                S0: begin
                    if (din) state <= S1;
                    else     state <= S0;
                end
                S1: begin
                    if (din) state <= S2;
                    else     state <= S0;
                end
                S2: begin
                    if (din) state <= S2; // Stay in S2 if 1,1,1... pattern continues? 
                                          // Wait, the sequence is 1,1,0,1.
                                          // If we have 1,1 and get another 1, we are still at "Saw 1,1"
                    else     state <= S3;
                end
                S3: begin
                    if (din) state <= S1; // Pattern 1,1,0,1 completed. Next bit could be start of new pattern.
                                          // If din=1, we have "1", so go to S1.
                    else     state <= S0;
                end
                default: state <= S0;
            endcase
        end
    end

    // Correcting State Machine Logic for Overlap and Transitions
    // Let's re-evaluate the states based on prefix matching:
    // S0: ""
    // S1: "1"
    // S2: "1, 1"
    // S3: "1, 1, 0"
    
    // Re-writing logic to be more robust for overlapping patterns.
    // If state is S2 (saw 1,1) and din=1 -> still saw 1,1 (S2).
    // If state is S3 (saw 1,1,0) and din=1 -> pattern detected! Next state? 
    // The sequence ends in '1'. That '1' can be the start of a new '1,1,0,1'. So go to S1.

    // Let's refine the transition logic inside the always block:
    /*
    S0 --(1)--> S1
    S0 --(0)--> S0
    S1 --(1)--> S2
    S1 --(0)--> S0
    S2 --(1)--> S2 (because 1,1,1 still contains the prefix 1,1)
    S2 --(0)--> S3
    S3 --(1)--> S1 (pattern complete, '1' is start of next)
    S3 --(0)--> S0
    */

    // Mealy output: detected = 1 if state == S3 AND din == 1.
    assign detected = (state == S3 && din == 1'b1);

endmodule
```

```verilog
module tb;
    reg clk;
    reg rst_n;
    reg din;
    wire detected;

    integer i;
    integer passed;
    integer total;

    seqdet_mealy uut (
        .clk(clk),
        .rst_n(rst_n),
        .din(din),
        .detected(detected)
    );

    always #5 clk = ~clk;

    task check_bit(input bit expected_det, input bit in_val);
        begin
            // Since it's Mealy, 'detected' reacts immediately to 'din'.
            // However, in a testbench with a clock, we must be careful about 
            // race conditions between din change and detected change.
            // We will check the output after a tiny delay to allow combinational propagation.
            #1; 
            if (detected !== expected_det) begin
                $display("FAIL: din=%b, expected detected=%b, actual detected=%b", in_val, expected_det, detected);
                passed = passed - 1;
            end else begin
                passed = passed + 1;
            end
            total = total + 1;
            
            // Prepare for next cycle: apply din and wait for clock edge
            din = in_val;
        end
    endtask

    initial begin
        // Initialize
        clk = 0;
        rst_n = 0;
        din = 0;
        passed = 0;
        total = 0;

        // Reset
        #15 rst_n = 1;
        @(posedge clk);

        // Test Case 1: Simple pattern 1, 1, 0, 1
        // Sequence: 1 (S1), 1 (S2), 0 (S3), 1 (Detected!)
        check_bit(0, 1); // S0 -> S1
        @(posedge clk);
        check_bit(0, 1); // S1 -> S2
        @(posedge clk);
        check_bit(0, 0); // S2 -> S3
        @(posedge clk);
        check_bit(1, 1); // S3 -> S1 (Detected)
        @(posedge clk);

        // Test Case 2: Overlapping pattern 1, 1, 0, 1, 1, 0, 1
        // We are currently at S1.
        // Sequence from here: 1 (S2), 0 (S3), 1 (Det!), 1 (S2), 0 (S3), 1 (Det!)
        check_bit(0, 1); // S1 -> S2
        @(posedge clk);
        check_bit(0, 0); // S2 -> S3
        @(posedge clk);
        check_bit(1, 1); // S3 -> S1 (Detected)
        @(posedge clk);
        check_bit(0, 1); // S1 -> S2
        @(posedge clk);
        check_bit(0, 0); // S2 -> S3
        @(posedge clk);
        check_bit(1, 1); // S3 -> S1 (Detected)
        @(posedge clk);

        // Test Case 3: Reset during sequence
        // Sequence: 1, 1, (reset), 0, 1
        check_bit(0, 1); // S0 -> S1
        @(posedge clk);
        check_bit(0, 1); // S1 -> S2
        #2 rst_n = 0;    // Async reset
        #5 rst_n = 1;    // Release reset
        @(posedge clk);
        check_bit(0, 0); // Should be in S0
        @(posedge clk);
        check_bit(0, 1); // S0 -> S1

        // Test Case 4: Extra 1s (S2 should stay S2)
        // Sequence: 1, 1, 1, 1, 0, 1
        check_bit(0, 1); // S1 -> S2
        @(posedge clk);
        check_bit(0, 1); // S2 -> S2
        @(posedge clk);
        check_bit(0, 1); // S2 -> S2
        @(posedge clk);
        check_bit(0, 0); // S2 -> S3
        @(posedge clk);
        check_bit(1, 1); // S3 -> S1 (Detected)
        @(posedge clk);

        // Test Case 5: No pattern
        check_bit(0, 0);
        check_bit(0, 0);
        check_bit(0, 1);
        check_bit(0, 0);
        check_bit(0, 1);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```