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

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S0;
        end else begin
            state <= next_state;
        end
    end

    // Next state and Mealy output combinational logic
    always @(*) begin
        // Default values to prevent latches
        next_state = S0;
        detected = 1'b0;

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
                    next_state = S2; // Stay in S2 if we see '111', still have '11' suffix
            end

            S3: begin
                if (din == 1'b1) begin
                    // Pattern 110 + current 1 detected!
                    detected = 1'b1;
                    // For overlapping: after 1101, the last two bits are '01'. 
                    // However, looking at the sequence 1101101:
                    // After first 1101, we have seen '1'. The next bit is '1'.
                    // If current state was S3 (saw 110) and din=1, we transition to S1.
                    next_state = S1;
                end else begin
                    next_state = S0;
                end
            end

            default: begin
                next_state = S0;
                detected = 1'b0;
            end
        endcase
    end

endmodule
