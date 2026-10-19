```verilog
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
    reg [3:0] expected_y;
    integer i, j;
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

        // Test Case 1: Exhaustive testing of all combinations of sel and data patterns
        // To keep the testbench efficient but thorough, we iterate through all possible sel values
        // and specific interesting data patterns (all zeros, all ones, alternating, etc.)
        
        for (i = 0; i < 4; i = i + 1) begin // Iterate through all selection lines
            for (j = 0; j < 16; j = j + 1) begin // Iterate through a variety of data patterns for d0
                // We will use 'j' to set d0, and derive other inputs to ensure they are distinct
                d0 = j[3:0];
                d1 = j[3:0] ^ 4'hF; // Complement
                d2 = j[3:0] << 1 | j[3:0] >> 3; // Rotate
                d3 = j[3:0] + 4'h1; // Increment
                sel = i[1:0];

                // Calculate expected value using reference model
                expected_y = get_expected(d0, d1, d2, d3, sel);
                total = total + 1;

                #1; // Wait for combinational logic to settle

                if (y !== expected_y) begin
                    $display("FAIL: sel=%b, d0=%b, d1=%b, d2=%b, d3=%b | Expected y=%b, Actual y=%b", 
                             sel, d0, d1, d2, d3, expected_y, y);
                end else begin
                    passed = passed + 1;
                end
            end
        end

        // Test Case 2: Corner cases for data (all 0s and all Fs)
        d0 = 4'b0000; d1 = 4'b0000; d2 = 4'b0000; d3 = 4'b0000;
        for (i = 0; i < 4; i = i + 1) begin
            sel = i[1:0];
            expected_y = 4'b0000;
            total = total + 1;
            #1;
            if (y !== expected_y) begin
                $display("FAIL: sel=%b, d0=%b, d1=%b, d2=%b, d3=%b | Expected y=%b, Actual y=%b", 
                         sel, d0, d1, d2, d3, expected_y, y);
            end else begin
                passed = passed + 1;
            end
        end

        d0 = 4'b1111; d1 = 4'b1111; d2 = 4'b1111; d3 = 4'b1111;
        for (i = 0; i < 4; i = i + 1) begin
            sel = i[1:0];
            expected_y = 4'b1111;
            total = total + 1;
            #1;
            if (y !== expected_y) begin
                $display("FAIL: sel=%b, d0=%b, d1=%b, d2=%b, d3=%b | Expected y=%b, Actual y=%b", 
                         sel, d0, d1, d2, d3, expected_y, y);
            end else begin
                passed = passed + 1;
            end
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```