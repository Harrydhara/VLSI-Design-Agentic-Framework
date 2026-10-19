module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    // State encoding for the sequence detector (1 -> 1 -> 0)
    // S0: Reset / Initial state
    // S1: Saw '1'
    // S2: Saw '1, 1'
    // S3: Saw '1, 1, 0'
    reg [1:0] state;

    parameter S0 = 2'b00;
    parameter S1 = 2'b01;
    parameter S2 = 2'b10;
    parameter S3 = 2'b11;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S0;
        end else begin
            case (state)
                S0: begin
                    if (din) state <= S1;
                    else     state <= S0;
                end
                S1: begin
                    if (din) state <= S2;
                    else     state <= S0;
                end
                S2: begin
                    if (din) state <= S2; // Stay in S2 if we see another 1 (part of a potential new sequence)
                    else     state <= S3;
                end
                S3: begin
                    if (din) state <= S1; // Pattern found! Next bit is '1', so start from S1
                    else     state <= S0;
                end
                default: state <= S0;
            endcase
        end
    end

    // Mealy output: detected depends on current state and current input din.
    // Pattern 1, 1, 0 is completed when in state S3 AND din is 1.
    assign detected = (state == S3 && din == 1'b1);

endmodule
