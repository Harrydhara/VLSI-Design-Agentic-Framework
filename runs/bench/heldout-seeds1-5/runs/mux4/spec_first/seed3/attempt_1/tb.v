module tb;
    // Inputs to DUT
    reg [3:0] d0;
    reg [3:0] d1;
    reg [3:0] d2;
    reg [3:0] d3;
    reg [1:0] sel;

    // Output from DUT
    wire [3:0] y;

    // Internal variables for verification
    integer i, j;
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

        // Test Case 1: Exhaustive testing of all combinations of inputs and selection
        // Since there are 4 inputs * 16 values each + 4 sel states, we can iterate through a subset or full range.
        // To be thorough but efficient, we will test every possible 'sel' value for various data patterns.

        for (i = 0; i < 4; i = i + 1) begin // Iterate through all selection values
            for (j = 0; j < 16; j = j + 1) begin // Test with different data combinations
                // We use 'j' to create a pattern of inputs. 
                // To ensure we cover corner cases, we vary d0-d3 based on j and i.
                d0 = j[3:0];
                d1 = (j + 1) % 16;
                d2 = (j + 2) % 16;
                d3 = (j + 3) % 16;
                sel = i[1:0];

                // Wait for combinational logic to settle
                #1;

                expected_y = get_expected(d0, d1, d2, d3, sel);
                total = total + 1;

                if (y !== expected_y) begin
                    $display("FAIL: d0=%h, d1=%h, d2=%h, d3=%h, sel=%b | Expected y=%h, Actual y=%h", 
                             d0, d1, d2, d3, sel, expected_y, y);
                end else begin
                    passed = passed + 1;
                end
            end
        end

        // Test Case 2: Specific Corner Cases (All zeros, All ones, Alternating)
        begin
            // All Zeros
            d0 = 4'h0; d1 = 4'h0; d2 = 4'h0; d3 = 4'h0; sel = 2'b00; #1;
            expected_y = 4'h0; total++;
            if (y !== expected_y) begin
                $display("FAIL: All Zeros | Expected y=%h, Actual y=%h", expected_y, y);
            end else passed++;

            // All Ones
            d0 = 4'hf; d1 = 4'hf; d2 = 4'hf; d3 = 4'hf; sel = 2'b11; #1;
            expected_y = 4'hf; total++;
            if (y !== expected_y) begin
                $display("FAIL: All Ones | Expected y=%h, Actual y=%h", expected_y, y);
            end else passed++;

            // Alternating bits
            d0 = 4'b1010; d1 = 4'b0101; d2 = 4'b1100; d3 = 4'b0011; sel = 2'b01; #1;
            expected_y = 4'b0101; total++;
            if (y !== expected_y) begin
                $display("FAIL: Alternating | Expected y=%h, Actual y=%h", expected_y, y);
            end else passed++;
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
