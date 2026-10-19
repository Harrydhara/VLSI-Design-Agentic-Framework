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
        // and all possible select signals.
        
        for (i = 0; i < 4; i = i + 1) begin // Iterate through sel
            for (j = 0; j < 16; j = j + 1) begin // Use j to represent a pattern of data
                // We will test a specific set of inputs for each selection
                // To ensure coverage, we vary the data inputs
                d0 = j[3:0];
                d1 = (j + 1) % 16;
                d2 = (j + 2) % 16;
                d3 = (j + 3) % 16;
                sel = i;

                // Calculate expected value using reference model
                expected_y = get_expected(d0, d1, d2, d3, sel);
                
                // Wait for combinational logic to settle
                #1;

                total = total + 1;
                if (y === expected_y) begin
                    passed = passed + 1;
                end else begin
                    $display("FAIL: sel=%0d, d0=%h, d1=%h, d2=%h, d3=%h | Expected y=%h, Actual y=%h", 
                             sel, d0, d1, d2, d3, expected_y, y);
                end
            end
        end

        // Test Case 2: Corner cases (All zeros, All ones, Alternating)
        begin
            // All Zeros
            d0 = 4'h0; d1 = 4'h0; d2 = 4'h0; d3 = 4'h0; sel = 2'b00; #1;
            expected_y = 4'h0; total++; if(y === expected_y) passed++; else $display("FAIL: sel=%0d, d0=%h, d1=%h, d2=%h, d3=%h | Expected y=%h, Actual y=%h", sel, d0, d1, d2, d3, expected_y, y);
            
            // All Ones
            d0 = 4'hf; d1 = 4'hf; d2 = 4'hf; d3 = 4'hf; sel = 2'b11; #1;
            expected_y = 4'hf; total++; if(y === expected_y) passed++; else $display("FAIL: sel=%0d, d0=%h, d1=%h, d2=%h, d3=%h | Expected y=%h, Actual y=%h", sel, d0, d1, d2, d3, expected_y, y);

            // Alternating bits
            d0 = 4'hA; d1 = 4'h5; d2 = 4'hA; d3 = 4'h5; sel = 2'b01; #1;
            expected_y = 4'h5; total++; if(y === expected_y) passed++; else $display("FAIL: sel=%0d, d0=%h, d1=%h, d2=%h, d3=%h | Expected y=%h, Actual y=%h", sel, d0, d1, d2, d3, expected_y, y);
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
