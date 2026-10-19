module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    reg [1:0] state;
    localparam S0 = 2'b00;
    localparam S1 = 2'b01;
    localparam S2 = 2'b10;
    localparam S3 = 2'b11;

    assign detected = (state == S3 && din == 1'b1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S0;
        end else begin
            case (state)
                S0: state <= (din == 1'b1) ? S1 : S0;
                S1: state <= (din == 1'b1) ? S2 : S0;
                S2: state <= (din == 1'b0) ? S3 : S2;
                S3: state <= (din == 1'b1) ? S1 : S0;
                default: state <= S0;
            endcase
        end
    end

endmodule
