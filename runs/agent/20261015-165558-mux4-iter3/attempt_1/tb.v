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

        // Test Case 1: Exhaustive check of all select lines with specific patterns
        d0 = 4'hA; d1 = 4'hB; d2 = 4'hC; d3 = 4'hD;
        
        for (i = 0; i < 4; i = i + 1) begin
            sel = i[1:0];
            total = total + 1;
            case (sel)
                2'b00: if (y !== d0) begin
                    $display("FAIL: sel=%b, expected=%h, actual=%h", sel, d0, y);
                end else begin
                    passed = passed + 1;
                end
                2'b01: if (y !== d1) begin
                    $display("FAIL: sel=%b, expected=%h, actual=%h", sel, d1, y);
                end else begin
                    passed = passed + 1;
                end
                2'b10: if (y !== d2) begin
                    $display("FAIL: sel=%b, expected=%h, actual=%h", sel, d2, y);
                end else begin
                    passed = passed + 1;
                end
                2'b11: if (y !== d3) begin
                    $display("FAIL: sel=%b, expected=%h, actual=%h", sel, d3, y);
                end else begin
                    passed = passed + 1;
                end
            endcase
        end

        // Test Case 2: Corner cases (all zeros and all ones)
        d0 = 4'h0; d1 = 4'h0; d2 = 4'h0; d3 = 4'h0;
        for (i = 0; i < 4; i = i + 1) begin
            sel = i[1:0];
            total = total + 1;
            if (y !== 4'h0) begin
                $display("FAIL: sel=%b, expected=0, actual=%h", sel, y);
            end else begin
                passed = passed + 1;
            end
        end

        d0 = 4'hf; d1 = 4'hf; d2 = 4'hf; d3 = 4'hf;
        for (i = 0; i < 4; i = i + 1) begin
            sel = i[1:0];
            total = total + 1;
            if (y !== 4'hf) begin
                $display("FAIL: sel=%b, expected=f, actual=%h", sel, y);
            end else begin
                passed = passed + 1;
            end
        end

        // Test Case 3: Random values
        d0 = 4'b1010; d1 = 4'b0101; d2 = 4'b1100; d3 = 4'b0011;
        sel = 2'b10;
        total = total + 1;
        if (y !== 4'b1100) begin
            $display("FAIL: sel=%b, expected=c, actual=%h", sel, y);
        end else begin
            passed = passed + 1;
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
