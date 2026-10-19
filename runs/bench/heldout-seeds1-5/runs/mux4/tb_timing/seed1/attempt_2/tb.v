module tb;
    reg [3:0] d0, d1, d2, d3;
    reg [1:0] sel;
    wire [3:0] y;

    integer passed = 0;
    integer total = 0;
    reg [3:0] expected_y;

    mux4 dut (
        .d0(d0),
        .d1(d1),
        .d2(d2),
        .d3(d3),
        .sel(sel),
        .y(y)
    );

    task check;
        begin
            total = total + 1;
            if (y === expected_y) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: time=%0d sel=%b d0=%h d1=%h d2=%h d3=%h expected=%h actual=%h", 
                         $time, sel, d0, d1, d2, d3, expected_y, y);
            end
        end
    endtask

    initial begin
        // Initialize inputs
        d0 = 4'h0; d1 = 4'h0; d2 = 4'h0; d3 = 4'h0; sel = 2'b00;
        #1;

        // Test Case 1: All distinct values, select d0
        d0 = 4'hA; d1 = 4'hB; d2 = 4'hC; d3 = 4'hD; sel = 2'b00;
        expected_y = 4'hA;
        #1; check;

        // Test Case 2: Select d1
        sel = 2'b01;
        expected_y = 4'hB;
        #1; check;

        // Test Case 3: Select d2
        sel = 2'b10;
        expected_y = 4'hC;
        #1; check;

        // Test Case 4: Select d3
        sel = 2'b11;
        expected_y = 4'hD;
        #1; check;

        // Test Case 5: Changing data values while sel is constant
        d0 = 4'h5;
        expected_y = 4'h5;
        #1; check;

        // Test Case 6: Corner case - all inputs same
        d0 = 4'hF; d1 = 4'hF; d2 = 4'hF; d3 = 4'hF;
        sel = 2'b01;
        expected_y = 4'hF;
        #1; check;

        // Test Case 7: Corner case - all inputs zero
        d0 = 4'h0; d1 = 4'h0; d2 = 4'h0; d3 = 4'h0;
        sel = 2'b10;
        expected_y = 4'h0;
        #1; check;

        // Test Case 8: Rapid sel change (combinational)
        d0 = 4'h1; d1 = 4'h2; d2 = 4'h3; d3 = 4'h4;
        sel = 2'b00; expected_y = 4'h1; #1; check;
        sel = 2'b11; expected_y = 4'h4; #1; check;
        sel = 2'b01; expected_y = 4'h2; #1; check;

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
