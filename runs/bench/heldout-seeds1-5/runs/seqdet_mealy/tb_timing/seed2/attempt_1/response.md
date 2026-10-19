```verilog
module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    // State encoding for the sequence 1 -> 1 -> 0 (Mealy output on next 1)
    // S0: Idle / Reset
    // S1: Saw '1'
    // S2: Saw '1, 1'
    // S3: Saw '1, 1, 0'
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
                    if (din) state <= S1;
                    else     state <= S0;
                end
                S1: begin
                    if (din) state <= S2;
                    else     state <= S0;
                end
                S2: begin
                    if (din) state <= S2; // Stay in S2 if we see 1,1,1... pattern
                    else     state <= S3;
                end
                S3: begin
                    if (din) state <= S1; // Pattern 1,1,0,1 completed. Next bit is '1' -> S1
                    else     state <= S0;
                end
                default: state <= S0;
            endcase
        end
    end

    // Mealy output: detected is high if we are in S3 and current din is 1
    assign detected = (state == S3 && din == 1'b1);

endmodule
```

```verilog
module tb;
    reg clk;
    reg rst_n;
    reg din;
    wire detected;

    seqdet_mealy uut (
        .clk(clk),
        .rst_n(rst_n),
        .din(din),
        .detected(detected)
    );

    integer passed = 0;
    integer total = 0;
    reg model_detected;

    // Reference Model logic
    // The state machine in the design is:
    // S0 --1--> S1 --1--> S2 --0--> S3 --1--> (Output=1, State=S1)
    // We track the sequence manually for the reference model.
    reg [3:0] shift_reg; 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 4'b0000;
        end else begin
            shift_reg <= {shift_reg[2:0], din};
        end
    end

    // Mealy output depends on current state AND current input.
    // The design uses the internal 'state' which is updated at posedge clk.
    // So detected = (state_after_last_clk == S3 && current_din == 1).
    // In our shift reg model, if we just sampled din, the state corresponds to shift_reg[2:0].
    // The sequence 1,1,0 is represented by shift_reg[2:0] == 3'b110.
    
    task check;
        begin
            total = total + 1;
            if (detected === model_detected) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: time=%0d din=%b detected=%b expected=%b", $time, din, detected, model_detected);
            end
        end
    endtask

    // Update the reference model for Mealy output
    // Since it's combinational based on state and din, we update it whenever din or state changes.
    // However, to keep it simple in TB: 
    // The design 'state' is updated at posedge clk. 
    // So after posedge clk, the 'detected' output depends on the NEW state and current 'din'.
    always @(*) begin
        // We use a small delay to allow the RTL state to update before calculating model
        // But in a real testbench we should be careful. 
        // Let's simulate the logic: detected is high if previous bits were 1,1,0 and current is 1.
        // In terms of shift_reg (which contains [din, bit2, bit1, bit0]):
        // If we just finished a clock edge, shift_reg[3] is the din that was just sampled.
        // The bits before it are shift_reg[2:0].
        // So if shift_reg[2:0] == 3'b110 and current din (which will be shift_reg[3]) is 1...
        // Wait, the design uses 'state'. Let's just mimic the state machine.
    end

    // Corrected Reference Model for Mealy Output
    reg [1:0] model_state;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) model_state <= 2'b00;
        else begin
            case (model_state)
                2'b00: if (din) model_state <= 2'b01; else model_state <= 2'b00;
                2'b01: if (din) model_state <= 2'b10; else model_state <= 2'b00;
                2'b10: if (din) model_state <= 2'b10; else model_state <= 2'b11;
                2'b11: if (din) model_state <= 2'b01; else model_state <= 2'b00;
                default: model_state <= 2'b00;
            endcase
        end
    end

    // The Mealy output is based on the state BEFORE the current din is processed? 
    // No, the spec says "detected is 1 exactly when the last three bits sampled... were 1,1,0 and din is currently 1".
    // This means if we are in S3 (having seen 1,1,0), and din becomes 1, detected goes high immediately.
    
    // Let's use a simpler model: track the last 4 bits.
    reg [3:0] history;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) history <= 4'b0000;
        else history <= {history[2:0], din};
    end

    // The Mealy output 'detected' is high if the sequence [din, bit_prev1, bit_prev2, bit_prev3] == 1,0,1,1
    // Wait, the pattern is 1,1,0,1. So history[3:0] would be 1,0,1,1? No.
    // If din=1 and previous bits were 1,1,0, then the sequence is 1,1,0,1.
    // In terms of history (where history[0] is oldest):
    // At the moment din is high, if history[2:0] was 1,1,0...
    // Let's just use the state machine logic for the model.
    
    // Since 'detected' is Mealy, it changes as soon as 'din' changes or 'state' changes.
    // The design 'state' updates at posedge clk. 
    // So if we are in S3 and din transitions from 0 to 1, detected goes high immediately.

    always @(*) begin
        // We need to know the state that is currently held by the RTL.
        // Since we can't see internal signals, we use our model_state.
        // But model_state updates at posedge clk. At any time between edges, 
        // model_state holds the state from the PREVIOUS edge.
        model_detected = (model_state == 2'b11 && din == 1'b1);
    end

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    task reset_dut;
        begin
            rst_n = 0;
            din = 0;
            @(negedge clk);
            rst_n = 1;
            #1;
        end
    endtask

    task drive(input b);
        begin
            @(negedge clk);
            din = b;
            // Mealy output can change immediately when din changes.
            // However, the spec says "detected is 1 exactly when...".
            // We check after the transition to ensure it's stable or at the right time.
            #1; 
            check;
        end
    endtask

    initial begin
        reset_dut();
        
        // Test Case 1: Basic sequence 1, 1, 0, 1
        drive(1); // S0 -> S1
        drive(1); // S1 -> S2
        drive(0); // S2 -> S3
        drive(1); // S3 + din=1 -> detected=1. State becomes S1.
        
        // Test Case 2: Overlapping 1, 1, 0, 1, 1, 0, 1
        // Current state is S1 (from previous sequence).
        // We need to complete 1, 1, 0, 1 again.
        // Sequence so far: ...1 (last bit of prev)
        drive(1); // S1 -> S2
        drive(0); // S2 -> S3
        drive(1); // S3 + din=1 -> detected=1. State becomes S1.
        
        // Test Case 3: No pattern
        reset_dut();
        drive(0);
        drive(1);
        drive(0);
        drive(0);
        drive(1);
        drive(1);
        drive(1); // Should not trigger

        // Test Case 4: Reset during sequence
        reset_dut();
        drive(1);
        drive(1);
        drive(0);
        #2 rst_n = 0;
        #2 rst_n = 1;
        // After reset, state is S0. din is still 0 (from before).
        // We must drive again to see if it works.
        drive(1);
        drive(1);
        drive(0);
        drive(1); // Should detect

        // Test Case 5: Mealy behavior - change din while in S3
        reset_dut();
        drive(1); // S1
        drive(1); // S2
        drive(0); // S3
        // Now we are in S3. If we change din to 1, detected should go high immediately.
        @(negedge clk);
        din = 1;
        #1;
        total = total + 1;
        if (detected === 1) passed = passed + 1;
        else $display("FAIL: Mealy transition not immediate. din=%b detected=%b", din, detected);
        // Note: The drive task calls check(), which compares with model_detected.
        // Our model_detected is updated via always @(*) based on model_state and din.
        // Since model_state is S3 and din becomes 1, model_detected becomes 1.

        // Test Case 6: All zeros
        reset_dut();
        drive(0); drive(0); drive(0); drive(0); drive(0);

        // Test Case 7: All ones (should not trigger)
        reset_dut();
        drive(1); drive(1); drive(1); drive(1); drive(1);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```