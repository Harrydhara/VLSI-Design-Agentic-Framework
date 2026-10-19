module tb;
    reg [3:0] d0, d1, d2, d3;
    reg [1:0] sel;
    wire [3:0] y;

    integer passed = 0;
    integer total = 0;

    mux4 uut (
        .d0(d0),
        .d1(d1),
        .d2(d2),
        .d3(d3),
        .sel(sel),
        .y(y)
    );

    task check;
        input [3:0] expected;
        begin
            total = total + 1;
            if (y === expected) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: time=%0d sel=%b d0=%h d1=%h d2=%h d3=%h expected=%h actual=%h", 
                         $time, sel, d0, d1, d2, d3, expected, y);
            end
        end
    endtask

    initial begin
        // Initialize inputs
        d0 = 4'h0; d1 = 4'h0; d2 = 4'h0; d3 = 4'h0; sel = 2'b00;
        #1;

        // Test Case 1: Select d0
        d0 = 4'hA; d1 = 4'hB; d2 = 4'hC; d3 = 4'hD; sel = 2'b00;
        #1; check(4'hA);

        // Test Case 2: Select d1
        sel = 2'b01;
        #1; check(4'hB);

        // Test Case 3: Select d2
        sel = 2'b10;
        #1; check(4'hC);

        // Test Case 4: Select d3
        sel = 2'b11;
        #1; check(4'hD);

        // Test Case 5: All zeros
        d0 = 4'h0; d1 = 4'h0; d2 = 4'h0; d3 = 4'h0; sel = 2'b01;
        #1; check(4'h0);

        // Test Case 6: All Fs
        d0 = 4'hF; d1 = 4'hF; d2 = 4'hF; d3 = 4'hF; sel = 2'b10;
        #1; check(4'hF);

        // Test Case 7: Changing inputs while selected
        d0 = 4'h5; d1 = 4'h6; d2 = 4'h7; d3 = 4'h8; sel = 2'b00;
        #1; check(4'h5);
        d0 = 4'h1; // Change the selected input
        #1; check(4'h1);

        // Test Case 8: Changing inputs while NOT selected
        d0 = 4'h1; d1 = 4'h2; d2 = 4'h3; d3 = 4'h4; sel = 2'b11;
        #1; check(4'h4);
        d3 = 4'hE; // Change the selected input
        #1; check(4'hE);
        d0 = 4'hF; // Change an unselected input
        #1; check(4'hE);

        // Test Case 9: Corner case - max values and min values mixed
        d0 = 4'h0; d1 = 4'hF; d2 = 4'h5; d3 = 4'hA;
        sel = 2'b00; #1; check(4'h0);
        sel = 2'b01; #1; check(4'hF);
        sel = 2'b10; #1; check(4'h5);
        sel = 2'b11; #1; check(4'hA);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
