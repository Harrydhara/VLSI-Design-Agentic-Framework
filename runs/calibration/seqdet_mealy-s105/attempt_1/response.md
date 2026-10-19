```verilog
module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    // State encoding for the sequence 1 -> 1 -> 0 (next bit 1 triggers output)
    // S0: Reset/Initial state
    // S1: Found '1'
    // S2: Found '11'
    // S3: Found '110'
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
                    if (din == 1'b1) state <= S1;
                    else             state <= S0;
                end
                S1: begin
                    if (din == 1'b1) state <= S2;
                    else             state <= S0;
                end
                S2: begin
                    if (din == 1'b0) state <= S3;
                    else             state <= S2; // Stay in S2 if '111' is seen
                end
                S3: begin
                    if (din == 1'b1) state <= S1; // Overlap: '1101' -> next bit could be part of '11...'
                    else             state <= S0;
                end
                default: state <= S0;
            endcase
        end
    end

    // Mealy output logic: depends on current state and current input din
    // Pattern is 1, 1, 0, 1. If we are in S3 (found 1, 1, 0), and din is 1, detected = 1.
    assign detected = (state == S3 && din == 1'b1) ? 1'b1 : 1'b0;

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

    task check_val(input reg expected);
        begin
            total = total + 1;
            if (detected !== expected) begin
                $display("FAIL: din=%b, rst_n=%b, expected=%b, actual=%b", din, rst_n, expected, detected);
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
        
        // Test Case 1: Basic pattern 1, 1, 0, 1
        // We must check 'detected' both when din changes and after clk edge.
        // Since it is Mealy, we check the value of detected relative to din.
        
        @(posedge clk); din = 1; // S0 -> S1 (at next edge)
        #1; check_val(0);
        @(posedge clk); din = 1; // S1 -> S2
        #1; check_val(0);
        @(posedge clk); din = 0; // S2 -> S3
        #1; check_val(0);
        // Now in S3, if din becomes 1, detected must go high immediately (Mealy)
        din = 1;
        #1; check_val(1);
        @(posedge clk); // Transition to S1
        #1; check_val(0);

        // Test Case 2: Overlapping pattern 1, 1, 0, 1, 1, 0, 1
        // Sequence so far (from previous): ...1 (at end of TC1)
        // We need to build up to the next 1101.
        // Current state is S1.
        @(posedge clk); din = 1; // S1 -> S2
        #1; check_val(0);
        @(posedge clk); din = 0; // S2 -> S3
        #1; check_val(0);
        din = 1;                // Mealy trigger
        #1; check_val(1);
        @(posedge clk);         // State becomes S1
        #1; check_val(0);
        @(posedge clk); din = 1; // S1 -> S2
        #1; check_val(0);
        @(posedge clk); din = 0; // S2 -> S3
        #1; check_val(0);
        din = 1;                // Mealy trigger
        #1; check_val(1);
        @(posedge clk);         // State becomes S1
        #1; check_val(0);

        // Test Case 3: Reset mid-sequence
        @(posedge clk); din = 1; // S1
        @(posedge clk); din = 1; // S2
        @(posedge clk); din = 0; // S3
        #1; check_val(0);
        rst_n = 0;               // Async reset
        #1;
        if (uut.state !== 2'd0) begin
             $display("FAIL: Reset failed to clear state");
             passed = passed - 1;
             total = total + 1;
        end else begin
             passed = passed + 1;
             total = total + 1;
        end
        din = 1;                 // Should not trigger because reset happened
        #1; check_val(0);
        rst_n = 1;

        // Test Case 4: Continuous 1s (S2 should stay S2)
        @(posedge clk); din = 1; // S0 -> S1
        @(posedge clk); din = 1; // S1 -> S2
        @(posedge clk); din = 1; // S2 -> S2
        #1; check_val(0);
        @(posedge clk); din = 1; // S2 -> S2
        #1; check_val(0);

        // Test Case 5: Pattern with extra zeros
        @(posedge clk); din = 0; // S2 -> S3 (if we were in S2) - wait, let's reset state manually for clarity
        // Let's just provide a clean sequence.
        @(posedge clk); din = 1; // S0->S1
        @(posedge clk); din = 1; // S1->S2
        @(posedge clk); din = 0; // S2->S3
        din = 1;                 // Mealy!
        #1; check_val(1);
        @(posedge clk); din = 0; // S1 -> S0
        #1; check_val(0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```