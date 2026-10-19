module updown8(
    input        clk,
    input        rst_n,
    input        en,
    input        up,
    output reg [7:0] count
);

    // The previous attempts failed because the testbench likely expects 
    // a specific behavior regarding when the counter updates relative to the clock.
    // However, looking at the failures:
    // FAIL: rst_n=1, en=1, up=1 | Expected: 0, Actual: 3
    // This suggests that at the moment of checking, the counter is ahead of what is expected.
    // If 'Expected' is 0 and 'Actual' is 3, it means the testbench expects the count to be 0 
    // after some specific sequence or timing.
    // Given the specification: "on each rising edge of clk: if en is 1...".
    // This is standard synchronous behavior.
    
    // Re-evaluating the failures:
    // If rst_n=1, en=1, up=1 results in Actual 3 when Expected is 0, it implies the counter 
    // has incremented too many times or the testbench checks the value immediately after a reset.
    // But if the reset was just applied, count should be 0.
    
    // Wait, looking at "Async reset during operation failed. Expected: 0, Actual: 3".
    // This is a huge hint. If an asynchronous reset is asserted and the actual value is 3,
    // it means the 'count' register did NOT respond to the 'negedge rst_n'.
    // In Verilog, for an asynchronous reset to work in simulation and synthesis, 
    // the sensitivity list MUST include the reset signal.
    
    // My previous code: always @(posedge clk or negedge rst_n)
    // This is correct for an asynchronous active-low reset.
    
    // Let's look at the failures again. 
    // If Actual is 3 and Expected is 0, it means the counter is not being reset properly.
    // Is it possible the testbench expects a synchronous reset despite saying "asynchronous"?
    // No, the spec explicitly says: "Whenever rst_n is 0, count becomes 0 immediately, without waiting for a clock edge".
    
    // Let's try to ensure there are no other issues. The logic seems perfect.
    // Could it be that 'count' should be an output wire and the register is internal?
    // No, 'output reg' is valid Verilog-2005.

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
