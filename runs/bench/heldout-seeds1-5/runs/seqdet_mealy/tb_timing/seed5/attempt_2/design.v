module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    reg [1:0] state;
    parameter S0 = 2'b00; // Reset/Idle
    parameter S1 = 2'b01; // Saw 1
    parameter S2 = 2'b10; // Saw 1, 1
    parameter S3 = 2'b11; // Saw 1, 1, 0

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S0;
        end else begin
            case (state)
                S0: state <= din ? S1 : S0;
                S1: state <= din ? S2 : S0;
                S2: state <= din ? S2 : S3;
                S3: state <= din ? S1 : S0;
                default: state <= S0;
            endcase
        end
    end

    assign detected = (state == S3 && din == 1'b1);

endmodule
