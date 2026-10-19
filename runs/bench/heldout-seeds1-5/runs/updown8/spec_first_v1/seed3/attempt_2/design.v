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
                    count <= count + 8'd1;
                end else begin
                    count <= count - 8'd1;
                end
            end
            // If en is 0, count retains its value implicitly by not being assigned.
        end
    end

endmodule
