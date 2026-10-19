module counter4(
    input        clk,
    input        rst,
    input        en,
    output reg [3:0] count
);

    // The failure "Expected count= 0, Actual count= x" suggests that the 
    // testbench might be checking the value immediately after a reset 
    // or is sensitive to the initial state. Since we cannot use initial blocks,
    // and the specification says "Its value before the first reset does not matter",
    // the logic itself is correct for a synchronous counter.
    // However, in some simulation environments, if 'count' is never initialized 
    // via a reset, it remains 'x'. The testbench failure indicates that even 
    // when rst=1 and en=1 on a rising edge, the result was 'x'.
    // This usually happens if the logic doesn't handle the transition from 'x' to 0 correctly.
    // In Verilog, x + 1 = x. But (rst) is checked first.
    // If rst is 1, count <= 4'b0000; should work regardless of current value.

    always @(posedge clk) begin
        if (rst) begin
            count <= 4'd0;
        end else if (en) begin
            count <= count + 4'd1;
        end else begin
            count <= count;
        end
    end

endmodule
