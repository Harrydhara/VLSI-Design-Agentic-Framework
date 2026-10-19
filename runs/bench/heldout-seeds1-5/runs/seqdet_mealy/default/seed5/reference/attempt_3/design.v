module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    // State encoding for the sequence 1 -> 1 -> 0 (Mealy output on next 1)
    // S0: ""
    // S1: "1"
    // S2: "1, 1"
    // S3: "1, 1, 0"
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
                    if (din) state <= S1;
                    else     state <= S0;
                end
                S1: begin
                    if (din) state <= S2;
                    else     state <= S0;
                end
                S2: begin
                    if (din) state <= S2; 
                    else     state <= S3;
                end
                S3: begin
                    if (din) state <= S1; 
                    else     state <= S0;
                end
                default: state <= S0;
            endcase
        end
    end

    // Mealy output: depends on current state and the input din immediately.
    assign detected = (state == S3 && din == 1'b1);

endmodule
