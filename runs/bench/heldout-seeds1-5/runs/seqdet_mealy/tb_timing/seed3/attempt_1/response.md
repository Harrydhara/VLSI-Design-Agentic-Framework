```verilog
module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    // State encoding for the sequence 1 -> 1 -> 0 (Mealy output on next 1)
    // S0: Idle / Reset
    // S1: Found '1'
    // S2: Found '11'
    // S3: Found '110'
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
                    if (din == 1'b1) state <= S1;
                    else             state <= S0;
                end
                S1: begin
                    if (din == 1'b1) state <= S2;
                    else             state <= S0;
                end
                S2: begin
                    if (din == 1'b0) state <= S3;
                    else             state <= S2; // Stay in S2 if '111', still looking for '0'
                end
                S3: begin
                    if (din == 1'b1) state <= S1; // Pattern 1101 complete. Next bit could be start of new pattern.
                    else             state <= S0;
                end
                default: state <= S0;
            endcase
        end
    end

    // Mealy output: detected is high if we are in S3 and din is 1
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
    reg [1:0] model_state;

    // Reference Model logic
    // The model tracks the state transitions on posedge clk
    // and calculates Mealy output based on current state + din.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            model_state <= 2'b00;
        end else begin
            case (model_state)
                2'b00: if (din) model_state <= 2'b01; else model_state <= 2'b00;
                2'b01: if (din) model_state <= 2'b10; else model_state <= 2'b00;
                2'b10: if (!din) model_state <= 2'b11; else model_state <= 2'b10;
                2'b11: if (din) model_state <= 2'b01; else model_state <= 2'b00;
                default: model_state <= 2'b00;
            endcase
        end
    end

    // Mealy output depends on the state *before* the transition (the current state)
    // and the input din. Since we check #1 after posedge, 'model_detected' 
    // must represent what the output should be given the state reached by the clock edge.
    // Wait, in a Mealy machine, the output at time T depends on State(T-1) and Input(T).
    // Our testbench checks #1 after posedge clk. At that point, 'state' has updated to State(T).
    // However, the specification says: "detected is 1 exactly when the last three bits... were 1,1,0 and din is currently 1".
    // This means if we are in S3 (having seen 1,1,0) and din becomes 1, detected goes high immediately.

    task check;
        begin
            total = total + 1;
            if (detected === model_detected) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: time=%0d din=%b state_pre_edge=%b expected=%b actual=%b", 
                         $time, din, model_state, model_detected, detected);
            end
        end
    endtask

    // Because Mealy output is combinational, we must check it whenever din changes
    // OR when the state changes (which happens on posedge clk).
    // The simplest way to test a Mealy machine is: 
    // 1. Change din at negedge.
    // 2. Check detected immediately (it might change due to din).
    // 3. Wait for posedge.
    // 4. Check detected again (it might change due to state update).

    always @(negedge clk) begin
        if (rst_n) begin
            // We don't check here because we want to control the timing in tasks
        end
    end

    // Corrected approach: Use a task to drive inputs and check outputs.
    task drive_din(input b);
        begin
            @(negedge clk);
            din = b;
            #1; // Wait for combinational propagation
            // Check if din change triggered Mealy output
            // We need to know what the state is *right now* (before posedge)
            // To keep it simple, we'll use a manual model update in the task.
        end
    endtask

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // We will redefine the test logic to be more robust for Mealy
    // The state machine is: S0 --1--> S1 --1--> S2 --0--> S3 --1--> (detected=1, next=S1)
    
    initial begin
        // Initialize
        rst_n = 0;
        din = 0;
        #15 rst_n = 1;

        // Test Sequence: 1, 1, 0, 1 (Pattern 1)
        // Pattern 1: din=1(S1), din=1(S2), din=0(S3), din=1(Detected!)
        apply_bit(1); // S0 -> S1
        apply_bit(1); // S1 -> S2
        apply_bit(0); // S2 -> S3
        apply_bit(1); // S3 + din=1 -> Detected! (and moves to S1)

        // Test Overlap: 1, 1, 0, 1, 1, 0, 1
        // We already did 1,1,0,1. The last bit was 1, which moved us to S1.
        // Now we need 1, 0, 1 to complete the next pattern (since we are at S1).
        apply_bit(1); // S1 -> S2
        apply_bit(0); // S2 -> S3
        apply_bit(1); // S3 + din=1 -> Detected!

        // Test Reset mid-sequence
        apply_bit(1); // S1
        apply_bit(1); // S2
        #7 rst_n = 0;
        #5 rst_n = 1;
        // After reset, should be in S0. din is still 1 from before? No, let's set it.
        @(negedge clk); din = 1; #1;
        if (detected !== 0) $display("FAIL: Reset failed to clear output");
        else passed = passed + 1, total = total + 1;

        // Test no pattern
        apply_bit(0);
        apply_bit(0);
        apply_bit(1);
        apply_bit(0);
        apply_bit(0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

    // Task to apply a bit and check the Mealy output
    task apply_bit(input b);
        reg expected_det;
        begin
            @(negedge clk);
            din = b;
            #1; // Combinational delay for din change
            
            // Calculate what 'detected' should be based on current state and new din
            // We use the internal model logic here. 
            // Note: The uut state updates at posedge clk.
            // At this moment (after negedge + #1), the uut is still in the OLD state.
            expected_det = (model_state == 2'b11 && b == 1'b1);
            
            total = total + 1;
            if (detected !== expected_det) begin
                $display("FAIL: time=%0d din=%b model_state=%b expected=%b actual=%b", 
                         $time, b, model_state, expected_det, detected);
            end else begin
                passed = passed + 1;
            end

            // Now wait for the clock edge to update the state
            @(posedge clk);
            #1; // Wait for state transition
            
            // After posedge, 'detected' might change because the state changed.
            // We need to check if the Mealy output is correct for the NEW state and current din.
            expected_det = (model_state == 2'b11 && b == 1'b1);
            total = total + 1;
            if (detected !== expected_det) begin
                $display("FAIL: time=%0d din=%b model_state=%b expected=%b actual=%b", 
                         $time, b, model_state, expected_det, detected);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

endmodule
```