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

        // Test Case 1: sel = 0, y should be a
        a = 8'hAA; b = 8'h55; sel = 1'b0;
        #1;
        check(a, b, sel, 8'hAA);

        // Test Case 2: sel = 1, y should be b
        a = 8'hAA; b = 8'h55; sel = 1'b1;
        #1;
        check(a, b, sel, 8'h55);

        // Test Case 3: All zeros
        a = 8'h00; b = 8'h00; sel = 1'b0;
        #1;
        check(a, b, sel, 8'h00);

        // Test Case 4: All ones
        a = 8'hFF; b = 8'hFF; sel = 1'b1;
        #1;
        check(a, b, sel, 8'hFF);

        // Test Case 5: Boundary values (0 and 255)
        a = 8'h00; b = 8'hFF; sel = 1'b0;
        #1;
        check(a, b, sel, 8'h00);

        a = 8'h00; b = 8'hFF; sel = 1'b1;
        #1;
        check(a, b, sel, 8'hFF);

        // Test Case 6: Alternating bits
        a = 8'hAA; b = 8'h55; sel = 1'b0;
        #1;
        check(a, b, sel, 8'hAA);

        a = 8'hAA; b = 8'h55; sel = 1'b1;
        #1;
        check(a, b, sel, 8'h55);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

    task check;
        input [7:0] t_a;
        input [7:0] t_b;
        input       t_sel;
        input [7:0] expected;
        begin
            total = total + 1;
            if (y === expected) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: a=%h, b=%h, sel=%b, expected=%h, actual=%h", t_a, t_b, t_sel, expected, y);
            end
        end
    endtask

endmodule
