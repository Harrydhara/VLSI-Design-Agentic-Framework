```verilog
module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    // State encoding for a Mealy machine detecting 1, 1, 0, 1
    // S0: Idle / Reset state (nothing matched)
    // S1: Detected '1'
    // S2: Detected '11'
    // S3: Detected '110'
    
    parameter S0 = 2'b00;
    parameter S1 = 2'b01;
    parameter S2 = 2'b10;
    parameter S3 = 2'b11;

    reg [1:0] state, next_state;
    reg       detected_comb;

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
        detected_comb = 1'b0;

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
                    // If we get '111', the suffix is still '11'
                    next_state = S2;
            end

            S3: begin
                if (din == 1'b1) begin
                    // Pattern 1, 1, 0 + current din=1 detected!
                    detected_comb = 1'b1;
                    // For overlapping patterns (1101 -> next could be 1101):
                    // After 1101, the suffix is '1'. So we go to S1.
                    next_state = S1;
                end else begin
                    // If we get '1100', reset to idle
                    next_state = S0;
                end
            end

            default: begin
                next_state = S0;
                detected_comb = 1'b0;
            end
        endcase
    end

    // Assign the combinational output (Mealy)
    assign detected = detected_comb;

endmodule
```