module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    // State encoding for the pattern 1, 1, 0, 1
    // S0: Initial / Nothing found
    // S1: Found '1'
    // S2: Found '1, 1'
    // S3: Found '1, 1, 0'
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
                    if (din == 1'b1) state <= S1;
                    else             state <= S0;
                end
                S1: begin
                    if (din == 1'b1) state <= S2;
                    else             state <= S0;
                end
                S2: begin
                    if (din == 1'b0) state <= S3;
                    else             state <= S2;
                end
                S3: begin
                    if (din == 1'b1) state <= S1;
                    else             state <= S0;
                end
                default: state <= S0;
            endcase
        end
    end

    // Mealy output logic: detected is 1 if in S3 and din is 1.
    assign detected = (state == S3 && din == 1'b1);

endmodule
