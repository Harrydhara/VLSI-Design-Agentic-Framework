module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    // State encoding for a Mealy machine detecting 1101
    // S0: IDLE / Reset state
    // S1: Detected '1'
    // S2: Detected '11'
    // S3: Detected '110'
    
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

    // Next state and Mealy output logic (Combinational)
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
                    next_state = S2; // Stay in S2 if we get '111', the last two are still '11'
            end

            S3: begin
                if (din == 1'b1) begin
                    detected = 1'b1;
                    next_state = S2; // Overlap: '1101' -> next state is '11' because last two bits are '11'
                                     // Wait, let's re-evaluate overlap for 1101.
                                     // Pattern: 1, 1, 0, 1. 
                                     // If we get 1, 1, 0, 1, the next bit could be '1' to start a new sequence?
                                     // No, if input is 1, 1, 0, 1, 1, 0, 1:
                                     // Bits: 1(S1) 1(S2) 0(S3) 1(detected=1, next state?)
                                     // After 1101, the suffix is '1'. To overlap with 1101, we need to see if 
                                     // the end of one pattern can be the start of another.
                                     // Pattern: 1 1 0 1. Suffixes: 1, 11, 110.
                                     // If current is 1 and state is S3 (110), we complete 1101.
                                     // The new suffix is '1'. So next state should be S1.
                                     // Let's re-check the requirement: "1 1 0 1 1 0 1" -> detected at 4th and 7th bit.
                                     // Bit 4 (din=1): pattern 1,1,0,1 completed. Suffix is '1'.
                                     // Bit 5 (din=1): suffix becomes '11'.
                                     // Bit 6 (din=0): suffix becomes '110'.
                                     // Bit 7 (din=1): pattern 1,1,0,1 completed.
                                     // So if state is S3 and din is 1, next_state = S1.
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

    // Correction on S2 logic for overlapping '111':
    // If state is S2 (we have '11') and din is 1, we have '111'.
    // The longest suffix matching a prefix of '1101' is '11'. So next_state = S2. Correct.

endmodule
