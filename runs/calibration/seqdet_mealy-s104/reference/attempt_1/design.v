module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    // State encoding for the sequence 1, 1, 0, 1
    // S0: Idle / Reset
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
                    if (din == 1'b1)
                        state <= S1;
                    else
                        state <= S0;
                end
                S1: begin
                    if (din == 1'b1)
                        state <= S2;
                    else
                        state <= S0;
                end
                S2: begin
                    if (din == 1'b0)
                        state <= S3;
                    else
                        state <= S2; // Stay in S2 if we get another '1' (pattern is 1,1,...)
                end
                S3: begin
                    if (din == 1'b1)
                        state <= S2; // Overlap: the current '1' could be the start of a new pattern or part of 1,1...
                                     // Actually, if we are in S3 and get a 1, the sequence was 1,1,0,1.
                                     // The last bit (1) is the first bit of a potential next sequence.
                                     // Let's re-evaluate: 1,1,0,1 -> state transitions to S1? No.
                                     // If pattern is 1,1,0,1 and we get another 1, the bits are ...1,1,0,1,1...
                                     // The last '1' is the first bit of a new potential sequence.
                                     // However, if we just saw 1,1,0,1, the state should transition to S1 (found '1').
                                     // Wait, let's look at overlap: 1,1,0,1,1,0,1.
                                     // Bits: 1(S1) 1(S2) 0(S3) 1(detected=1, next state S1) 1(S2) 0(S3) 1(detected=1).
                                     // So if in S3 and din=1, we go to S1.
                        state <= S1;
                    else
                        state <= S0;
                end
                default: state <= S0;
            endcase
        end
    end

    // Mealy output logic
    // detected is 1 if in state S3 and din is 1.
    assign detected = (state == S3 && din == 1'b1);

endmodule
