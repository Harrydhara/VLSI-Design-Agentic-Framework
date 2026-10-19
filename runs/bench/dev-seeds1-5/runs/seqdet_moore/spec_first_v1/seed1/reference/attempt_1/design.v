module seqdet_moore(
    input   clk,
    input   rst,
    input   din,
    output  detected
);

    // State encoding for Moore machine
    // S0: Initial / Reset state (nothing detected)
    // S1: Detected '1'
    // S2: Detected '10'
    // S3: Detected '101'
    // S4: Detected '1011' (Output = 1)
    
    reg [2:0] state;
    localparam S0 = 3'd0,
               S1 = 3'd1,
               S2 = 3'd2,
               S3 = 3'd3,
               S4 = 3'd4;

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
                    else             state <= S2; // Pattern '1010', last two bits are '10' -> S2
                end
                S4: begin
                    // Overlapping pattern check for 1,0,1,1...
                    // If next bit is 0: sequence becomes ...1,0 (ends in 10) -> S2
                    // If next bit is 1: sequence becomes ...1,1 (ends in 1) -> S1
                    if (din == 1'b0) state <= S2;
                    else             state <= S1;
                end
                default: state <= S0;
            endcase
        end
    end

    // Moore output depends only on the current state
    assign detected = (state == S4);

endmodule
