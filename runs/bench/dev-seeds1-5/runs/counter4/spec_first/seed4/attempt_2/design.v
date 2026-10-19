module counter4(
    input        clk,
    input        rst,
    input        en,
    output reg [3:0] count
);

    always @(posedge clk) begin
        if (rst) begin
            count <= 4'b0000;
        end else if (en) begin
            count <= count + 4'd1;
        end
        // Implicitly: else count <= count;
    end

endmodule
