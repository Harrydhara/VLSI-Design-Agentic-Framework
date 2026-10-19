module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    parameter S0 = 2'b00; // ""
    parameter S1 = 2'b01; // "1"
    parameter S2 = 2'b10; // "11"
    parameter S3 = 2'b11; // "110"

    reg [1:0] state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= S0;
        else
            state <= next_state;
    end

    always @(*) begin
        case (state)
            S0: next_state = din ? S1 : S0;
            S1: next_state = din ? S2 : S0;
            S2: next_state = din ? S2 : S3;
            S3: next_state = din ? S1 : S0;
            default: next_state = S0;
        endcase
    end

    assign detected = (state == S3 && din == 1'b1);

endmodule
