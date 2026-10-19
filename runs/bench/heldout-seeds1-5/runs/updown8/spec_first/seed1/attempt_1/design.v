module updown8(
    input        clk,
    input        rst_n,
    input        en,
    input        up,
    output reg [7:0] count
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 8'h00;
        end else begin
            if (en) begin
                if (up) begin
                    count <= count + 1'b1;
                end else begin
                    count <= count - 1'b1;
                end
            end
        end
    end

endmodule
