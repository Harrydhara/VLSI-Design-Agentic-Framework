module updown8(
    input        clk,
    input        rst_n,
    input        en,
    input        up,
    output [7:0] count
);

    reg [7:0] count_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_reg <= 8'h00;
        end else if (en) begin
            if (up) begin
                count_reg <= count_reg + 1'b1;
            end else begin
                count_reg <= count_reg - 1'b1;
            end
        end
    end

    assign count = count_reg;

endmodule
