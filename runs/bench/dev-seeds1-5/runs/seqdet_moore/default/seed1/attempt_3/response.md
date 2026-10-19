```verilog
module seqdet_moore(
    input   clk,
    input   rst,
    input   din,
    output  detected
);

    // State encoding for Moore Machine
    // S0: Idle / Reset state (no bits matched)
    // S1: Detected '1'
    // S2: Detected '1, 0'
    // S3: Detected '1, 0, 1'
    // S4: Detected '1, 0, 1, 1' (Output = 1)
    reg [2:0] state;
    localparam S0 = 3'd0,
               S1 = 3'd1,
               S2 = 3'd2,
               S3 = 3'd3,
               S4 = 3'd4;

    always @(posedge clk) begin
        if (rst) begin
            state <= S0;
        end else begin
            case (state)
                S0: begin
                    if (din == 1'b1) state <= S1;
                    else             state <= S0;
                end
                S1: begin
                    if (din == 1'b0) state <= S2;
                    else             state <= S1;
                end
                S2: begin
                    if (din == 1'b1) state <= S3;
                    else             state <= S0;
                end
                S3: begin
                    if (din == 1'b1) state <= S4;
                    else             state <= S2; // '1,0,1,0' -> last two bits are '1,0'
                end
                S4: begin
                    // Overlapping pattern check for 1,0,1,1...
                    // If next bit is 1: sequence becomes ...1,1. Last bit is 1 (S1).
                    // If next bit is 0: sequence becomes ...1,0. Last two bits are 1,0 (S2).
                    if (din == 1'b1) state <= S1;
                    else             state <= S2;
                end
                default: state <= S0;
            endcase
        end
    end

    // Moore output depends only on current state
    assign detected = (state == S4);

endmodule
```

```verilog
module tb;
    reg clk;
    reg rst;
    reg din;
    wire detected;

    integer passed;
    integer total;

    seqdet_moore uut (
        .clk(clk),
        .rst(rst),
        .din(din),
        .detected(detected)
    );

    always #5 clk = ~clk;

    task check_output(input bit expected_det, input string msg);
        begin
            #1; // Wait for combinational logic/state update to settle
            if (detected !== expected_det) begin
                $display("FAIL: %s | din=%b, rst=%b, expected detected=%b, actual=%b", msg, din, rst, expected_det, detected);
                passed = passed - 1;
            end else begin
                passed = passed + 1;
            end
            total = total + 1;
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
        din = 1; // din is ignored during reset
        #1;
        if (detected !== 0) begin
            $display("FAIL: Resetting | expected detected=0, actual=%b", detected);
            passed = passed - 1;
        end else begin
            passed = passed + 1;
        end
        total = total + 1;

        rst = 0;
        @(posedge clk); 
        check_output(0, "Post-reset idle");

        // Test Case 1: Simple pattern 1, 0, 1, 1
        din = 1; @(posedge clk); check_output(0, "Pattern bit 1"); // S1
        din = 0; @(posedge clk); check_output(0, "Pattern bit 2"); // S2
        din = 1; @(posedge clk); check_output(0, "Pattern bit 3"); // S3
        din = 1; @(posedge clk); check_output(1, "Pattern bit 4 (Match)"); // S4

        // Test Case 2: Overlap pattern 1, 0, 1, 1, 0, 1, 1
        din = 0; @(posedge clk); check_output(0, "Overlap bit 5"); // S2
        din = 1; @(posedge clk); check_output(0, "Overlap bit 6"); // S3
        din = 1; @(posedge clk); check_output(1, "Overlap bit 7 (Match)"); // S4

        // Test Case 3: Reset mid-sequence
        din = 1; @(posedge clk); check_output(0, "Seq bit 8"); // S1
        din = 0; @(posedge clk); check_output(0, "Seq bit 9"); // S2
        din = 1; @(posedge clk); check_output(0, "Seq bit 10"); // S3
        rst = 1; din = 1; @(posedge clk); check_output(0, "Resetting mid-seq"); 
        rst = 0;

        // Test Case 4: Wrong bits (1, 0, 1, 0)
        din = 1; @(posedge clk); check_output(0, "Wrong bit 1"); // S1
        din = 0; @(posedge clk); check_output(0, "Wrong bit 2"); // S2
        din = 1; @(posedge clk); check_output(0, "Wrong bit 3"); // S3
        din = 0; @(posedge clk); check_output(0, "Wrong bit 4 (Pattern broken)"); // S2

        // Test Case 5: Corner case - all ones
        // Current state is S2.
        din = 1; @(posedge clk); check_output(0, "All ones 1"); // S3
        din = 1; @(posedge clk); check_output(1, "All ones 2 (Match)"); // S4
        din = 1; @(posedge clk); check_output(0, "All ones 3"); // S1

        // Test Case 6: All zeros
        din = 0; @(posedge clk); check_output(0, "All zeros 1"); // S0
        din = 0; @(posedge clk); check_output(0, "All zeros 2"); // S0

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```