```verilog
module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    // State encoding for pattern 1, 1, 0 (Mealy output depends on din)
    // S0: Initial / No bits matched
    // S1: "1" matched
    // S2: "1, 1" matched
    // S3: "1, 1, 0" matched
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
                    if (din == 1'b1) state <= S1;
                    else             state <= S0;
                end
                S1: begin
                    if (din == 1'b1) state <= S2;
                    else             state <= S0;
                end
                S2: begin
                    if (din == 1'b0) state <= S3;
                    else             state <= S2; // Stay in S2 if we get "1, 1, 1"
                end
                S3: begin
                    if (din == 1'b1) state <= S1; // Pattern was 1,1,0. Next bit is 1. New sequence starts with '1'.
                    else             state <= S0;
                end
                default: state <= S0;
            endcase
        end
    end

    // Mealy output logic (Combinational)
    // detected is 1 if we are in state "1, 1, 0" and din is 1.
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

    task check_val(input reg expected_det, input reg current_din);
        total = total + 1;
        if (detected !== expected_det) begin
            $display("FAIL: din=%b, expected detected=%b, actual detected=%b", current_din, expected_det, detected);
            passed = passed - 1;
        end else begin
            passed = passed + 1;
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

        // Test Case 1: Simple pattern 1, 1, 0, 1
        // Sequence: 1 (S1), 1 (S2), 0 (S3), 1 (Detected!)
        @(posedge clk); din = 1; // S0 -> S1
        #1; check_val(0, 1);
        @(posedge clk); din = 1; // S1 -> S2
        #1; check_val(0, 1);
        @(posedge clk); din = 0; // S2 -> S3
        #1; check_val(0, 0);
        @(posedge clk); din = 1; // S3 -> S1 (Mealy output triggers here)
        #1; check_val(1, 1);

        // Test Case 2: Overlapping pattern 1, 1, 0, 1, 1, 0, 1
        // We are currently at S1.
        // Sequence: 1 (S2), 0 (S3), 1 (Detected!), 1 (S1), 0 (S3), 1 (Detected!)
        @(posedge clk); din = 1; // S1 -> S2
        #1; check_val(0, 1);
        @(posedge clk); din = 0; // S2 -> S3
        #1; check_val(0, 0);
        @(posedge clk); din = 1; // S3 -> S1 (Detected!)
        #1; check_val(1, 1);
        @(posedge clk); din = 1; // S1 -> S2
        #1; check_val(0, 1);
        @(posedge clk); din = 0; // S2 -> S3
        #1; check_val(0, 0);
        @(posedge clk); din = 1; // S3 -> S1 (Detected!)
        #1; check_val(1, 1);

        // Test Case 3: Reset during pattern
        @(posedge clk); din = 1; // S1 -> S2
        #1; check_val(0, 1);
        #2 rst_n = 0;           // Async reset
        #1;                     // Check immediately after reset
        if (detected !== 0) begin
            $display("FAIL: Reset failed to clear output. detected=%b", detected);
            passed = passed - 1;
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end
        #10 rst_n = 1;

        // Test Case 4: Continuous 1s (should stay in S2)
        @(posedge clk); din = 1; // S0 -> S1
        #1; check_val(0, 1);
        @(posedge clk); din = 1; // S1 -> S2
        #1; check_val(0, 1);
        @(posedge clk); din = 1; // S2 -> S2
        #1; check_val(0, 1);
        @(posedge clk); din = 1; // S2 -> S2
        #1; check_val(0, 1);

        // Test Case 5: Mealy output sensitivity (din changes without clock)
        // Current state is S2. If we change din to 0, detected should stay 0.
        // If we were in S3 and changed din to 1, detected should go high immediately.
        @(posedge clk); din = 0; // S2 -> S3
        #1; check_val(0, 0);
        #5 din = 1;              // Mealy: change din without clock edge
        check_val(1, 1);         // Should be high immediately
        #5 din = 0;              // Mealy: change din back
        check_val(0, 0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```