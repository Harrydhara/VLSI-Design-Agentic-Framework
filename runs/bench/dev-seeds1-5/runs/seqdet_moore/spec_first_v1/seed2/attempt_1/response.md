```verilog
module seqdet_moore(
    input   clk,
    input   rst,
    input   din,
    output  detected
);

    // State encoding for Moore machine
    // S0: Initial / Reset state (nothing detected)
    // S1: Detected '1'
    // S2: Detected '1, 0'
    // S3: Detected '1, 0, 1'
    // S4: Detected '1, 0, 1, 1' (Output = 1)
    
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
                    if (din == 1'b1)
                        state <= S1;
                    else
                        state <= S0;
                end
                S1: begin
                    if (din == 1'b0)
                        state <= S2;
                    else
                        state <= S1; // Stay in S1 if another '1' comes
                end
                S2: begin
                    if (din == 1'b1)
                        state <= S3;
                    else
                        state <= S0;
                end
                S3: begin
                    if (din == 1'b1)
                        state <= S4;
                    else
                        state <= S2; // Pattern '1,0,1,0' -> last two bits are '1,0', go to S2
                end
                S4: begin
                    // Overlapping pattern check for 1,0,1,1...
                    // If next bit is 1: sequence becomes ...1,0,1,1,1. Last four bits are not 1,0,1,1.
                    // However, we need to see if the suffix matches a prefix of 1,0,1,1.
                    // Suffixes of '1,0,1,1' + 'din':
                    // If din=1: '1,0,1,1,1'. Suffixes: '0,1,1,1', '1,1,1', '1,1', '1'. 
                    // Only '1' matches prefix of 1,0,1,1. So go to S1.
                    // If din=0: '1,0,1,1,0'. Suffixes: '0,1,1,0', '1,1,0', '1,0', '0'.
                    // '1,0' matches prefix of 1,0,1,1. So go to S2.
                    if (din == 1'b1)
                        state <= S1;
                    else
                        state <= S2;
                end
                default: state <= S0;
            endcase
        end
    end

    // Moore output depends only on current state
    assign detected = (state == S4);

endmodule
```