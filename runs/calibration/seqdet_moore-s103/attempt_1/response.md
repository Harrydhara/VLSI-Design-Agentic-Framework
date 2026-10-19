```verilog
module seqdet_moore(
    input   clk,
    input   rst,
    input   din,
    output  detected
);

    // State encoding for Moore machine
    // S0: Reset/Idle (nothing detected)
    // S1: Detected '1'
    // S2: Detected '1, 0'
    // S3: Detected '1, 0, 1'
    // S4: Detected '1, 0, 1, 1' (Pattern complete)
    reg [2:0] state;
    parameter S0 = 3'd0;
    parameter S1 = 3'd1;
    parameter S2 = 3'd2;
    parameter S3 = 3'd3;
    parameter S4 = 3'd4;

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
                    else             state <= S2; // Pattern '1,0,1,0' -> last two are '1,0', go to S2
                end
                S4: begin
                    // Overlapping pattern check for 1,0,1,1...
                    // If next bit is 1: sequence becomes ...1,1. Last bit is 1 (S1).
                    // If next bit is 0: sequence becomes ...1,0. Last two are 1,0 (S2).
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

    integer i;
    integer passed;
    integer total;

    seqdet_moore uut (
        .clk(clk),
        .rst(rst),
        .din(din),
        .detected(detected)
    );

    always #5 clk = ~clk;

    task check_bit(input bit expected_val, input bit in_val);
        begin
            @(posedge clk);
            #1; // Wait for logic to settle after edge
            din = in_val; 
            // Note: The spec says din is sampled on rising edge. 
            // In a testbench, we change din slightly AFTER the edge or use non-blocking.
            // To simulate real behavior: apply input at edge, check output after edge.
        end
    endtask

    initial begin
        clk = 0;
        rst = 1;
        din = 0;
        passed = 0;
        total = 0;

        // Reset sequence
        @(posedge clk);
        #1;
        rst = 0;

        // Test Case 1: Basic pattern 1, 0, 1, 1
        // Sequence: 1 -> 0 -> 1 -> 1
        apply_bit(1); // S1
        check_out(0);
        apply_bit(0); // S2
        check_out(0);
        apply_bit(1); // S3
        check_out(0);
        apply_bit(1); // S4
        check_out(1);
        apply_bit(0); // S2 (overlapping check)
        check_out(0);

        // Test Case 2: Overlapping pattern 1, 0, 1, 1, 0, 1, 1
        // Reset first
        @(posedge clk); #1 rst = 1; @(posedge clk); #1 rst = 0;
        
        apply_bit(1); // S1
        check_out(0);
        apply_bit(0); // S2
        check_out(0);
        apply_bit(1); // S3
        check_out(0);
        apply_bit(1); // S4 (Detected!)
        check_out(1);
        apply_bit(0); // S2
        check_out(0);
        apply_bit(1); // S3
        check_out(0);
        apply_bit(1); // S4 (Detected!)
        check_out(1);

        // Test Case 3: Reset mid-sequence
        @(posedge clk); #1 rst = 1; @(posedge clk); #1 rst = 0;
        apply_bit(1); // S1
        check_out(0);
        apply_bit(0); // S2
        check_out(0);
        apply_bit(1); // S3
        check_out(0);
        @(posedge clk); #1 rst = 1; @(posedge clk); #1 rst = 0; // Reset at edge of bit 4
        // The spec says: "The bit on din at that edge is ignored."
        // So if we reset while in S3, we go to S0.
        check_out(0);

        // Test Case 4: Random noise
        apply_bit(0); check_out(0);
        apply_bit(0); check_out(0);
        apply_bit(1); check_out(0);
        apply_bit(1); check_out(0);
        apply_bit(1); check_out(0);
        apply_bit(0); check_out(0);
        apply_bit(1); check_out(0);
        apply_bit(1); check_out(1);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

    task apply_bit(input bit b);
        begin
            @(posedge clk);
            #1; // Ensure we are after the edge
            din = b;
        end
    endtask

    task check_out(input bit expected);
        begin
            total = total + 1;
            // We must wait for the state to update. Since it's a Moore machine,
            // 'detected' changes right after the clock edge.
            // In our testbench, we use #1 delay to look at the value.
            if (detected !== expected) begin
                $display("FAIL: din=%b, rst=%b, expected detected=%b, actual detected=%b", din, rst, expected, detected);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

endmodule
```