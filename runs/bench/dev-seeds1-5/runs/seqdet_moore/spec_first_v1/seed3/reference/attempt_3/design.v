module seqdet_moore(
    input   clk,
    input   rst,
    input   din,
    output  detected
);

    // State encoding for Moore machine
    // S0: Initial / Reset state (nothing detected)
    // S1: Detected '1'
    // S2: Detected '10'
    // S3: Detected '101'
    // S4: Detected '1011' (Pattern complete)

    parameter S0 = 3'd0;
    parameter S1 = 3'd1;
    parameter S2 = 3'd2;
    parameter S3 = 3'd3;
    parameter S4 = 3'd4;

    reg [2:0] state, next_state;

    // State transition logic (Sequential)
    always @(posedge clk) begin
        if (rst) begin
            state <= S0;
        end else begin
            state <= next_state;
        end
    end

    // Next state combinational logic
    // The pattern is 1, 0, 1, 1.
    always @(*) begin
        next_state = S0; // Default case
        case (state)
            S0: begin
                if (din == 1'b1)
                    next_state = S1;
                else
                    next_state = S0;
            end
            S1: begin
                if (din == 1'b0)
                    next_state = S2;
                else
                    next_state = S1; // Sequence '11', last bit is '1'
            end
            S2: begin
                if (din == 1'b1)
                    next_state = S3;
                else
                    next_state = S0; // Sequence '100', no progress
            end
            S3: begin
                if (din == 1'b1)
                    next_state = S4;
                else
                    next_state = S2; // Sequence '1010', last bits are '10'
            end
            S4: begin
                // Overlapping patterns for 1,0,1,1.
                // If next bit is 1: sequence was ...1,0,1,1,1. Last bit is '1'.
                // However, we must check if the suffix matches a prefix of 1011.
                // Suffixes of 1011 + 1 are: 1, 11, 011, 1011 (not possible), etc.
                // The longest prefix of 1011 that is a suffix of 10111 is '1'.
                if (din == 1'b1)
                    next_state = S1;
                else begin
                    // Sequence was ...1,0,1,1,0. Last bits are '1,0'.
                    // This matches the prefix of length 2: '10'.
                    next_state = S2;
                end
            end
            default: begin
                next_state = S0;
            end
        endcase
    end

    // Moore output logic: depends only on the current state.
    assign detected = (state == S4);

endmodule
