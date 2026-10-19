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

        // Test Case 1: Exhaustive check of all select lines with specific values
        d0 = 4'hA; d1 = 4'hB; d2 = 4'hC; d3 = 4'hD;
        
        for (i = 0; i < 4; i = i + 1) begin
            sel = i[1:0];
            total = total + 1;
            case (sel)
                2'b00: if (y !== 4'hA) begin
                    $display("FAIL: sel=%b, d0=%h d1=%h d2=%h d3=%h, expected=%h, actual=%h", sel, d0, d1, d2, d3, 4'hA, y);
                end else begin
                    passed = passed + 1;
                end
                2'b01: if (y !== 4'hB) begin
                    $display("FAIL: sel=%b, d0=%h d1=%h d2=%h d3=%h, expected=%h, actual=%h", sel, d0, d1, d2, d3, 4'hB, y);
                end else begin
                    passed = passed + 1;
                end
                2'b10: if (y !== 4'hC) begin
                    $display("FAIL: sel=%b, d0=%h d1=%h d2=%h d3=%h, expected=%h, actual=%h", sel, d0, d1, d2, d3, 4'hC, y);
                end else begin
                    passed = passed + 1;
                end
                2'b11: if (y !== 4'hD) begin
                    $display("FAIL: sel=%b, d0=%h d1=%h d2=%h d3=%h, expected=%h, actual=%h", sel, d0, d1, d2, d3, 4'hD, y);
                end else begin
                    passed = passed + 1;
                end
            endcase
        end

        // Test Case 2: All zeros
        d0 = 4'b0000; d1 = 4'b0000; d2 = 4'b0000; d3 = 4'b0000;
        for (i = 0; i < 4; i = i + 1) begin
            sel = i[1:0];
            total = total + 1;
            if (y !== 4'b0000) begin
                $display("FAIL: sel=%b, expected=0, actual=%h", sel, y);
            end else begin
                passed = passed + 1;
            end
        end

        // Test Case 3: All ones
        d0 = 4'b1111; d1 = 4'b1111; d2 = 4'b1111; d3 = 4'b1111;
        for (i = 0; i < 4; i = i + 1) begin
            sel = i[1:0];
            total = total + 1;
            if (y !== 4'b1111) begin
                $display("FAIL: sel=%b, expected=F, actual=%h", sel, y);
            end else begin
                passed = passed + 1;
            end
        end

        // Test Case 4: Alternating patterns
        d0 = 4'b1010; d1 = 4'b0101; d2 = 4'b1100; d3 = 4'b0011;
        for (i = 0; i < 4; i = i + 1) begin
            sel = i[1:0];
            total = total + 1;
            case (sel)
                2'b00: if (y !== 4'b1010) begin $display("FAIL: sel=%b, expected=A, actual=%h", sel, y); end else passed = passed + 1; end
                2'b01: if (y !== 4'b0101) begin $display("FAIL: sel=%b, expected=5, actual=%h", sel, y); end else passed = passed + 1; end
                2'b10: if (y !== 4'b1100) begin $display("FAIL: sel=%b, expected=C, actual=%h", sel, y); end else passed = passed + 1; end
                2'b11: if (y !== 4'b0011) begin $display("FAIL: sel=%b, expected=3, actual=%h", sel, y); end else passed = passed + 1; end
            endcase
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
