module tb;

    reg [7:0] a;
    reg [7:0] b;
    reg       sel;
    wire [7:0] y;

    integer passed;
    integer total;

    mux2 uut (
        .a(a),
        .b(b),
        .sel(sel),
        .y(y)
    );

    initial begin
        passed = 0;
        total = 0;

        // Test Case 1: sel=0, a=0xAA, b=0xBB -> y should be 0xAA
        total = total + 1;
        a = 8'hAA; b = 8'hBB; sel = 1'b0;
        #1;
        if (y === 8'hAA) begin
            passed = passed + 1;
        end else begin
            $display("FAIL: a=%h, b=%h, sel=%b, expected=AA, actual=%h", a, b, sel, y);
        end

        // Test Case 2: sel=1, a=0xAA, b=0xBB -> y should be 0xBB
        total = total + 1;
        a = 8'hAA; b = 8'hBB; sel = 1'b1;
        #1;
        if (y === 8'hBB) begin
            passed = passed + 1;
        end else begin
            $display("FAIL: a=%h, b=%h, sel=%b, expected=BB, actual=%h", a, b, sel, y);
        end

        // Test Case 3: Corner case - all zeros
        total = total + 1;
        a = 8'h00; b = 8'h00; sel = 1'b0;
        #1;
        if (y === 8'h00) begin
            passed = passed + 1;
        end else begin
            $display("FAIL: a=%h, b=%h, sel=%b, expected=00, actual=%h", a, b, sel, y);
        end

        // Test Case 4: Corner case - all ones
        total = total + 1;
        a = 8'hFF; b = 8'hFF; sel = 1'b1;
        #1;
        if (y === 8'hFF) begin
            passed = passed + 1;
        end else begin
            $display("FAIL: a=%h, b=%h, sel=%b, expected=FF, actual=%h", a, b, sel, y);
        end

        // Test Case 5: Alternating bits
        total = total + 1;
        a = 8'h55; b = 8'hAA; sel = 1'b0;
        #1;
        if (y === 8'h55) begin
            passed = passed + 1;
        end else begin
            $display("FAIL: a=%h, b=%h, sel=%b, expected=55, actual=%h", a, b, sel, y);
        end

        total = total + 1;
        a = 8'h55; b = 8'hAA; sel = 1'b1;
        #1;
        if (y === 8'hAA) begin
            passed = passed + 1;
        end else begin
            $display("FAIL: a=%h, b=%h, sel=%b, expected=AA, actual=%h", a, b, sel, y);
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
