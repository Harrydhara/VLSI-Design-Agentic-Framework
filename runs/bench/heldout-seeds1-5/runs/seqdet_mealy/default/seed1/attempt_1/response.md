```verilog
module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    // State encoding for the sequence detector (1 -> 1 -> 0)
    // S0: IDLE / Reset state
    // S1: Saw '1'
    // S2: Saw '11'
    // S3: Saw '110'
    parameter S0 = 2'b00;
    parameter S1 = 2'b01;
    parameter S2 = 2'b10;
    parameter S3 = 2'b11;

    reg [1:0] state;

    // State transition logic (Sequential)
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
                    if (din) state <= S2; // Stay in S2 if we see '111'
                    else     state <= S3;
                end
                S3: begin
                    if (din) state <= S1; // Pattern 1101 completed, next bit could be start of new pattern
                    else     state <= S0;
                end
                default: state <= S0;
            endcase
        end
    end

    // Mealy output logic (Combinational)
    // detected is 1 if we are in state S3 (saw 1, 1, 0) AND current din is 1.
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

    task check_bit(input expected_detected);
        begin
            total = total + 1;
            // Since it's Mealy, we must check the output immediately after din changes
            // or at a stable point. In this TB, we check right after setting din.
            #0; // Allow combinational propagation
            if (detected !== expected_detected) begin
                $display("FAIL: din=%b, state=%b, expected detected=%b, actual detected=%b", 
                         din, uut.state, expected_detected, detected);
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

        // Reset sequence
        #15 rst_n = 1;
        #10;

        // Test Case 1: Simple pattern 1, 1, 0, 1
        // Sequence: 1 (S1), 1 (S2), 0 (S3), 1 (Detected!)
        din = 1; #10; // S0 -> S1
        check_bit(0);
        din = 1; #10; // S1 -> S2
        check_bit(0);
        din = 0; #10; // S2 -> S3
        check_bit(0);
        din = 1; #10; // S3 -> S1 (Mealy output triggers here)
        check_bit(1);

        // Test Case 2: Overlapping pattern 1, 1, 0, 1, 1, 0, 1
        // We are currently at S1.
        // Sequence: 1 (S2), 0 (S3), 1 (Detected!), 1 (S1/S2?), 0 (S3), 1 (Detected!)
        // Let's reset to be sure and run the specific sequence requested.
        rst_n = 0; #10; rst_n = 1; #10;

        // Input: 1, 1, 0, 1, 1, 0, 1
        din = 1; #10; check_bit(0); // S1
        din = 1; #10; check_bit(0); // S2
        din = 0; #10; check_bit(0); // S3
        din = 1; #10; check_bit(1); // S1 (Detected)
        din = 1; #10; check_bit(0); // S2
        din = 0; #10; check_bit(0); // S3
        din = 1; #10; check_bit(1); // S1 (Detected)

        // Test Case 3: Reset during sequence
        rst_n = 0; #5; 
        // din is still 1 from previous, but rst_n goes low.
        // Mealy output should be 0 immediately if it was 1? 
        // Actually, detected depends on state and din. State becomes S0.
        #5 rst_n = 1; #10;
        check_bit(0);

        // Test Case 4: Continuous 1s (S2 should stay in S2)
        din = 1; #10; // S1
        din = 1; #10; // S2
        din = 1; #10; // S2
        check_bit(0);
        din = 0; #10; // S3
        check_bit(0);
        din = 1; #10; // Detected!
        check_bit(1);

        // Test Case 5: No pattern (1, 1, 1, 1...)
        rst_n = 0; #10; rst_n = 1; #10;
        din = 1; #10; // S1
        din = 1; #10; // S2
        din = 1; #10; // S2
        din = 1; #10; // S2
        check_bit(0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```