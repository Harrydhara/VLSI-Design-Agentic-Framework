module tb;

    reg [3:0] d0, d1, d2, d3;
    reg [1:0] sel;
    wire [3:0] y;

    integer passed;
    integer total;

    mux4 uut (
        .d0(d0),
        .d1(d1),
        .d2(d2),
        .d3(d3),
        .sel(sel),
        .y(y)
    );

    task check_mux;
        input [3:0] exp_y;
        begin
            total = total + 1;
            if (y !== exp_y) begin
                $display("FAIL: sel=%b, d0=%b, d1=%b, d2=%b, d3=%b, expected=%b, actual=%b", 
                         sel, d0, d1, d2, d3, exp_y, y);
                passed = passed - 1;
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        // Initialize counters
        passed = 0;
        total = 0;

        // Test Case 1: sel=0
        d0 = 4'hA; d1 = 4'hB; d2 = 4'hC; d3 = 4'hD; sel = 2'b00;
        #1; check_mux(4'hA);

        // Test Case 2: sel=1
        sel = 2'b01;
        #1; check_mux(4'hB);

        // Test Case 3: sel=2
        sel = 2'b10;
        #1; check_mux(4'hC);

        // Test Case 4: sel=3
        sel = 2'b11;
        #1; check_mux(4'hD);

        // Test Case 5: All zeros
        d0 = 4'h0; d1 = 4'h0; d2 = 4'h0; d3 = 4'h0; sel = 2'b00;
        #1; check_mux(4'h0);

        // Test Case 6: All ones
        d0 = 4'hF; d1 = 4'hF; d2 = 4'hF; d3 = 4'hF; sel = 2'b11;
        #1; check_mux(4'hF);

        // Test Case 7: Alternating patterns
        d0 = 4'h5; d1 = 4'hA; d2 = 4'h5; d3 = 4'hA;
        sel = 2'b00; #1; check_mux(4'h5);
        sel = 2'b01; #1; check_mux(4'hA);
        sel = 2'b10; #1; check_mux(4'h5);
        sel = 2'b11; #1; check_mux(4'hA);

        // Test Case 8: Single bit toggling
        d0 = 4'b0001; d1 = 4'b0010; d2 = 4'b0100; d3 = 4'b1000;
        sel = 2'b00; #1; check_mux(4'b0001);
        sel = 2'b01; #1; check_mux(4'b0010);
        sel = 2'b10; #1; check_mux(4'b0100);
        sel = 2'b11; #1; check_mux(4'b1000);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
