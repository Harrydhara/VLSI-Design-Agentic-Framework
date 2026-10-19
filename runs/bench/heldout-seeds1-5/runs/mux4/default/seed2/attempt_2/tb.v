module tb;

    reg [3:0] d0, d1, d2, d3;
    reg [1:0] sel;
    wire [3:0] y;

    integer i;
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

    initial begin
        passed = 0;
        total = 0;

        // Test Case 1: All inputs same
        d0 = 4'hA; d1 = 4'hA; d2 = 4'hA; d3 = 4'hA;
        for (i = 0; i < 4; i = i + 1) begin
            sel = i[1:0];
            #1; // Allow combinational logic to settle
            total = total + 1;
            if (y === 4'hA) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: sel=%d, expected=4'hA, actual=%h", sel, y);
            end
        end

        // Test Case 2: All inputs different
        d0 = 4'h1; d1 = 4'h2; d2 = 4'h3; d3 = 4'h4;
        for (i = 0; i < 4; i = i + 1) begin
            sel = i[1:0];
            #1; // Allow combinational logic to settle
            total = total + 1;
            case (sel)
                2'b00: if (y === 4'h1) passed = passed + 1; else $display("FAIL: sel=%d, expected=4'h1, actual=%h", sel, y);
                2'b01: if (y === 4'h2) passed = passed + 1; else $display("FAIL: sel=%d, expected=4'h2, actual=%h", sel, y);
                2'b10: if (y === 4'h3) passed = passed + 1; else $display("FAIL: sel=%d, expected=4'h3, actual=%h", sel, y);
                2'b11: if (y === 4'h4) passed = passed + 1; else $display("FAIL: sel=%d, expected=4'h4, actual=%h", sel, y);
            endcase
        end

        // Test Case 3: All zeros and all ones
        d0 = 4'h0; d1 = 4'hF; d2 = 4'h0; d3 = 4'hF;
        for (i = 0; i < 4; i = i + 1) begin
            sel = i[1:0];
            #1; // Allow combinational logic to settle
            total = total + 1;
            if (sel == 2'b00 || sel == 2'b10) begin
                if (y === 4'h0) passed = passed + 1;
                else $display("FAIL: sel=%d, expected=4'h0, actual=%h", sel, y);
            end else begin
                if (y === 4'hF) passed = passed + 1;
                else $display("FAIL: sel=%d, expected=4'hF, actual=%h", sel, y);
            end
        end

        // Test Case 4: Random patterns
        d0 = 4'b1010; d1 = 4'b0101; d2 = 4'b1100; d3 = 4'b0011;
        for (i = 0; i < 4; i = i + 1) begin
            sel = i[1:0];
            #1; // Allow combinational logic to settle
            total = total + 1;
            case (sel)
                2'b00: if (y === 4'b1010) passed = passed + 1; else $display("FAIL: sel=%d, expected=4'b1010, actual=%b", sel, y);
                2'b01: if (y === 4'b0101) passed = passed + 1; else $display("FAIL: sel=%d, expected=4'b0101, actual=%b", sel, y);
                2'b10: if (y === 4'b1100) passed = passed + 1; else $display("FAIL: sel=%d, expected=4'b1100, actual=%b", sel, y);
                2'b11: if (y === 4'b0011) passed = passed + 1; else $display("FAIL: sel=%d, expected=4'b0011, actual=%b", sel, y);
            endcase
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
