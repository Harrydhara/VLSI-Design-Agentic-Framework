module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    // State encoding for the sequence 1 -> 1 -> 0 (Mealy output on next 1)
    // S0: Idle / Reset
    // S1: Saw '1'
    // S2: Saw '1, 1'
    // S3: Saw '1, 1, 0'
    reg [1:0] state;

    localparam S0 = 2'b00;
    localparam S1 = 2'b01;
    localparam S2 = 2'b10;
    localparam S3 = 2'b11;

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
                    if (din) state <= S2; // Stay in S2 if we see 1,1,1... pattern
                    else     state <= S3;
                end
                S3: begin
                    if (din) state <= S1; // Pattern 1,1,0,1 completed. Next bit is '1' -> S1
                    else     state <= S0;
                end
                default: state <= S0;
            endcase
        end
    end

    // Mealy output: detected is high if we are in S3 and current din is 1
    assign detected = (state == S3 && din == 1'b1);

endmodule
