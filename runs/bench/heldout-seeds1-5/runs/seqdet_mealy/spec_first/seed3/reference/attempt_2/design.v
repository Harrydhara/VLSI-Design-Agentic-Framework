module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    // State encoding for a Mealy machine detecting 1101
    // S0: IDLE / Reset state (no relevant bits seen)
    // S1: Saw '1'
    // S2: Saw '11'
    // S3: Saw '110'
    parameter S0 = 2'b00;
    parameter S1 = 2'b01;
    parameter S2 = 2'b10;
    parameter S3 = 2'b11;

    reg [1:0] state, next_state;

    // Sequential logic for state transition
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
                if (din == 1'b0)
                    next_state = S3;
                else
                    next_state = S2; // suffix is '11', stay in S2
            end
            S3: begin
                if (din == 1'b1)
                    next_state = S1; // pattern completed, suffix is '1'
                else
                    next_state = S0; // suffix is '0', reset to S0
            end
            default: next_state = S0;
        endcase
    end

    // Mealy output logic: 
    // detected is 1 exactly when the last three bits were 1, 1, 0 and din is currently 1.
    // This corresponds to being in state S3 (which represents having seen '110') 
    // and receiving a '1' on the current clock cycle.
    assign detected = (state == S3 && din == 1'b1);

endmodule
