```verilog
module seqdet_moore(
    input   clk,
    input   rst,
    input   din,
    output  detected
);

    // State encoding for Moore machine
    // S0: Idle / Reset state
    // S1: Detected '1'
    // S2: Detected '10'
    // S3: Detected '101'
    // S4: Detected '1011' (Pattern complete)
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
                    else             state <= S2; // Pattern '1010', last two are '10'
                end
                S4: begin
                    // Overlapping pattern check for 1011...
                    // If next bit is 1, we have ...10111 -> state becomes S1 (last bit was 1)
                    // If next bit is 0, we have ...10110 -> state becomes S2 (last two were 10)
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
                3'd0: if (din == 1'b1) model_state <= 3'd1; else model_state <= 3'd0;
                3'd1: if (din == 1'b0) model_state <= 3'd2; else model_state <= 3'd1;
                3'd2: if (din == 1'b1) model_state <= 3'd3; else model_state <= 3'd0;
                3'd3: if (din == 1'b1) model_state <= 3'd4; else model_state <= 3'd2;
                3'd4: if (din == 1'b1) model_state <= 3'd1; else model_state <= 3'd2;
                default: model_state <= 3'd0;
            endcase
            // Moore output is based on the state reached after the edge
            if (model_state == 3'd4 || (rst == 0 && (
                (model_state == 3'd0 && din == 1'b1 && 3'd1 == 3'd4) || // impossible logic for clarity
                (model_state == 3'd1 && din == 1'b0 && 3'd2 == 3'd4) ||
                (model_state == 3'd2 && din == 1'b1 && 3'd3 == 3'd4) ||
                (model_state == 3'd3 && din == 1'b1 && 3'd4 == 3'd4) ||
                (model_state == 3'd4 && din == 1'b1 && 3'd1 == 3'd4) ||
                (model_state == 3'd4 && din == 1'b0 && 3'd2 == 3'd4)
            ))) begin
                 // This is getting messy, let's just use a simple state transition logic for model_detected
            end
        end
    end

    // Simpler Reference Model
    always @(posedge clk) begin
        if (rst) begin
            model_state <= 3'd0;
            model_detected <= 1'b0;
        end else begin
            // Calculate next state based on current model_state and din
            case (model_state)
                3'd0: if (din == 1'b1) model_state <= 3'd1; else model_state <= 3'd0;
                3'd1: if (din == 1'b0) model_state <= 3'd2; else model_state <= 3'd1;
                3'd2: if (din == 1'b1) model_state <= 3'd3; else model_state <= 3'd0;
                3'd3: if (din == 1'b1) model_state <= 3'd4; else model_state <= 3'd2;
                3'd4: if (din == 1'b1) model_state <= 3'd1; else model_state <= 3'd2;
                default: model_state <= 3'd0;
            endcase
        end
    end

    // The Moore output is a function of the state. 
    // Since 'model_state' updates on posedge, and we check #1 after posedge,
    // 'model_detected' should be updated to reflect the NEW model_state.
    always @(posedge clk) begin
        if (rst) model_detected <= 1'b0;
        else     model_detected <= (model_state == 3'd4); // This is wrong, it must follow the state update
    end

    // Let's rewrite the reference model properly to avoid confusion.
    reg [2:0] m_state;
    reg m_det;
    always @(posedge clk) begin
        if (rst) begin
            m_state <= 3'd0;
            m_det   <= 1'b0;
        end else begin
            case (m_state)
                3'd0: if (din) m_state <= 3'd1; else m_state <= 3'd0;
                3'd1: if (!din) m_state <= 3'd2; else m_state <= 3'd1;
                3'd2: if (din) m_state <= 3'd3; else m_state <= 3'd0;
                3'd3: if (din) m_state <= 3'd4; else m_state <= 3'd2;
                3'd4: if (din) m_state <= 3'd1; else m_state <= 3'd2;
                default: m_state <= 3'd0;
            endcase
            // The state is updated, now the output is determined by that new state.
            // We need to look ahead or use a combinational block for model_det in the TB.
        end
    end

    // Corrected approach: Use a combinational block for the reference model's output
    // so it matches the Moore property (output = f(state)).
    reg m_det_comb;
    always @(*) begin
        m_det_comb = (m_state == 3'd4);
    end

    // Redefine check to use the combinational model output
    task check_val;
        begin
            total = total + 1;
            if (detected === m_det_comb) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: time=%0d expected=%b actual=%b", $time, m_det_comb, detected);
            end
        end
    endtask

    task reset_dut;
        begin
            rst = 1;
            din = 0;
            @(negedge clk);
            rst = 0;
            @(posedge clk); #1;
            // After reset, state is S0, so detected should be 0.
            total = total + 1;
            if (detected === 1'b0) passed = passed + 1;
            else $display("FAIL: Reset failed. expected=0 actual=%b", detected);
        end
    endtask

    task drive_bit(input b);
        begin
            @(negedge clk);
            din = b;
            @(posedge clk); #1;
            check_val();
        end
    endtask

    initial begin
        clk = 0;
        rst = 0;
        din = 0;
        passed = 0;
        total = 0;

        reset_dut();

        // Test Pattern: 1, 0, 1, 1 (Detects)
        drive_bit(1); // S1
        drive_bit(0); // S2
        drive_bit(1); // S3
        drive_bit(1); // S4 -> detected=1

        // Test Overlap: 1, 0, 1, 1, 0, 1, 1 (Detects at bit 4 and bit 7)
        drive_bit(0); // S2
        drive_bit(1); // S3
        drive_bit(1); // S4 -> detected=1

        // Test Reset mid-sequence
        drive_bit(1); // S1
        drive_bit(0); // S2
        @(negedge clk); rst = 1; @(posedge clk); #1;
        total = total + 1;
        if (detected === 1'b0) passed = passed + 1;
        else $display("FAIL: Reset mid-sequence failed. expected=0 actual=%b", detected);
        rst = 0;

        // Test No Pattern
        drive_bit(0);
        drive_bit(0);
        drive_bit(1);
        drive_bit(1); // S1
        
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
```