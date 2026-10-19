```verilog
module seqdet_moore(
    input   clk,
    input   rst,
    input   din,
    output  detected
);

    // State encoding for Moore machine
    // S0: Idle/Reset
    // S1: Detected '1'
    // S2: Detected '10'
    // S3: Detected '101'
    // S4: Detected '1011' (Pattern complete)
    reg [2:0] state;

    localparam S0 = 3'd0;
    localparam S1 = 3'd1;
    localparam S2 = 3'd2;
    localparam S3 = 3'd3;
    localparam S4 = 3'd4;

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
                    else             state <= S0;
                end
                S4: begin
                    // Overlapping patterns logic:
                    // If next is 0, sequence ends in ...10. State -> S2.
                    // If next is 1, sequence ends in ...11. The last '1' could be start of new pattern? No, 1011 needs a 0.
                    // Actually, if we see 1011 and then another 1, the suffix is "1", so state -> S1.
                    if (din == 1'b0) state <= S2;
                    else             state <= S1;
                end
                default: state <= S0;
            endcase
        end
    end

    assign detected = (state == S4);

endmodule
```

```verilog
module tb;
    reg clk;
    reg rst;
    reg din;
    wire detected;

    seqdet_moore uut (
        .clk(clk),
        .rst(rst),
        .din(din),
        .detected(detected)
    );

    integer passed, total;
    reg [2:0] m_state;

    // Reference Model
    always @(posedge clk) begin
        if (rst) begin
            m_state <= 3'd0;
        end else begin
            case (m_state)
                3'd0: if (din == 1'b1) m_state <= 3'd1; else m_state <= 3'd0;
                3'd1: if (din == 1'b0) m_state <= 3'd2; else m_state <= 3'd1;
                3'd2: if (din == 1'b1) m_state <= 3'd3; else m_state <= 3'd0;
                3'd3: if (din == 1'b1) m_state <= 3'd4; else m_state <= 3'd0;
                3'd4: if (din == 1'b0) m_state <= 3'd2; else m_state <= 3'd1;
                default: m_state <= 3'd0;
            endcase
        end
    end

    task check;
      begin
        total = total + 1;
        if (detected === (m_state == 3'd4)) passed = passed + 1;
        else $display("FAIL: time=%0d expected=%b actual=%b", $time, (m_state == 3'd4), detected);
      end
    endtask

    task feed(input b);
      begin
        @(negedge clk); din = b;
        @(posedge clk); #1 check;
      end
    endtask

    initial begin
        // Initialize clock and signals
        clk = 0;
        always #5 clk = ~clk;
        
        passed = 0;
        total = 0;
        rst = 1;
        din = 0;

        // Synchronous Reset: Apply rst=1 on a rising edge.
        // The spec says "on a rising edge with rst=1 the detector forgets... bit on din at that edge is ignored"
        @(posedge clk);
        #0 rst = 1; // Ensure it's high at the edge
        @(posedge clk); #1;
        // Check reset state
        total = total + 1;
        if (detected === 0) passed = passed + 1;
        else $display("FAIL: Reset failed. detected=%b", detected);

        rst = 0;
        @(negedge clk); din = 0; // Ensure clean start

        // Test Case 1: Simple pattern 1, 0, 1, 1
        feed(1); // S1
        feed(0); // S2
        feed(1); // S3
        feed(1); // S4 (detected=1)

        // Test Case 2: Overlapping patterns 1, 0, 1, 1, 0, 1, 1
        // Current state is S4. Next bit is 0.
        feed(0); // S2
        feed(1); // S3
        feed(1); // S4 (detected=1)

        // Test Case 3: Reset mid-sequence
        feed(1); // S1
        feed(0); // S2
        @(negedge clk); rst = 1; din = 1; // Set reset and a bit
        @(posedge clk); #1;
        total = total + 1;
        if (detected === 0) passed = passed + 1;
        else $display("FAIL: Reset mid-seq failed. detected=%b", detected);
        
        @(negedge clk); rst = 0; din = 0;
        @(posedge clk); #1; // Check state after reset release

        // Test Case 4: No pattern (all ones)
        feed(1); feed(1); feed(1); feed(1);

        // Test Case 5: Pattern with trailing zeros
        reset_dut_task();
        feed(1); feed(0); feed(1); feed(1); // S4
        feed(0); // S2
        feed(0); // S0

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

    task reset_dut_task;
      begin
        @(negedge clk); rst = 1; din = 0;
        @(posedge clk); #1;
        rst = 0;
        total = total + 1;
        if (detected === 0) passed = passed + 1;
        else $display("FAIL: reset_dut_task failed. detected=%b", detected);
      end
    endtask

endmodule
```