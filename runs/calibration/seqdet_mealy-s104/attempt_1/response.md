```verilog
module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    // State encoding for the sequence 1, 1, 0, 1
    // S0: Idle / Reset
    // S1: Found '1'
    // S2: Found '1, 1'
    // S3: Found '1, 1, 0'
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
                    if (din == 1'b1)
                        state <= S1;
                    else
                        state <= S0;
                end
                S1: begin
                    if (din == 1'b1)
                        state <= S2;
                    else
                        state <= S0;
                end
                S2: begin
                    if (din == 1'b0)
                        state <= S3;
                    else
                        state <= S2; // Stay in S2 if we get another '1' (pattern is 1,1,...)
                end
                S3: begin
                    if (din == 1'b1)
                        state <= S2; // Overlap: the current '1' could be the start of a new pattern or part of 1,1...
                                     // Actually, if we are in S3 and get a 1, the sequence was 1,1,0,1.
                                     // The last bit (1) is the first bit of a potential next sequence.
                                     // Let's re-evaluate: 1,1,0,1 -> state transitions to S1? No.
                                     // If pattern is 1,1,0,1 and we get another 1, the bits are ...1,1,0,1,1...
                                     // The last '1' is the first bit of a new potential sequence.
                                     // However, if we just saw 1,1,0,1, the state should transition to S1 (found '1').
                                     // Wait, let's look at overlap: 1,1,0,1,1,0,1.
                                     // Bits: 1(S1) 1(S2) 0(S3) 1(detected=1, next state S1) 1(S2) 0(S3) 1(detected=1).
                                     // So if in S3 and din=1, we go to S1.
                        state <= S1;
                    else
                        state <= S0;
                end
                default: state <= S0;
            endcase
        end
    end

    // Mealy output logic
    // detected is 1 if in state S3 and din is 1.
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
            // Since it's Mealy, we must check 'detected' immediately when 'din' changes
            // and also after the clock edge to ensure stability if needed.
            // However, the spec says "changes as soon as din changes".
            if (detected !== expected_det) begin
                $display("FAIL: din=%b, state_after_clk=%b, expected detected=%b, actual detected=%b", 
                         din, uut.state, expected_det, detected);
                passed = passed - 1;
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
        passed = 0;
        total = 0;

        // Reset sequence
        #12 rst_n = 1;

        // Test Case 1: Simple pattern 1, 1, 0, 1
        // We drive din and check detected. Since it's Mealy, we check after setting din.
        
        // Input: 1
        din = 1; #10; // Clock edge
        check_bit(0);
        // Input: 1
        din = 1; #10;
        check_bit(0);
        // Input: 0
        din = 0; #10;
        check_bit(0);
        // Input: 1 (Pattern complete)
        din = 1; 
        #2; // Small delay to check Mealy response before clock edge
        check_bit(1);
        #8; // Finish the clock cycle
        check_bit(1);

        // Test Case 2: Overlapping pattern 1, 1, 0, 1, 1, 0, 1
        // Current state should be S1 (from previous 1).
        // Input: 1
        din = 1; #10;
        check_bit(0); // State becomes S2
        // Input: 0
        din = 0; #10;
        check_bit(0); // State becomes S3
        // Input: 1 (Pattern complete)
        din = 1;
        #2;
        check_bit(1);
        #8;
        check_bit(1); // State becomes S1

        // Test Case 3: Reset during sequence
        // Current state is S1.
        din = 1; #10; // State becomes S2
        rst_n = 0;    // Async reset
        #2;
        if (uut.state !== 2'b00) begin
            $display("FAIL: Reset failed, state=%b", uut.state);
            passed = passed - 1;
        end else begin
            passed = passed + 1;
        end
        total = total + 1;
        rst_n = 1;

        // Test Case 4: No pattern
        din = 0; #10; check_bit(0);
        din = 1; #10; check_bit(0);
        din = 0; #10; check_bit(0);
        din = 0; #10; check_bit(0);

        // Test Case 5: Multiple 1s (1, 1, 1, 0, 1)
        din = 1; #10; // S1
        din = 1; #10; // S2
        din = 1; #10; // S2
        din = 0; #10; // S3
        din = 1; #2; check_bit(1); #8; check_bit(1);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```