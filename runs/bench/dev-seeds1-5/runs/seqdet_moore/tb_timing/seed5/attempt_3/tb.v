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

    initial begin
        // Initialize clock and signals
        clk = 0;
        always #5 clk = ~clk;
        
        passed = 0;
        total = 0;
        rst = 1;
        din = 0;

        // Synchronous Reset: Apply rst=1 on a rising edge.
        @(posedge clk);
        #0 rst = 1; 
        @(posedge clk); #1;
        total = total + 1;
        if (detected === 0) passed = passed + 1;
        else $display("FAIL: Reset failed. detected=%b", detected);

        rst = 0;
        @(negedge clk); din = 0;

        // Test Case 1: Simple pattern 1, 0, 1, 1
        feed(1); // S1
        feed(0); // S2
        feed(1); // S3
        feed(1); // S4 (detected=1)

        // Test Case 2: Overlapping patterns 1, 0, 1, 1, 0, 1, 1
        feed(0); // S2
        feed(1); // S3
        feed(1); // S4 (detected=1)

        // Test Case 3: Reset mid-sequence
        feed(1); // S1
        feed(0); // S2
        @(negedge clk); rst = 1; din = 1; 
        @(posedge clk); #1;
        total = total + 1;
        if (detected === 0) passed = passed + 1;
        else $display("FAIL: Reset mid-seq failed. detected=%b", detected);
        
        @(negedge clk); rst = 0; din = 0;
        @(posedge clk); #1;

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

endmodule
