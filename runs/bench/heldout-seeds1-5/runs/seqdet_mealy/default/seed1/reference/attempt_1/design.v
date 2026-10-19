module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    // State encoding for the sequence detector (1 -> 1 -> 0)
    // S0: IDLE / Reset state
    // S1: Saw '1'
    // S2: Saw '11'
    // S3: Saw '110'
    parameter S0 = 2'b00;
    parameter S1 = 2'b01;
    parameter S2 = 2'b10;
    parameter S3 = 2'b11;

    reg [1:0] state;

    // State transition logic (Sequential)
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
                    if (din) state <= S2; // Stay in S2 if we see '111'
                    else     state <= S3;
                end
                S3: begin
                    if (din) state <= S1; // Pattern 1101 completed, next bit could be start of new pattern
                    else     state <= S0;
                end
                default: state <= S0;
            endcase
        end
    end

    // Mealy output logic (Combinational)
    // detected is 1 if we are in state S3 (saw 1, 1, 0) AND current din is 1.
    assign detected = (state == S3 && din == 1'b1);

endmodule
