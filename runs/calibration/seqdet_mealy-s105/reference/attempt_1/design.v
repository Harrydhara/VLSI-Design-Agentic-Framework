module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    // State encoding for the sequence 1 -> 1 -> 0 (next bit 1 triggers output)
    // S0: Reset/Initial state
    // S1: Found '1'
    // S2: Found '11'
    // S3: Found '110'
    reg [1:0] state;

    localparam S0 = 2'd0;
    localparam S1 = 2'd1;
    localparam S2 = 2'd2;
    localparam S3 = 2'd3;

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
                    else             state <= S2; // Stay in S2 if '111' is seen
                end
                S3: begin
                    if (din == 1'b1) state <= S1; // Overlap: '1101' -> next bit could be part of '11...'
                    else             state <= S0;
                end
                default: state <= S0;
            endcase
        end
    end

    // Mealy output logic: depends on current state and current input din
    // Pattern is 1, 1, 0, 1. If we are in S3 (found 1, 1, 0), and din is 1, detected = 1.
    assign detected = (state == S3 && din == 1'b1) ? 1'b1 : 1'b0;

endmodule
