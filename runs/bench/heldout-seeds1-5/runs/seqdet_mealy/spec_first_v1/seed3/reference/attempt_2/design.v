module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    // State encoding for a Mealy machine detecting 1101
    // S0: "" (Reset or no progress)
    // S1: "1"
    // S2: "11"
    // S3: "110"
    parameter S0 = 2'b00;
    parameter S1 = 2'b01;
    parameter S2 = 2'b10;
    parameter S3 = 2'b11;

    reg [1:0] state, next_state;

    // Sequential logic for state transitions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S0;
        end else begin
            state <= next_state;
        end
    end

    // Combinational logic for next state
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
                if (din == 1'b1)
                    next_state = S2; // suffix is "11"
                else
                    next_state = S3; // suffix is "110"
            end
            S3: begin
                if (din == 1'b1)
                    next_state = S1; // suffix is "1", but we just completed pattern. Next state should be S1?
                                     // Wait, if din=1 and state=S3, the sequence ends in ...1101.
                                     // The longest prefix of 1101 that is a suffix of 1101 is "1".
                                     // However, let's look at the overlap requirement: 1101101.
                                     // After the first '1' (the 4th bit), we have seen '...1'.
                                     // The next bit is '1', making it '...11'. This should be state S2.
                                     // If we go to S1, then the next '1' makes it S2. That works too.
                                     // Let's re-check: 1(S1) 1(S2) 0(S3) 1(Det, S1) 1(S2) 0(S3) 1(Det).
                                     // This matches the requirement.
                    next_state = S1; 
                else
                    next_state = S0;
            end
            default: next_state = S0;
        endcase
    end

    // Mealy output logic: detected is 1 when in state S3 and din is 1.
    // This must be combinational to react immediately to din changes.
    assign detected = (state == S3 && din == 1'b1);

endmodule
