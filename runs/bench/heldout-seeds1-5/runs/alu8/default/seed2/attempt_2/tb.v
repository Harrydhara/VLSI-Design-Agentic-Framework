module tb;
    reg [7:0] a, b;
    reg [2:0] op;
    wire [7:0] y;
    wire zero, carry, overflow, negative;

    integer passed, total;

    alu8 dut (
        .a(a),
        .b(b),
        .op(op),
        .y(y),
        .zero(zero),
        .carry(carry),
        .overflow(overflow),
        .negative(negative)
    );

    task check_result;
        input [7:0] exp_y;
        input exp_z;
        input exp_c;
        input exp_ov;
        input exp_n;
        begin
            total = total + 1;
            if (y !== exp_y || zero !== exp_z || carry !== exp_c || overflow !== exp_ov || negative !== exp_n) begin
                $display("FAIL: a=%h b=%h op=%b | Exp: y=%h z=%b c=%b ov=%b n=%b | Got: y=%h z=%b c=%b ov=%b n=%b", 
                         a, b, op, exp_y, exp_z, exp_c, exp_ov, exp_n, y, zero, carry, overflow, negative);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        passed = 0;
        total = 0;

        // Test AND
        op = 3'b000; a = 8'hAA; b = 8'h55; check_result(8'h00, 1, 0, 0, 0);
        op = 3'b000; a = 8'hFF; b = 8'hF0; check_result(8'hF0, 0, 0, 0, 1);

        // Test OR
        op = 3'b001; a = 8'hAA; b = 8'h55; check_result(8'hFF, 0, 0, 0, 1);
        op = 3'b001; a = 8'h00; b = 8'h00; check_result(8'h00, 1, 0, 0, 0);

        // Test XOR
        op = 3'b010; a = 8'hFF; b = 8'hFF; check_result(8'h00, 1, 0, 0, 0);
        op = 3'b010; a = 8'hAA; b = 8'h55; check_result(8'hFF, 0, 0, 0, 1);

        // Test ADD
        op = 3'b011; a = 8'h01; b = 8'h02; check_result(8'h03, 0, 0, 0, 0);
        op = 3'b011; a = 8'hFF; b = 8'h01; check_result(8'h00, 1, 1, 0, 0);
        op = 3'b011; a = 8'h7F; b = 8'h01; check_result(8'h80, 0, 0, 1, 1);
        op = 3'b011; a = 8'h80; b = 8'h80; check_result(8'h00, 1, 1, 1, 0);

        // Test SUB
        op = 3'b100; a = 8'h05; b = 8'h02; check_result(8'h03, 0, 1, 0, 0); // carry=1 (a>=b)
        op = 3'b100; a = 8'h02; b = 8'h05; check_result(8'hFD, 0, 0, 0, 1); // carry=0 (a<b), y is -3
        op = 3'b100; a = 8'h80; b = 8'h01; check_result(8'h7F, 0, 0, 1, 0); // overflow: diff sign, result pos (neg-pos=pos)
        op = 3'b100; a = 8'h01; b = 8'h80; check_result(8'h81, 0, 0, 1, 1); // overflow: diff sign, result neg (pos-neg=neg)
        op = 3'b100; a = 8'hFF; b = 8'hFF; check_result(8'h00, 1, 1, 0, 0);

        // Test SRA
        op = 3'b101; a = 8'h82; b = 8'h00; check_result(8'h41, 0, 0, 0, 0);
        op = 3'b101; a = 8'h81; b = 8'h00; check_result(8'hC0, 0, 1, 0, 1);
        op = 3'b101; a = 8'h01; b = 8'h00; check_result(8'h00, 1, 1, 0, 0);

        // Test ROL
        op = 3'b110; a = 8'h81; b = 8'h00; check_result(8'h03, 0, 1, 0, 0);
        op = 3'b110; a = 8'h01; b = 8'h00; check_result(8'h02, 0, 0, 0, 0);

        // Test SLT
        op = 3'b111; a = 8'h05; b = 8'h0A; check_result(8'h01, 0, 0, 0, 0);
        op = 3'b111; a = 8'h0A; b = 8'h05; check_result(8'h00, 1, 0, 0, 0);
        op = 3'b111; a = 8'hFF; b = 8'h01; check_result(8'h00, 1, 0, 0, 0);
        op = 3'b111; a = 8'h01; b = 8'hFF; check_result(8'h01, 0, 0, 0, 0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
