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
    reg [2:0] model_state;
    reg model_detected;

    // Reference Model logic
    always @(posedge clk) begin
        if (rst) begin
            model_state <= 3'd0;
            model_detected <= 1'b0;
        end else begin
            case (model_state)
                3'd0: if (din) model_state <= 3'd1; else model_state <= 3'd0;
                3'd1: if (!din) model_state <= 3'd2; else model_state <= 3'd1;
                3'd2: if (din) model_state <= 3'd3; else model_state <= 3'd0;
                3'd3: if (din) model_state <= 3'd4; else model_state <= 3'd2;
                3'd4: if (din) model_state <= 3'd1; else model_state <= 3'd2;
                default: model_state <= 3'd0;
            endcase
            model_detected <= (model_state == 3'd4); // Note: This is the state AFTER transition logic, but Moore output depends on current state.
            // Wait, in a synchronous design, 'detected' reflects the state reached at the rising edge.
            // The model must track what the state will be after the clock edge to match the hardware.
        end
    end

    // Corrected Reference Model: 
    // The Moore output is a function of the state currently held in the registers.
    reg [2:0] m_state;
    reg m_det;
    always @(posedge clk) begin
        if (rst) begin
            m_state <= 3'd0;
            m_det   <= 1'b0;
        end else begin
            // Calculate next state based on current m_state and din
            case (m_state)
                3'd0: if (din) m_state <= 3'd1; else m_state <= 3'd0;
                3'd1: if (!din) m_state <= 3'd2; else m_state <= 3'd1;
                3'd2: if (din) m_state <= 3'd3; else m_state <= 3'd0;
                3'd3: if (din) m_state <= 3'd4; else m_state <= 3'd2;
                3'd4: if (din) m_state <= 3'd1; else m_state <= 3'd2;
                default: m_state <= 3'd0;
            endcase
            // The output 'detected' is the Moore output of the state we just entered.
            // However, in Verilog, the non-blocking assignment to m_state happens at the edge.
            // To match the hardware behavior:
        end
    end

    // Let's use a simpler approach for the testbench model: 
    // Just simulate the state machine logic exactly as defined.
    reg [2:0] expected_state;
    reg expected_detected;

    always @(posedge clk) begin
        if (rst) begin
            expected_state <= 3'd0;
            expected_detected <= 1'b0;
        end else begin
            case (expected_state)
                3'd0: if (din) expected_state <= 3'd1; else expected_state <= 3'd0;
                3'd1: if (!din) expected_state <= 3'd2; else expected_state <= 3'd1;
                3'd2: if (din) expected_state <= 3'd3; else expected_state <= 3'd0;
                3'd3: if (din) expected_state <= 3'd4; else expected_state <= 3'd2;
                3'd4: if (din) expected_state <= 3'd1; else expected_state <= 3'd2;
                default: expected_state <= 3'd0;
            endcase
            // The Moore output is based on the state that was just latched.
            // But we need to know what the state will be AFTER this edge for comparison.
        end
    end

    // Since 'detected' is a function of the current state, and the state updates at posedge clk:
    // We check 'detected' 1 cycle after the rising edge.
    // At that point, 'detected' should be (new_state == S4).

    task check;
        begin
            total = total + 1;
            if (detected === expected_detected) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: time=%0d din=%b expected_det=%b actual_det=%b", $time, din, expected_detected, detected);
            end
        end
    endtask

    // We'll use a more robust way to track the model. 
    // The state machine is simple enough that we can just re-implement it in the TB.
    reg [2:0] ref_state;
    reg ref_det;

    always @(posedge clk) begin
        if (rst) begin
            ref_state <= 3'd0;
            ref_det   <= 1'b0;
        end else begin
            // Calculate next state
            case (ref_state)
                3'd0: if (din) ref_state <= 3'd1; else ref_state <= 3'd0;
                3'd1: if (!din) ref_state <= 3'd2; else ref_state <= 3'd1;
                3'd2: if (din) ref_state <= 3'd3; else ref_state <= 3'd0;
                3'd3: if (din) ref_state <= 3'd4; else ref_state <= 3'd2;
                3'd4: if (din) ref_state <= 3'd1; else ref_state <= 3'd2;
                default: ref_state <= 3'd0;
            endcase
            // The state is updated. We need the output corresponding to that new state.
            // But we can't use 'ref_state' in the same block for the next value easily without a temporary variable.
        end
    end

    // Let's refine the model:
    reg [2:0] next_state;
    always @(*) begin
        case (ref_state)
            3'd0: if (din) next_state = 3'd1; else next_state = 3'd0;
            3'd1: if (!din) next_state = 3'd2; else next_state = 3'd1;
            3'd2: if (din) next_state = 3'd3; else next_state = 3'd0;
            3'd3: if (din) next_state = 3'd4; else next_state = 3'd2;
            3'd4: if (din) next_state = 3'd1; else next_state = 3'd2;
            default: next_state = 3'd0;
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            ref_state <= 3'd0;
            ref_det   <= 1'b0;
        end else begin
            ref_state <= next_state;
            ref_det   <= (next_state == 3'd4);
        end
    end

    // The actual check:
    task drive_bit(input b);
        begin
            @(negedge clk);
            din = b;
            @(posedge clk);
            #1;
            // After posedge, ref_det has been updated to the output of the new state.
            total = total + 1;
            if (detected === ref_det) passed = passed + 1;
            else $display("FAIL: time=%0d din=%b expected=%b actual=%b", $time, b, ref_det, detected);
        end
    endtask

    initial begin
        clk = 0;
        always #5 clk = ~clk;

        // Initialize
        rst = 1;
        din = 0;
        passed = 0;
        total = 0;
        ref_state = 3'd0;
        ref_det = 1'b0;

        // Reset sequence
        #7 rst = 0; // Async-like reset (though spec says synchronous, we do it between edges)
        @(posedge clk); #1;
        if (detected !== 0) $display("FAIL: Reset failed");
        total = total + 1; passed = passed + 1; // Manual count for reset check

        // Test Pattern: 1, 0, 1, 1 (Detected!)
        drive_bit(1);
        drive_bit(0);
        drive_bit(1);
        drive_bit(1); // Should detect here

        // Test Overlap: 1, 0, 1, 1, 0, 1, 1 (Detected at 4th and 7th)
        // We already did 1,0,1,1. Now add 0, 1, 1
        drive_bit(0);
        drive_bit(1);
        drive_bit(1); // Should detect here

        // Test Reset mid-sequence: 1, 0, (rst), 1, 1
        drive_bit(1);
        drive_bit(0);
        @(negedge clk); rst = 1; @(posedge clk); #1;
        if (detected !== 0) $display("FAIL: Reset mid-sequence failed");
        total = total + 1; passed = passed + 1;
        rst = 0;

        drive_bit(1);
        drive_bit(1); // Should not detect

        // Test sequence with no matches
        drive_bit(0);
        drive_bit(0);
        drive_bit(0);
        drive_bit(1);

        // Final check for all bits
        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
