module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    // State encoding for a Mealy machine detecting 1101
    // S0: Idle / Reset state
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
                    next_state = S2; // Stay in S2 if we get '111', the last two are still '11'
            end
            S3: begin
                if (din == 1'b1)
                    next_state = S2; // Pattern 1101 completed. Next bit is 1, so we have '11'
                else
                    next_state = S0;
            end
            default: next_state = S0;
        endcase
    end

    // Mealy output logic (Combinational)
    // detected is 1 when in state S3 and din is 1.
    // State S3 means we have already seen '110'.
    assign detected = (state == S3 && din == 1'b1);

endmodule
