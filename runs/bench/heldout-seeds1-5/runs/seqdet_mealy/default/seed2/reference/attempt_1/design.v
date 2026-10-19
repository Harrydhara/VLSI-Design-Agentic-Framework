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
                    else             state <= S2; // Stay in S2 if another '1' comes? No, pattern is 1,1. If we get 1,1,1, the last two are still 1,1.
                                                  // Actually, if input is 1,1,1:
                                                  // S0 -> (1) -> S1 -> (1) -> S2 -> (1) -> S2. Correct.
                end
                S3: begin
                    if (din == 1'b1) state <= S1; // Pattern 1,1,0,1 completed. Next bit could be start of new pattern.
                                                  // If din is 1, we have seen ...1,1,0,1. The last '1' can be the first '1' of next pattern.
                                                  // Wait, if input is 1,1,0,1,1,0,1:
                                                  // S3 + din=1 -> state becomes S1 (the new '1').
                                                  // Let's re-verify overlapping logic.
                                                  // Pattern: 1, 1, 0, 1.
                                                  // Input:   1  1  0  1  1  0  1
                                                  // State: S0 S1 S2 S3 S1 S2 S3 (Wait, if din=1 at S3, we go to S1)
                                                  // Let's trace carefully.
                    else             state <= S0;
                end
                default: state <= S0;
            endcase
        end
    end

    // Mealy output logic: detected is 1 if in S3 and din is 1.
    assign detected = (state == S3 && din == 1'b1);

endmodule
