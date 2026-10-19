module tb;
    reg [7:0] a, b;
    reg [2:0] op;
    wire [7:0] y;
    wire zero, carry, overflow, negative;

    integer i, j;
    integer passed, total;

    alu8 uut (
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
        input exp_z, exp_c, exp_o, exp_n;
        begin
            total = total + 1;
            if (y !== exp_y || zero !== exp_z || carry !== exp_c || overflow !== exp_o || negative !== exp_n) begin
                $display("FAIL: op=%b a=%d b=%d | expected y=%d z=%b c=%b o=%b n=%b, actual y=%d z=%b c=%b o=%b n=%b", 
                         op, a, b, exp_y, exp_z, exp_c, exp_o, exp_n, y, zero, carry, overflow, negative);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        passed = 0;
        total = 0;

        // Test AND
        a = 8'hAA; b = 8'h55; op = 3'b000; #1; check_result(8'h00, 1, 0, 0, 0);
        a = 8'hFF; b = 8'h0F; op = 3'b000; #1; check_result(8'h0F, 0, 0, 0, 0);

        // Test OR
        a = 8'hAA; b = 8'h55; op = 3'b001; #1; check_result(8'hFF, 0, 0, 0, 0);
        a = 8'h00; b = 8'h00; op = 3'b001; #1; check_result(8'h00, 1, 0, 0, 0);

        // Test XOR
        a = 8'hAA; b = 8'h55; op = 3'b010; #1; check_result(8'hFF, 0, 0, 0, 0);
        a = 8'hAA; b = 8'hAA; op = 3'b010; #1; check_result(8'h00, 1, 0, 0, 0);

        // Test ADD
        a = 8'h05; b = 8'h02; op = 3'b011; #1; check_result(8'h07, 0, 0, 0, 0); // Normal
        a = 8'hFF; b = 8'h01; op = 3'b011; #1; check_result(8'h00, 1, 1, 0, 0); // Carry out
        a = 8'h7F; b = 8'h01; op = 3'b011; #1; check_result(8'h80, 0, 0, 1, 1); // Signed Overflow (pos+pos=neg)
        a = 8'h80; b = 8'h80; op = 3'b011; #1; check_result(8'h00, 1, 1, 0, 0); // Carry out, no overflow (neg+neg=pos is wrong? No: 80+80=100. Sign bits same (1), result sign (0). Overflow!)
        // Re-check 80 + 80: a[7]=1, b[7]=1, y[7]=0. Same signs, different result sign -> overflow = 1. Correct.
        a = 8'h80; b = 8'h80; op = 3'b011; #1; check_result(8'h00, 1, 1, 1, 0);

        // Test SUB
        a = 8'h0A; b = 8'h05; op = 3'b100; #1; check_result(8'h05, 0, 1, 0, 0); // a >= b (carry=1)
        a = 8'h05; b = 8'h0A; op = 3'b100; #1; check_result(8'hFB, 0, 0, 0, 1); // a < b (carry=0), result is -5
        a = 8'h7F; b = 8'h80; op = 3'b100; #1; check_result(8'hFF, 0, 0, 1, 1); // Signed Overflow (pos-neg=neg)
        a = 8'h80; b = 8'h7F; op = 3'b100; #1; check_result(8'h01, 0, 1, 1, 0); // Signed Overflow (neg-pos=pos)

        // Test SRA
        a = 8'b1000_0011; b = 8'h00; op = 3'b101; #1; check_result(8'b1100_0001, 0, 1, 0, 1); // Shifted bit 0 (1) to carry
        a = 8'b0100_0011; b = 8'h00; op = 3'b101; #1; check_result(8'b0010_0001, 0, 1, 0, 0); // Shifted bit 0 (1) to carry

        // Test ROL
        a = 8'b1000_0001; b = 8'h00; op = 3'b110; #1; check_result(8'b0000_0011, 0, 1, 0, 0); // bit 7 (1) to carry
        a = 8'b0100_0001; b = 8'h00; op = 3'b110; #1; check_result(8'b1000_0010, 0, 0, 0, 1); // bit 7 (0) to carry

        // Test SLT
        a = 8'd5; b = 8'd10; op = 3'b111; #1; check_result(8'h01, 0, 0, 0, 0); // 5 < 10
        a = 8'd10; b = 8'd5; op = 3'b111; #1; check_result(8'h00, 1, 0, 0, 0); // 10 < 5 is false
        a = -8'd5; b = 8'd5; op = 3'b111; #1; check_result(8'h01, 0, 0, 0, 0); // -5 < 5
        a = 8'd5; b = -8'd5; op = 3'b111; #1; check_result(8'h00, 1, 0, 0, 0); // 5 < -5 is false

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
