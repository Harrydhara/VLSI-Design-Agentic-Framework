```verilog
module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    // State encoding for the sequence 1, 1, 0 (Mealy output depends on din)
    // S0: Reset/Initial state
    // S1: Found '1'
    // S2: Found '1, 1'
    // S3: Found '1, 1, 0'
    reg [1:0] state;

    localparam S0 = 2'b00;
    localparam S1 = 2'b01;
    localparam S2 = 2'b10;
    localparam S3 = 2'b11;

    // Mealy output: depends on current state and current input din
    // If we are in S3 (found 1,1,0) and din is 1, detected is 1.
    assign detected = (state == S3 && din == 1'b1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S0;
        end else begin
            case (state)
                S0: begin
                    if (din == 1'b1) state <= S1;
                    else             state <= S0;
                end
                S1: begin
                    if (din == 1'b1) state <= S2;
                    else             state <= S0;
                end
                S2: begin
                    if (din == 1'b0) state <= S3;
                    else             state <= S2; // Stay in S2 if we get another '1' (pattern is 1,1,...)
                end
                S3: begin
                    // After 1,1,0, the next bit completes the pattern.
                    // If din=1, we found 1,1,0,1. The last three bits are 1,0,1? No.
                    // Overlap check: Pattern is 1,1,0,1.
                    // Input sequence: 1 -> S1, 1 -> S2, 0 -> S3, 1 -> (detected=1)
                    // After the '1' that triggers detection, what is the next state?
                    // The bits seen are ...1, 1, 0, 1.
                    // To check for overlap: if we just saw 1,1,0,1, the last bit was 1.
                    // This 1 could be the start of a new 1,1,0,1 sequence.
                    // However, looking at the bits: [1, 1, 0, 1]. The suffix is '1'.
                    // If we treat this '1' as the first bit of a new pattern:
                    if (din == 1'b1) state <= S1; 
                    else             state <= S0;
                end
                default: state <= S0;
            endcase
        end
    end

    // Correcting State Machine logic for overlapping 1,1,0,1
    // Let's re-evaluate the transitions to ensure overlap works.
    // Pattern: 1 -> 1 -> 0 -> 1 (detected)
    // Sequence: 1, 1, 0, 1, 1, 0, 1
    // Bits:     1  2  3  4  5  6  7
    // State transitions:
    // T=1 (din=1): S0 -> S1
    // T=2 (din=1): S1 -> S2
    // T=3 (din=0): S2 -> S3
    // T=4 (din=1): S3 -> detected=1. What is next state? 
    //              The sequence ends in ...1. This '1' could be the start of a new pattern.
    //              So S3 + din=1 should go to S1.
    // T=5 (din=1): S1 -> S2
    // T=6 (din=0): S2 -> S3
    // T=7 (din=1): S3 -> detected=1.

    // Re-writing the logic inside the always block to be more robust:
endmodule
```

Wait, I noticed a mistake in my manual trace above regarding state transitions for overlapping patterns. Let's refine the RTL and provide the complete solution.

```verilog
module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    reg [1:0] state;
    localparam S_RESET = 2'b00; // Haven't seen anything useful
    localparam S_1     = 2'b01; // Seen '1'
    localparam S_11    = 2'b10; // Seen '1, 1'
    localparam S_110   = 2'b11; // Seen '1, 1, 0'

    assign detected = (state == S_110 && din == 1'b1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_RESET;
        end else begin
            case (state)
                S_RESET: begin
                    if (din == 1'b1) state <= S_1;
                    else             state <= S_RESET;
                end
                S_1: begin
                    if (din == 1'b1) state <= S_11;
                    else             state <= S_RESET;
                end
                S_11: begin
                    if (din == 1'b0) state <= S_110;
                    else             state <= S_11; // Stay in S_11 if we see '1, 1, 1'
                end
                S_110: begin
                    if (din == 1'b1) state <= S_1;   // Pattern 1,1,0,1 completed. New start is the last '1'.
                    else             state <= S_RESET; // Pattern 1,1,0,0... reset.
                end
                default: state <= S_RESET;
            endcase
        end
    end

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

    integer passed, total;
    reg model_detected;
    reg [1:0] model_state;

    // Reference Model
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            model_state <= 2'b00;
            model_detected <= 1'b0;
        end else begin
            // The model must calculate the output based on current state AND din (Mealy)
            // But for the testbench, we need to know what the state WILL be after this edge.
            // However, Mealy output is combinational. Let's simulate it carefully.
            case (model_state)
                2'b00: if (din == 1'b1) model_state <= 2'b01; else model_state <= 2'b00;
                2'b01: if (din == 1'b1) model_state <= 2'b10; else model_state <= 2'b00;
                2'b10: if (din == 1'b0) model_state <= 2'b11; else model_state <= 2'b10;
                2'b11: if (din == 1'b1) model_state <= 2'b01; else model_state <= 2'b00;
                default: model_state <= 2'b00;
            endcase
        end
    end

    // Because Mealy output is combinational, the 'model_detected' depends on current state and din.
    // We update it in a way that matches the RTL logic.
    always @(*) begin
        if (model_state == 2'b11 && din == 1'b1)
            model_detected = 1'b1;
        else
            model_detected = 1'b0;
    end

    // Since the model state updates on posedge, and Mealy output is combinational:
    // At any time t, detected = (state_at_t == S_110 && din_at_t == 1)
    // The testbench needs to track 'state' correctly.

    task check;
        begin
            total = total + 1;
            if (detected === model_detected) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: time=%0d din=%b state_model=%b expected=%b actual=%b", 
                         $time, din, model_state, model_detected, detected);
            end
        end
    endtask

    // We need a way to track the "current" state of the model for comparison.
    // Since 'detected' is combinational, we check it whenever 'din' or 'state' changes.
    // But in a clocked testbench, we check after the clock edge.

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    task reset_dut;
        begin
            rst_n = 0;
            din = 0;
            #2;
            rst_n = 1;
            // Reset model state too
            @(negedge clk);
            model_state = 2'b00;
            #1;
        end
    endtask

    task drive(input b);
        begin
            @(negedge clk);
            din = b;
            // Mealy output can change immediately when din changes.
            // However, the specification says "detected is 1 exactly when...".
            // In a Mealy machine, we check the combinational output.
            #1; 
            check;
        end
    endtask

    initial begin
        passed = 0;
        total = 0;
        reset_dut();

        // Test Case 1: Simple sequence 1, 1, 0, 1
        drive(1); // S0 -> S1
        drive(1); // S1 -> S2
        drive(0); // S2 -> S3
        drive(1); // S3 + din=1 -> detected=1, state becomes S1

        // Test Case 2: Overlapping sequence 1, 1, 0, 1, 1, 0, 1
        // We are currently at S1 (from the last drive).
        drive(1); // S1 -> S2
        drive(0); // S2 -> S3
        drive(1); // S3 + din=1 -> detected=1, state becomes S1
        
        // Test Case 3: No pattern
        reset_dut();
        drive(0);
        drive(1);
        drive(0);
        drive(0);
        drive(1);
        drive(1);

        // Test Case 4: Reset mid-sequence
        reset_dut();
        drive(1);
        drive(1);
        #2 rst_n = 0; #2 rst_n = 1; // Async reset
        // After reset, state should be S0. din is still 1 from previous drive? 
        // No, we must re-apply din after reset to check.
        drive(1); // Should start from S0 -> S1
        drive(0);
        drive(1);

        // Test Case 5: Multiple 1s in S2
        reset_dut();
        drive(1);
        drive(1);
        drive(1); // S2 stays S2
        drive(0); // S2 -> S3
        drive(1); // S3 + din=1 -> detected=1

        // Test Case 6: Sequence 1, 1, 0, 0
        reset_dut();
        drive(1);
        drive(1);
        drive(0);
        drive(0); // S3 -> S0
        drive(1); // S0 -> S1

        #10;
        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```

Wait, the `model_detected` logic in my testbench is slightly flawed because it uses `model_state` which updates on the clock edge. In a Mealy machine, `detected` depends on the state *before* the transition and the input *during* the transition. 

Let's rewrite the design and testbench cleanly.

```verilog
module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    reg [1:0] state;
    localparam S0 = 2'b00;
    localparam S1 = 2'b01;
    localparam S2 = 2'b10;
    localparam S3 = 2'b11;

    assign detected = (state == S3 && din == 1'b1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S0;
        end else begin
            case (state)
                S0: state <= (din == 1'b1) ? S1 : S0;
                S1: state <= (din == 1'b1) ? S2 : S0;
                S2: state <= (din == 1'b0) ? S3 : S2;
                S3: state <= (din == 1'b1) ? S1 : S0;
                default: state <= S0;
            endcase
        end
    end

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

    integer passed, total;
    reg [1:0] model_state;
    reg model_detected;

    // Reference Model
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            model_state <= 2'b00;
        end else begin
            case (model_state)
                2'b00: model_state <= (din == 1'b1) ? 2'b01 : 2'b00;
                2'b01: model_state <= (din == 1'b1) ? 2'b10 : 2'b00;
                2'b10: model_state <= (din == 1'b0) ? 2'b11 : 2'b10;
                2'b11: model_state <= (din == 1'b1) ? 2'b01 : 2'b00;
                default: model_state <= 2'b00;
            endcase
        end
    end

    // Mealy output is combinational based on the state *before* the clock edge
    // and the current din. In our testbench, we need to track what the state was.
    reg [1:0] state_prev;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state_prev <= 2'b00;
        else        state_prev <= model_state; // This is actually the state at the start of the cycle
    end
    // Wait, that's confusing. Let's simplify.

    // Correct approach: The Mealy output depends on (state_at_start_of_cycle AND din).
    // In a clocked testbench, we change 'din' at negedge, then check 'detected' after posedge.
    // At the moment of checking (after posedge), 'detected' is based on the state 
    // that was just updated? No! Mealy output depends on the state *before* the transition.
    // Let's re-read: "detected is 1 exactly when the last three bits... were 1,1,0 and din is currently 1".
    // This means if we are in S3 (having seen 1,1,0) and din becomes 1, detected goes high.

    // Let's use a simpler reference model:
    reg [3:0] history;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) history <= 4'b0000;
        else        history <= {history[2:0], din};
    end

    // The Mealy output is actually easier to model by looking at the bits.
    // But we must be careful about timing.
    
    task check_val;
        begin
            total = total + 1;
            if (detected === model_detected) passed = passed + 1;
            else $display("FAIL: time=%