module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    // State encoding for a Mealy machine detecting 1101
    // S0: Idle / Reset state (nothing matched)
    // S1: Detected '1'
    // S2: Detected '11'
    // S3: Detected '110'
    
    parameter S0 = 2'b00;
    parameter S1 = 2'b01;
    parameter S2 = 2'b10;
    parameter S3 = 2'b11;

    reg [1:0] state, next_state;
    reg       detected_reg;

    // State transition logic (Sequential)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S0;
        end else begin
            state <= next_state;
        end
    end

    // Next state and Mealy output logic (Combinational)
    always @(*) begin
        // Default values to prevent latches
        next_state = S0;
        detected_reg = 1'b0;

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
                    next_state = S2; // Stay in S2 if we get another '1' (pattern is 1,1,...)
            end

            S3: begin
                // Mealy output logic: If in S3 and din is 1, pattern 1101 is complete.
                if (din == 1'b1) begin
                    detected_reg = 1'b1;
                    next_state = S2; // Overlap: the current '1' could be the start of a new '11...'
                end else begin
                    detected_reg = 1'b0;
                    next_state = S0;
                end
            end

            default: begin
                next_state = S0;
                detected_reg = 1'b0;
            end
        endcase
    end

    // The Mealy output must be combinational and depend on both state AND din.
    // In the previous attempt, detected_reg was only set to 1 in S3 when din=1.
    // However, if we are in a state that *could* lead to detection but isn't S3 yet, 
    // it shouldn't trigger. The logic above is correct for Mealy, but let's ensure 
    // the output assignment covers all possible transitions correctly.
    
    assign detected = detected_reg;

endmodule
