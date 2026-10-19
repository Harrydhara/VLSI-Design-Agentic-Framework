```verilog
module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    // State encoding for the sequence 1 -> 1 -> 0 (Mealy output on next 1)
    // S0: Idle / Reset
    // S1: Found '1'
    // S2: Found '11'
    // S3: Found '110'
    reg [1:0] state;

    localparam S0 = 2'b00;
    localparam S1 = 2'b01;
    localparam S2 = 2'b10;
    localparam S3 = 2'b11;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S0;
        end else begin
            case (state)
                S0: begin
                    if (din == 1'b1) state <= S1;
                    else             state <= S0;
                end
                S1: begin
                    if (din == 1'b1) state <= S2;
                    else             state <= S0;
                end
                S2: begin
                    if (din == 1'b0) state <= S3;
                    else             state <= S2; // Stay in S2 if sequence is 111...
                end
                S3: begin
                    if (din == 1'b1) state <= S1; // Overlap: 110 + 1 -> next bit could be part of 1101
                                                 // Actually, if we see 1101, the last '1' is the start of a new potential sequence.
                                                 // Let's re-evaluate overlap for 1101101:
                                                 // Bits: 1(S1) 1(S2) 0(S3) 1(detected=1, S1) 1(S2) 0(S3) 1(detected=1, S1)
                                                 // So after detecting 1101, we are in state S1.
                    else             state <= S0;
                end
                default: state <= S0;
            endcase
        end
    end

    // Mealy output logic: detected is high if we are in S3 and din is 1
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

    task check_bit(input expected_det);
        begin
            total = total + 1;
            // Since it's Mealy, we must check 'detected' immediately after changing 'din'
            // and potentially before the clock edge. However, in a testbench with #5 delays,
            // we should be careful about race conditions. We will check after a tiny delay.
            #1; 
            if (detected !== expected_det) begin
                $display("FAIL: din=%b, state_approx=%b, expected detected=%b, actual=%b", din, uut.state, expected_det, detected);
                passed = passed - 1;
            end else begin
                passed = passed + 1;
            end
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

        // Test Case 1: Basic sequence 1, 1, 0, 1
        // Sequence: 1 -> 1 -> 0 -> 1 (detect)
        din = 1; #10; check_bit(0); // S1
        din = 1; #10; check_bit(0); // S2
        din = 0; #10; check_bit(0); // S3
        din = 1; #10; check_bit(1); // Detected! -> S1

        // Test Case 2: Overlapping pattern 1, 1, 0, 1, 1, 0, 1
        // We are currently at S1 from previous test.
        // Current bits in memory: ...1 (from end of prev)
        // Next bit: 1 -> S2
        din = 1; #10; check_bit(0); // S2
        // Next bit: 0 -> S3
        din = 0; #10; check_bit(0); // S3
        // Next bit: 1 -> Detected! (S1)
        din = 1; #10; check_bit(1); // S1
        // Next bit: 1 -> S2
        din = 1; #10; check_bit(0); // S2
        // Next bit: 0 -> S3
        din = 0; #10; check_bit(0); // S3
        // Next bit: 1 -> Detected! (S1)
        din = 1; #10; check_bit(1); // S1

        // Test Case 3: Reset during sequence
        din = 1; #10; // S2
        din = 1; #10; // S2
        din = 0; #5  rst_n = 0; // Reset mid-way
        #5 rst_n = 1;
        // After reset, state should be S0. din is still 0.
        check_bit(0);

        // Test Case 4: No pattern
        din = 0; #10; check_bit(0);
        din = 1; #10; check_bit(0);
        din = 1; #10; check_bit(0);
        din = 1; #10; check_bit(0); // Should stay in S2 (111)
        din = 1; #10; check_bit(0);

        // Test Case 5: Mealy behavior - change din without clock edge
        // Get to S3
        din = 1; #10; // S1
        din = 1; #10; // S2
        din = 0; #10; // S3
        // Now in S3, detected is 0. If we change din to 1, detected should go high immediately.
        din = 1; 
        #0.5; // Small delay to check Mealy response before clock edge
        total = total + 1;
        if (detected !== 1) begin
            $display("FAIL: Mealy transition failed. din=%b, expected detected=1, actual=%b", din, detected);
            passed = passed - 1;
        end else begin
            passed = passed + 1;
        end
        #5; // Finish the clock cycle

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```