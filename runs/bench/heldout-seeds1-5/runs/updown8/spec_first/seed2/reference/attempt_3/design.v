module updown8(
    input        clk,
    input        rst_n,
    input        en,
    input        up,
    output reg [7:0] count
);

    always @(posedge clk or negedge rst_n) begin
        if (rst_n == 1'b0) begin
            count <= 8'h00;
        end else if (en == 1'b1) begin
            if (up == 1'b1) begin
                count <= count + 8'h01;
            end else begin
                count <= count - 8'h01;
            end
        end
    end

endmodule
