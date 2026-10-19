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

    // Reference Model State Machine
    reg [2:0] model_state;
    reg model_detected;

    always #5 clk = ~clk;

    task check;
        begin
            total = total + 1;
            if (detected === model_detected) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: time=%0d expected=%b actual=%b", $time, model_detected, detected);
            end
        end
    endtask

    // Update reference model on clock edges
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
            model_detected <= (model_state == 3'd4); // Note: Moore output logic is slightly tricky in ref model
            // To match the RTL exactly, we need to calculate what the state WILL be after this edge.
            // But since it's a Moore machine, 'detected' depends on the state reached AFTER the edge.
        end
    end

    // Corrected Reference Model: The output is based on the state *after* the transition.
    // We use a separate block to track the "next" state logic for the model.
    reg [2:0] next_state;
    always @(posedge clk) begin
        if (rst) begin
            model_state <= 3'd0;
            model_detected <= 1'b0;
        end else begin
            // The state transitions based on din at the rising edge.
            // The output 'detected' is high if the NEW state is S4.
            case (model_state)
                3'd0: next_state = (din == 1'b1) ? 3'd1 : 3'd0;
                3'd1: next_state = (din == 1'b0) ? 3'd2 : 3'd1;
                3'd2: next_state = (din == 1'b1) ? 3'd3 : 3'd0;
                3'd3: next_state = (din == 1'b1) ? 3'd4 : 3'd2;
                3'd4: next_state = (din == 1'b1) ? 3'd1 : 3'd2;
                default: next_state = 3'd0;
            endcase
            model_state <= next_state;
            model_detected <= (next_state == 3'd4);
        end
    end

    task reset_dut;
        begin
            rst = 1;
            din = 0;
            @(negedge clk);
            rst = 0;
            // Wait for state to settle in S0
            @(posedge clk); #1;
            if (detected !== 0) $display("FAIL: Reset failed. detected=%b", detected);
            else passed = passed + 1, total = total + 1; // Manual count for reset check
        end
    endtask

    task drive_bit(input b);
        begin
            @(negedge clk);
            din = b;
            @(posedge clk); #1;
            check;
        end
    endtask

    initial begin
        clk = 0;
        rst = 0;
        din = 0;
        passed = 0;
        total = 0;

        // Test Reset
        reset_dut();

        // Test Pattern: 1, 0, 1, 1 (Detects)
        drive_bit(1); // S1
        drive_bit(0); // S2
        drive_bit(1); // S3
        drive_bit(1); // S4 -> detected=1

        // Test Overlap: 1, 0, 1, 1, 0, 1, 1 (Detects at bit 4 and bit 7)
        // Current state is S4. Next bits are 0, 1, 1.
        drive_bit(0); // S2
        drive_bit(1); // S3
        drive_bit(1); // S4 -> detected=1

        // Test Reset mid-sequence
        drive_bit(1); // S1
        drive_bit(0); // S2
        @(negedge clk); rst = 1; @(posedge clk); #1;
        if (detected !== 0) $display("FAIL: Reset mid-sequence failed. detected=%b", detected);
        else passed = passed + 1, total = total + 1;
        rst = 0;

        // Test No Pattern
        drive_bit(0);
        drive_bit(0);
        drive_bit(1);
        drive_bit(1); // Should be S1 (not S4)
        
        // Test sequence with wrong bit: 1, 0, 1, 0...
        reset_dut();
        drive_bit(1);
        drive_bit(0);
        drive_bit(1);
        drive_bit(0); // S2
        drive_bit(1); // S3
        drive_bit(1); // S4

        // Final check for random bits
        drive_bit(0);
        drive_bit(0);
        drive_bit(0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
