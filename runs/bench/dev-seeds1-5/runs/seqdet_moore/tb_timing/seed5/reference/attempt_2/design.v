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
                    else             state <= S1;
                end
                S2: begin
                    if (din == 1'b1) state <= S3;
                    else             state <= S0;
                end
                S3: begin
                    if (din == 1'b1) state <= S4;
                    else             state <= S0;
                end
                S4: begin
                    // Overlapping patterns logic:
                    // If next is 0, sequence ends in ...10. State -> S2.
                    // If next is 1, sequence ends in ...11. The last '1' could be start of new pattern? No, 1011 needs a 0.
                    // Actually, if we see 1011 and then another 1, the suffix is "1", so state -> S1.
                    if (din == 1'b0) state <= S2;
                    else             state <= S1;
                end
                default: state <= S0;
            endcase
        end
    end

    assign detected = (state == S4);

endmodule
