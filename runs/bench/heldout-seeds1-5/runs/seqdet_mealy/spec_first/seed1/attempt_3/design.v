module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    // State machine for detecting sequence 1, 1, 0, 1 (Mealy)
    // S0: Initial state / nothing matched
    // S1: Saw '1'
    // S2: Saw '11'
    // S3: Saw '110'

    parameter S0 = 2'b00;
    parameter S1 = 2'b01;
    parameter S2 = 2'b10;
    parameter S3 = 2'b11;

    reg [1:0] state, next_state;
    reg       detected_reg;

    // Sequential logic for state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S0;
        end else begin
            state <= next_state;
        end
    end

    // Combinational logic for next state and Mealy output
    always @(*) begin
        // Default assignments to prevent latches
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
                    // If we see '111', the last two bits are still '11'
                    next_state = S2;
            end

            S3: begin
                if (din == 1'b1) begin
                    // Pattern 1, 1, 0 followed by current din=1 is detected
                    detected_reg = 1'b1;
                    // After 1101, the suffix is '1'. Transition to S1.
                    next_state = S1;
                end else begin
                    // If we see '1100', the sequence is broken.
                    // However, if din=0, the last bit is '0', which doesn't help start a new 1101.
                    next_state = S0;
                end
            end

            default: begin
                next_state = S0;
                detected_reg = 1'b0;
            end
        endcase
    end

    // Mealy output is combinational and depends on current state AND din
    assign detected = detected_reg;

endmodule
