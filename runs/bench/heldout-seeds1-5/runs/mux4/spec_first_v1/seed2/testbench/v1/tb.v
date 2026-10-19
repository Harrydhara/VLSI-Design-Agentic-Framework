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

        // Test Case 1: Exhaustive search of all input combinations for each selection
        // To keep the testbench efficient but thorough, we iterate through all possible data values
        // and all select signals. Since 4 inputs * 16 values * 4 selects is small (256), we can do it.
        
        for (i = 0; i < 4; i = i + 1) begin // Iterate through selection
            for (j = 0; j < 16; j = j + 1) begin // Iterate through a specific data pattern
                // We will use a pattern where each input has a unique value to ensure no crosstalk/confusion
                d0 = j[3:0];
                d1 = (j + 4) % 16;
                d2 = (j + 8) % 16;
                d3 = (j + 12) % 16;
                sel = i[1:0];

                // Calculate expected value using reference model
                expected_y = get_expected(d0, d1, d2, d3, sel);
                total = total + 1;

                #1; // Wait for combinational logic to settle

                if (y !== expected_y) begin
                    $display("FAIL: sel=%b, d0=%h, d1=%h, d2=%h, d3=%h | Expected y=%h, Actual y=%h", 
                             sel, d0, d1, d2, d3, expected_y, y);
                end else begin
                    passed = passed + 1;
                end
            end
        end

        // Test Case 2: Corner cases - All zeros and all ones
        // All Zeros
        d0 = 4'h0; d1 = 4'h0; d2 = 4'h0; d3 = 4'h0; sel = 2'b00;
        #1;
        expected_y = 4'h0;
        total = total + 1;
        if (y !== expected_y) begin
            $display("FAIL: Corner Case All Zeros | Expected y=%h, Actual y=%h", expected_y, y);
        end else begin
            passed = passed + 1;
        end

        // All Ones
        d0 = 4'hf; d1 = 4'hf; d2 = 4'hf; d3 = 4'hf; sel = 2'b11;
        #1;
        expected_y = 4'hf;
        total = total + 1;
        if (y !== expected_y) begin
            $display("FAIL: Corner Case All Ones | Expected y=%h, Actual y=%h", expected_y, y);
        end else begin
            passed = passed + 1;
        end

        // Alternating bits
        d0 = 4'b1010; d1 = 4'b0101; d2 = 4'b1100; d3 = 4'b0011; sel = 2'b01;
        #1;
        expected_y = 4'b0101;
        total = total + 1;
        if (y !== expected_y) begin
            $display("FAIL: Alternating bits | Expected y=%h, Actual y=%h", expected_y, y);
        end else begin
            passed = passed + 1;
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
