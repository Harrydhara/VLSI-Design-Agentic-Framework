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
        input exp_z;
        input exp_c;
        input exp_ov;
        input exp_n;
        begin
            total = total + 1;
            if (y !== exp_y || zero !== exp_z || carry !== exp_c || overflow !== exp_ov || negative !== exp_n) begin
                $display("FAIL: op=%b a=%d b=%d | exp: y=%d z=%b c=%b ov=%b n=%b | act: y=%d z=%b c=%b ov=%b n=%b", 
                         op, a, b, exp_y, exp_z, exp_c, exp_ov, exp_n, y, zero, carry, overflow, negative);
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
        op = 3'b000; a = 8'hFF; b = 8'h0F; check_result(8'h0F, 0, 0, 0, 0);

        // Test OR
        op = 3'b001; a = 8'hAA; b = 8'h55; check_result(8'hFF, 0, 0, 0, 1);
        op = 3'b001; a = 8'h00; b = 8'h00; check_result(8'h00, 1, 0, 0, 0);

        // Test XOR
        op = 3'b010; a = 8'hAA; b = 8'h55; check_result(8'hFF, 0, 0, 0, 1);
        op = 3'b010; a = 8'hAA; b = 8'hAA; check_result(8'h00, 1, 0, 0, 0);

        // Test ADD
        op = 3'b011; a = 8'd10; b = 8'd20; check_result(8'd30, 0, 0, 0, 0);
        op = 3'b011; a = 8'hFF; b = 8'h01; check_result(8'h00, 1, 1, 0, 0); // Carry out
        op = 3'b011; a = 8'h7F; b = 8'h01; check_result(8'h80, 0, 0, 1, 1); // Signed overflow: pos+pos=neg
        op = 3'b011; a = 8'h80; b = 8'h80; check_result(8'h00, 1, 1, 1, 0); // Signed overflow: neg+neg=pos

        // Test SUB
        op = 3'b100; a = 8'd20; b = 8'd10; check_result(8'd10, 0, 1, 0, 0); // Carry (a>=b)
        op = 3'b100; a = 8'd10; b = 8'd20; check_result(8'hF6, 0, 0, 0, 1); // Carry (a<b), result is -10
        op = 3'b100; a = 8'h7F; b = 8'h80; check_result(8'hFF, 0, 0, 1, 1); // Signed overflow: pos-neg=neg (wait, 127 - (-128) = 255. In signed logic, result is -1. Sign of a was +, sign of y is +? No, diff[7] is 1. So a(0) != y(1). Correct.)
        // Let's re-verify SUB overflow: (a=127, b=-128) -> diff = 127 - (-128) = 255 (signed -1). 
        // a[7]=0, b[7]=1. Different signs. y[7]=1. y[7] != a[7]. Overflow=1. Correct.
        op = 3'b100; a = 8'h80; b = 8'h7F; check_result(8'h01, 0, 1, 1, 0); // Signed overflow: neg-pos=pos (a[7]=1, b[7]=0, y[7]=0. diff is -128 - 127 = -255 -> 1 in 8bit).
        // Wait, let's re-calculate a=8'h80(neg), b=8'h7F(pos). diff = 8'h80 - 8'h7F = 8'h01. 
        // a[7]=1, b[7]=0 (diff signs). y[7]=0. Since y[7] != a[7], overflow=1. Correct.

        // Test SRA
        op = 3'b101; a = 8'b1000_0001; b = 8'h00; check_result(8'b1100_0000, 0, 1, 0, 1); // Arithmetic shift: bit 7 stays
        op = 3'b101; a = 8'b0000_0011; b = 8'h00; check_result(8'b0000_0001, 0, 1, 0, 0); // Logical shift: bit 7 becomes 0

        // Test ROL
        op = 3'b110; a = 8'b1000_0001; b = 8'h00; check_result(8'b0000_0011, 0, 1, 0, 0); // bit 7 moves to bit 0
        op = 3'b110; a = 8'b0100_0000; b = 8'h00; check_result(8'b1000_0000, 0, 0, 0, 1); // bit 7 moves to bit 0

        // Test SLT
        op = 3'b111; a = 8'd5; b = 8'd10; check_result(8'h01, 0, 0, 0, 0); // 5 < 10
        op = 3'b111; a = 8'd10; b = 8'd5; check_result(8'h00, 1, 0, 0, 0); // 10 < 5 is false
        op = 3'b111; a = -8'd5; b = 8'd2; check_result(8'h01, 0, 0, 0, 0); // -5 < 2 (signed)
        op = 3'b111; a = 8'd2; b = -8'd5; check_result(8'h00, 1, 0, 0, 0); // 2 < -5 is false

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
