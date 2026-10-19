module seqdet_moore(
    input   clk,
    input   rst,
    input   din,
    output  detected
);

    // State encoding for Moore machine
    // S0: Idle/Reset
    // S1: Detected '1'
    // S2: Detected '10'
    // S3: Detected '101'
    // S4: Detected '1011' (Pattern complete)
    reg [2:0] state;

    localparam S0 = 3'd0;
    localparam S1 = 3'd1;
    localparam S2 = 3'd2;
    localparam S3 = 3'd3;
    localparam S4 = 3'd4;

    always @(posedge clk) begin
        if (rst) begin
            state <= S0;
        end else begin
            case (state)
                S0: begin
                    if (din == 1'b1) state <= S1;
                    else             state <= S0;
                end
                S1: begin
                    if (din == 1'b0) state <= S2;
                    else             state <= S1; // Stay in S1 if '11' seen, but pattern is 1011
                                                  // Actually, if we see 1, 1... the first 1 could be start.
                                                  // If din=1, state stays S1 (representing a single '1').
                end
                S2: begin
                    if (din == 1'b1) state <= S3;
                    else             state <= S0;
                end
                S3: begin
                    if (din == 1'b1) state <= S4;
                    else             state <= S0; // Pattern was 101, now 1010 -> reset to S0 or check if '0' starts something? No.
                end
                S4: begin
                    // Overlapping patterns: 1011...
                    // If next bit is 0: sequence becomes 10110. The last bits are ...10. So state -> S2.
                    // If next bit is 1: sequence becomes 10111. The last bits are ...11. So state -> S1.
                    if (din == 1'b0) state <= S2;
                    else             state <= S1;
                end
                default: state <= S0;
            endcase
        end
    end

    // Moore output depends only on current state
    assign detected = (state == S4);

endmodule
