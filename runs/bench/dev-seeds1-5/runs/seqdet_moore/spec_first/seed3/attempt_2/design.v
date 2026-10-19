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
                    next_state = S1; // Stay in S1 if another '1' comes
            end
            S2: begin
                if (din == 1'b1)
                    next_state = S3;
                else
                    next_state = S0;
            end
            S3: begin
                if (din == 1'b1)
                    next_state = S4;
                else
                    next_state = S2; // '101' + '0' -> ends in '10', so go to S2
            end
            S4: begin
                // Overlapping patterns for 1,0,1,1
                // If next bit is 1: sequence was ...1,0,1,1,1. Last bits are '1', so S1.
                // If next bit is 0: sequence was ...1,0,1,1,0. Last bits are '1,0', so S2.
                if (din == 1'b1)
                    next_state = S1;
                else
                    next_state = S2;
            end
            default: begin
                next_state = S0;
            end
        endcase
    end

    // Moore output logic: depends only on the current state.
    // The pattern 1,0,1,1 is detected when we reach state S4.
    assign detected = (state == S4);

endmodule
