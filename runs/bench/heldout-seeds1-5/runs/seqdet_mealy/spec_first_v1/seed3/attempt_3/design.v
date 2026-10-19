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
                    next_state = S1; // suffix is "1"
                else
                    next_state = S0;
            end
            default: next_state = S0;
        endcase
    end

    // Mealy output logic: detected is 1 when in state S3 and din is 1.
    assign detected = (state == S3 && din == 1'b1);

endmodule
