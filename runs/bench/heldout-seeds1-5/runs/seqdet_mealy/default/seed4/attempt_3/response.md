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
                    if (din == 1'b1) state <= S1; // After 1101, the last '1' starts a new potential sequence
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

    integer passed;
    integer total;

    seqdet_mealy uut (
        .clk(clk),
        .rst_n(rst_n),
        .din(din),
        .detected(detected)
    );

    always #5 clk = ~clk;

    // Task to apply input and check output at the end of the cycle
    task drive_and_check(input expected_det);
        begin
            total = total + 1;
            @(posedge clk); // Wait for clock edge
            #1;             // Small delay after edge to allow state transition
            if (detected !== expected_det) begin
                $display("FAIL: din=%b, expected detected=%b, actual=%b", din, expected_det, detected);
                passed = passed - 1;
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    // Task to check Mealy behavior (immediate change)
    task check_mealy(input expected_det);
        begin
            total = total + 1;
            #0.1; // Tiny delay to allow combinational propagation
            if (detected !== expected_det) begin
                $display("FAIL: Mealy din=%b, expected detected=%b, actual=%b", din, expected_det, detected);
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
        #5; // Wait for reset to settle

        // Test Case 1: Basic sequence 1, 1, 0, 1
        din = 1; drive_and_check(0); // S1
        din = 1; drive_and_check(0); // S2
        din = 0; drive_and_check(0); // S3
        din = 1; drive_and_check(1); // Detected! -> S1

        // Test Case 2: Overlapping pattern 1, 1, 0, 1, 1, 0, 1
        // Reset for a clean overlap test.
        rst_n = 0; #10; rst_n = 1; #5;
        din = 1; drive_and_check(0); // S1
        din = 1; drive_and_check(0); // S2
        din = 0; drive_and_check(0); // S3
        din = 1; drive_and_check(1); // Detected! -> S1 (Sequence: 1,1,0,1)
        din = 1; drive_and_check(0); // S2 (Sequence part: ...1,1)
        din = 0; drive_and_check(0); // S3 (Sequence part: ...1,1,0)
        din = 1; drive_and_check(1); // Detected! -> S1 (Sequence: 1,1,0,1,1,0,1)

        // Test Case 3: Reset during sequence
        din = 1; #5; // S1
        din = 1; #5; // S2
        rst_n = 0;   // Async reset
        #5 rst_n = 1;
        #5;          // Wait for state to be S0
        if (uut.state !== 2'b00) begin
             $display("FAIL: Reset failed, state=%b", uut.state);
             passed = passed - 1; total = total + 1;
        end else begin
             passed = passed + 1; total = total + 1;
        end

        // Test Case 4: Mealy behavior check
        // Get to S3
        din = 1; #10; // S1
        din = 1; #10; // S2
        din = 0; #10; // S3
        // Now in S3, detected is 0. Change din to 1.
        din = 1;
        check_mealy(1);
        #5; // Complete the cycle

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```