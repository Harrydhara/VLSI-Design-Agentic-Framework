module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    // State encoding for pattern 1, 1, 0 (Mealy output depends on din)
    // S0: Initial / No bits matched
    // S1: "1" matched
    // S2: "1, 1" matched
    // S3: "1, 1, 0" matched
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
                    if (din == 1'b1) state <= S1;
                    else             state <= S0;
                end
                S1: begin
                    if (din == 1'b1) state <= S2;
                    else             state <= S0;
                end
                S2: begin
                    if (din == 1'b0) state <= S3;
                    else             state <= S2; // Stay in S2 if we get "1, 1, 1"
                end
                S3: begin
                    if (din == 1'b1) state <= S1; // Pattern was 1,1,0. Next bit is 1. New sequence starts with '1'.
                    else             state <= S0;
                end
                default: state <= S0;
            endcase
        end
    end

    // Mealy output logic (Combinational)
    // detected is 1 if we are in state "1, 1, 0" and din is 1.
    assign detected = (state == S3 && din == 1'b1);

endmodule
