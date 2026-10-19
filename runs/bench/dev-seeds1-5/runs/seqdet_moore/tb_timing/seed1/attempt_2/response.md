```verilog
module seqdet_moore(
    input   clk,
    input   rst,
    input   din,
    output  detected
);

    // State encoding for Moore machine
    // S0: Idle/Reset (No bits matched)
    // S1: Detected '1'
    // S2: Detected '10'
    // S3: Detected '101'
    // S4: Detected '1011' (Output 1)
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
                    else             state <= S2; // Pattern '1010', last two bits are '10' -> S2
                end
                S4: begin
                    // Overlapping pattern check for 1011...
                    // If next bit is 1, we have ...11. The last bit is '1', so go to S1.
                    // If next bit is 0, we have ...110. The last two bits are '10', so go to S2.
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

    seqdet_moore uut (
        .clk(clk),
        .rst(rst),
        .din(din),
        .detected(detected)
    );

    integer passed, total;

    // Reference Model State
    reg [2:0] m_state;
    reg model_out;

    // The reference model must update on the same clock edge as the design
    always @(posedge clk) begin
        if (rst) begin
            m_state <= 3'd0;
            model_out <= 1'b0;
        end else begin
            case (m_state)
                3'd0: if (din == 1'b1) m_state <= 3'd1; else m_state <= 3'd0;
                3'd1: if (din == 1'b0) m_state <= 3'd2; else m_state <= 3'd1;
                3'd2: if (din == 1'b1) m_state <= 3'd3; else m_state <= 3'd0;
                3'd3: if (din == 1'b1) m_state <= 3'd4; else m_state <= 3'd2;
                3'd4: if (din == 1'b1) m_state <= 3'd1; else m_state <= 3'd2;
                default: m_state <= 3'd0;
            endcase
            // Moore output is determined by the state reached AFTER the edge
            // However, in a synchronous system, model_out should reflect the new state.
            // We use a temporary variable to calculate what the next state will be.
        end
    end

    // To correctly simulate Moore output (which depends on current state), 
    // we need to know the state that exists after the clock edge.
    // Since 'detected' is combinational based on 'state', model_out should follow.
    always @(*) begin
        model_out = (m_state == 3'd4);
    end

    task check;
        begin
            total = total + 1;
            if (detected !== model_out) begin
                $display("FAIL: time=%0d din=%b expected=%b actual=%b", $time, din, model_out, detected);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    task drive_bit(input b);
        begin
            @(negedge clk);
            din = b;
            @(posedge clk);
            #1 check;
        end
    endtask

    initial begin
        // Initialize
        clk = 0;
        rst = 0;
        din = 0;
        passed = 0;
        total = 0;
        
        always #5 clk = ~clk;

        // Reset sequence
        @(negedge clk);
        rst = 1;
        #2; // Assert reset between edges
        @(posedge clk);
        #1;
        // Check after reset (reset is synchronous, so we check after the edge where rst=1)
        if (detected !== 0) $display("FAIL: Reset failed. detected=%b", detected);
        else passed = passed + 1;
        total = total + 1;
        rst = 0;

        // Test Case 1: Simple pattern 1, 0, 1, 1
        drive_bit(1); // S1
        drive_bit(0); // S2
        drive_bit(1); // S3
        drive_bit(1); // S4 (detected should be 1)

        // Test Case 2: Overlapping pattern 1, 0, 1, 1, 0, 1, 1
        // We are currently at S4. Next bits: 0, 1, 1
        drive_bit(0); // S2 (from S4)
        drive_bit(1); // S3
        drive_bit(1); // S4 (detected should be 1)

        // Test Case 3: No pattern
        @(negedge clk); rst = 1; #2; @(posedge clk); #1 check; rst = 0;
        drive_bit(0);
        drive_bit(0);
        drive_bit(1);
        drive_bit(1);
        drive_bit(0);

        // Test Case 4: Pattern with reset in middle
        drive_bit(1);
        drive_bit(0);
        @(negedge clk); rst = 1; #2; @(posedge clk); #1 check; rst = 0;
        drive_bit(1);
        drive_bit(0);
        drive_bit(1);
        drive_bit(1);

        // Test Case 5: All ones (should stay in S1)
        @(negedge clk); rst = 1; #2; @(posedge clk); #1 check; rst = 0;
        drive_bit(1);
        drive_bit(1);
        drive_bit(1);
        drive_bit(1);

        // Test Case 6: All zeros (should stay in S0)
        @(negedge clk); rst = 1; #2; @(posedge clk); #1 check; rst = 0;
        drive_bit(0);
        drive_bit(0);
        drive_bit(0);
        drive_bit(0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```