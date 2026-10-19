```verilog
module tb;
    // Inputs to DUT
    reg [3:0] d0;
    reg [3:0] d1;
    reg [3:0] d2;
    reg [3:0] d3;
    reg [1:0] sel;

    // Outputs from DUT
    wire [3:0] y;

    // Internal variables for verification
    integer i;
    integer j;
    reg [3:0] expected_y;
    integer passed;
    integer total;

    // Instantiate the Design Under Test (DUT)
    mux4 dut (
        .d0(d0),
        .d1(d1),
        .d2(d2),
        .d3(d3),
        .sel(sel),
        .y(y)
    );

    // Reference Model Function
    function [3:0] get_expected(input [3:0] i0, input [3:0] i1, input [3:0] i2, input [3:0] i3, input [1:0] s);
        case (s)
            2'b00: get_expected = i0;
            2'b01: get_expected = i1;
            2'b10: get_expected = i2;
            2'b11: get_expected = i3;
            default: get_expected = 4'b0000;
        endcase
    endfunction

    initial begin
        passed = 0;
        total = 0;

        // Test Case 1: Exhaustive testing of all selection lines with varying data patterns
        // We iterate through every possible combination of inputs to ensure full coverage.
        // Since there are 4*4*4*4*4 = 4^5 = 1024 combinations, we can test them all.
        
        for (i = 0; i < 16; i = i + 1) begin // d0
            for (j = 0; j < 16; j = j + 1) begin // d1
                for (i = 0; i < 16; i = i + 1) begin // This is a nested loop structure, let's simplify logic for the testbench script
                end
            end
        end

        // Re-writing loop to be clean and correct
        // We will iterate through all possible values of d0, d1, d2, d3, and sel.
        // To keep simulation time reasonable but thorough, we'll use a nested approach.
        
        for (integer s_val = 0; s_val < 4; s_val = s_val + 1) begin
            for (integer v0 = 0; v0 < 16; v0 = v0 + 1) begin
                for (integer v1 = 0; v1 < 16; v1 = v1 + 1) begin
                    for (integer v2 = 0; v2 < 16; v2 = v2 + 1) begin
                        for (integer v3 = 0; v3 < 16; v3 = v3 + 1) begin
                            // Apply inputs
                            d0 = v0;
                            d1 = v1;
                            d2 = v2;
                            d3 = v3;
                            sel = s_val;

                            // Calculate expected value using reference model
                            expected_y = get_expected(v0, v1, v2, v3, s_val);
                            
                            // Increment total checks
                            total = total + 1;

                            // Wait for combinational logic to settle (non-zero delay)
                            #1;

                            // Compare actual vs expected
                            if (y !== expected_y) begin
                                $display("FAIL: d0=%d, d1=%d, d2=%d, d3=%d, sel=%d | Expected: %d, Actual: %d", 
                                         v0, v1, v2, v3, s_val, expected_y, y);
                            end else begin
                                passed = passed + 1;
                            end
                        end
                    end
                end
            end
        end

        // Corner Case: All zeros
        d0 = 4'b0000; d1 = 4'b0000; d2 = 4'b0000; d3 = 4'b0000; sel = 2'b00; #1;
        total = total + 1;
        if (y !== 4'b0000) begin
            $display("FAIL: All zeros | Expected: 0, Actual: %d", y);
        end else passed = passed + 1;

        // Corner Case: All ones
        d0 = 4'b1111; d1 = 4'b1111; d2 = 4'b1111; d3 = 4'b1111; sel = 2'b11; #1;
        total = total + 1;
        if (y !== 4'b1111) begin
            $display("FAIL: All ones | Expected: 15, Actual: %d", y);
        end else passed = passed + 1;

        // Corner Case: Alternating bits
        d0 = 4'b1010; d1 = 4'b0101; d2 = 4'b1100; d3 = 4'b0011; sel = 2'b01; #1;
        total = total + 1;
        if (y !== 4'b0101) begin
            $display("FAIL: Alternating | Expected: 5, Actual: %d", y);
        end else passed = passed + 1;

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```