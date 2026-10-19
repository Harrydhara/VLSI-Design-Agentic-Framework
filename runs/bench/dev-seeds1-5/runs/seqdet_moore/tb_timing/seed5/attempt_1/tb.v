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
    reg model_detected;
    reg [2:0] model_state;

    // Reference Model
    always @(posedge clk) begin
        if (rst) begin
            model_state <= 3'd0;
            model_detected <= 1'b0;
        end else begin
            case (model_state)
                3'd0: if (din == 1'b1) model_state <= 3'd1; else model_state <= 3'd0;
                3'd1: if (din == 1'b0) model_state <= 3'd2; else model_state <= 3'd1;
                3'd2: if (din == 1'b1) model_state <= 3'd3; else model_state <= 3'd0;
                3'd3: if (din == 1'b1) model_state <= 3'd4; else model_state <= 3'd0;
                3'd4: if (din == 1'b0) model_state <= 3'd2; else model_state <= 3'd1;
                default: model_state <= 3'd0;
            endcase
            model_detected <= (model_state == 3'd4); // This is wrong for Moore. 
                                                    // In Moore, output depends on state *before* transition? 
                                                    // No, the spec says "during the clock cycle right after the rising edge".
                                                    // That means if at T=4 (rising edge) we enter S4, then during [T4, T5] detected is 1.
            // Let's correct model logic:
        end
    end

    // Corrected Reference Model Logic for Moore
    reg [2:0] m_state;
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

    // The output 'detected' is high when state is S4.
    // Since it's a Moore machine, the output changes at the same time as the state.
    // We check the output after the rising edge.
    
    task check;
      begin
        total = total + 1;
        if (detected === (m_state == 3'd4)) passed = passed + 1;
        else $display("FAIL: time=%0d expected=%b actual=%b", $time, (m_state == 3'd4), detected);
      end
    endtask

    task reset_dut;
      begin
        rst = 1; din = 0;
        #2; // Assert between edges or at specific time
        @(negedge clk);
        rst = 0;
        @(posedge clk); #1;
        if (detected !== 0) $display("FAIL: Reset failed. detected=%b", detected);
        else passed = passed + 1; // Manual increment for reset check
        total = total + 1;
      end
    endtask

    // Helper to feed bits
    task feed(input bit b);
      begin
        @(negedge clk); din = b;
        @(posedge clk); #1;
        check;
      end
    endtask

    initial begin
        clk = 0;
        always #5 clk = ~clk;
        passed = 0;
        total = 0;

        // Reset sequence
        rst = 1; din = 0;
        #7;
        @(negedge clk);
        rst = 0;
        @(posedge clk); #1;
        if (detected !== 0) $display("FAIL: reset error");
        else passed = passed + 1; // We count the initial state check as a pass
        total = total + 1;

        // Test Case 1: Simple pattern 1, 0, 1, 1
        feed(1); // S1
        feed(0); // S2
        feed(1); // S3
        feed(1); // S4 -> detected should be 1

        // Test Case 2: Overlapping 1, 0, 1, 1, 0, 1, 1
        // We are currently at S4. Next bit is 0.
        feed(0); // S2 (from S4)
        feed(1); // S3
        feed(1); // S4 -> detected should be 1

        // Test Case 3: No pattern
        reset_dut();
        feed(1);
        feed(1);
        feed(0);
        feed(0);
        feed(1);

        // Test Case 4: Reset mid-sequence
        reset_dut();
        feed(1);
        feed(0);
        @(negedge clk); rst = 1; // Reset during sequence
        @(posedge clk); #1;
        if (detected !== 0) $display("FAIL: reset mid-seq. detected=%b", detected);
        else passed = passed + 1; total = total + 1;
        @(negedge clk); rst = 0;

        // Test Case 5: All zeros/ones
        feed(0); feed(0); feed(0);
        feed(1); feed(1); feed(1); feed(1); // Should not trigger (needs 1011)
        
        // Test Case 6: Pattern at the very end of a stream
        reset_dut();
        feed(1); feed(0); feed(1); feed(1);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
