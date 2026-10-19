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

    // State transition logic
    always @(posedge clk) begin
        if (rst) begin
            state <= S0;
        end else begin
            state <= next_state;
        end
    end

    // Next state combinational logic
    always @(*) begin
        next_state = S0; // Default
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
                    next_state = S2; // Pattern '1010', last two bits are '10'
            end
            S4: begin
                // Overlapping patterns: pattern is 1,0,1,1. 
                // If next bit is 0, we have ...1,0 (matches S2)
                // If next bit is 1, we have ...1,1 (matches S1)
                if (din == 1'b0)
                    next_state = S2;
                else
                    next_state = S1;
            end
            default: begin
                next_state = S0;
            end
        endcase
    end

    // Moore output logic
    assign detected = (state == S4);

endmodule
