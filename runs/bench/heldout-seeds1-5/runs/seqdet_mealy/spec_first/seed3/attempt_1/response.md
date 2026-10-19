```verilog
module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    // State encoding for a Mealy machine detecting 1101
    // S0: IDLE / Reset state
    // S1: Saw '1'
    // S2: Saw '11'
    // S3: Saw '110'
    parameter S0 = 2'b00;
    parameter S1 = 2'b01;
    parameter S2 = 2'b10;
    parameter S3 = 2'b11;

    reg [1:0] state, next_state;

    // State transition logic (Sequential)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic (Combinational)
    always @(*) begin
        case (state)
            S0: begin
                if (din == 1'b1)
                    next_state = S1;
                else
                    next_state = S0;
            end
            S1: begin
                if (din == 1'b1)
                    next_state = S2;
                else
                    next_state = S0;
            end
            S2: begin
                if (din == 1'b0)
                    next_state = S3;
                else
                    next_state = S2; // Stay in S2 if we see '111', the last two are still '11'
            end
            S3: begin
                if (din == 1'b1)
                    next_state = S2; // Pattern 1101 completed. Next bit could be part of 11...
                                     // If din is 1, we have '1101'. The last two bits are '01'.
                                     // Wait, let's re-evaluate the overlap for 1101.
                                     // Sequence: 1 -> 1 -> 0 -> 1 (Detected)
                                     // If next bit is 1: sequence becomes ...1011. The last two bits are '11'.
                                     // So from S3, if din=1, we go to S2 because the suffix is '11'.
                                     // Actually, let's trace carefully:
                                     // S3 means we just saw '110'. 
                                     // If din=1, sequence ends in '1101'. Output = 1.
                                     // The new suffix is '1', which is state S1? No, the overlap rule says:
                                     // "1 1 0 1 1 0 1" -> detected at 4th and 7th bit.
                                     // At 4th bit (din=1), we go from S3 to a state representing suffix '1'.
                                     // But if the next bits are '1, 0, 1', we need to be in S1 or S2?
                                     // Let's re-trace:
                                     // Input: 1 (S1) -> 1 (S2) -> 0 (S3) -> 1 (Detected, next state?)
                                     // If next bit is 1: 11011. Suffixes are '1', '11'. So we should be in S2.
                                     // If next bit is 0: 11010. Suffixes are '1', '10' (not a state). We go to S0.
                                     next_state = S1; // Wait, if din=1, suffix is '1'. But we need to check overlap.
                                     // Let's use the standard FSM approach for 1101:
                                     // S0 --1--> S1 --1--> S2 --0--> S3 --1--> (Detected) -> Next state?
                                     // If din=1 at S3, sequence is ...1101. The suffix is '1'. 
                                     // However, the next bit could be '1' to make it '11', which is S2.
                                     // Let's check: if we are in S3 and din=1, we have seen '1101'.
                                     // The suffix of '1101' that can start a new '1101' is '1'. 
                                     // So next state should be S1.
                                     // Let's re-verify overlap: 1 1 0 1 1 0 1
                                     // Bits: 1(S1), 1(S2), 0(S3), 1(Det, S1), 1(S2), 0(S3), 1(Det, S1).
                                     // This works!
                end else begin
                    next_state = S0;
                end
            end
            default: next_state = S0;
        endcase
    end

    // Correcting the logic for S2 and S3 to ensure overlap works as requested.
    // Let's refine the state machine transitions manually.
    // State 0: ""
    // State 1: "1"
    // State 2: "11"
    // State 3: "110"
    
    always @(*) begin
        case (state)
            S0: next_state = (din == 1'b1) ? S1 : S0;
            S1: next_state = (din == 1'b1) ? S2 : S0;
            S2: next_state = (din == 1'b0) ? S3 : S2; // if din=1, suffix is '11', stay in S2
            S3: next_state = (din == 1'b1) ? S1 : S0; // if din=1, suffix is '1'. If din=0, suffix is '0'.
            default: next_state = S0;
        endcase
    end

    // Mealy Output Logic
    // detected is 1 when in state S3 and din is 1.
    assign detected = (state == S3 && din == 1'b1);

endmodule
```

Wait, I need to re-check the overlap logic for `1101` with `S3 -> S1`.
If input is `1 1 0 1 1 0 1`:
1. `din=1`, state `S0->S1`
2. `din=1`, state `S1->S2`
3. `din=0`, state `S2->S3`
4. `din=1`, `detected=1`, state `S3->S1` (Suffix is '1')
5. `din=1`, state `S1->S2`
6. `din=0`, state `S2->S3`
7. `din=1`, `detected=1`, state `S3->S1`

This matches the requirement "detected is 1 while the 4th bit is on din and again while the 7th bit is on din".

One detail: in S2, if `din=1`, the suffix is `11`. So `next_state = S2` is correct.
In S3, if `din=1`, the sequence ends in `...1101`. The longest prefix of `1101` that is a suffix of `1101` is `1`. Thus `next_state = S1`.

Final check on S2: If state is S2 (saw 11) and din is 1, we have seen 111. The longest prefix of 1101 that is a suffix of 111 is 11. So staying in S2 is correct.

```verilog
module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    parameter S0 = 2'b00; // ""
    parameter S1 = 2'b01; // "1"
    parameter S2 = 2'b10; // "11"
    parameter S3 = 2'b11; // "110"

    reg [1:0] state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= S0;
        else
            state <= next_state;
    end

    always @(*) begin
        case (state)
            S0: next_state = din ? S1 : S0;
            S1: next_state = din ? S2 : S0;
            S2: next_state = din ? S2 : S3;
            S3: next_state = din ? S1 : S0;
            default: next_state = S0;
        endcase
    end

    assign detected = (state == S3 && din == 1'b1);

endmodule
```