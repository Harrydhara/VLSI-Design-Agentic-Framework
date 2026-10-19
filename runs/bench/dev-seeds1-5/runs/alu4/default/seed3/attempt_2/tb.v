module tb;
    reg [3:0] a, b;
    reg [2:0] op;
    wire [3:0] y;
    wire zero, carry, overflow, negative;

    integer passed, total;

    alu4 dut (
        .a(a),
        .b(b),
        .op(op),
        .y(y),
        .zero(zero),
        .carry(carry),
        .overflow(overflow),
        .negative(negative)
    );

    task check;
        input [3:0] exp_y;
        input exp_z;
        input exp_c;
        input exp_ov;
        input exp_n;
        begin
            total = total + 1;
            if (y !== exp_y || zero !== exp_z || carry !== exp_c || overflow !== exp_ov || negative !== exp_n) begin
                $display("FAIL: op=%b a=%b b=%b | Exp: y=%b z=%b c=%b ov=%b n=%b | Got: y=%b z=%b c=%b ov=%b n=%b", 
                         op, a, b, exp_y, exp_z, exp_c, exp_ov, exp_n, y, zero, carry, overflow, negative);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        passed = 0;
        total = 0;

        // ADD tests (op=000)
        op = 3'b000;
        a = 4'h5; b = 4'h2; check(4'h7, 0, 0, 0, 0);
        a = 4'hF; b = 4'h1; check(4'h0, 1, 1, 0, 0);
        a = 4'h7; b = 4'h1; check(4'h8, 0, 0, 1, 1);
        a = 4'h8; b = 4'h8; check(4'h0, 1, 1, 1, 0);

        // SUB tests (op=001)
        op = 3'b001;
        a = 4'h5; b = 4'h2; check(4'h3, 0, 1, 0, 0);
        a = 4'h2; b = 4'h5; check(4'hD, 0, 0, 0, 1);
        a = 4'h7; b = 4'h8; check(4'hF, 0, 0, 1, 1); // 7 - (-8) = 15 (signed overflow)

        // AND tests (op=010)
        op = 3'b010;
        a = 4'hF; b = 4'h5; check(4'h5, 0, 0, 0, 0);
        a = 4'h0; b = 4'hF; check(4'h0, 1, 0, 0, 0);

        // OR tests (op=011)
        op = 3'b011;
        a = 4'hA; b = 4'h5; check(4'hf, 0, 0, 0, 1);
        a = 4'h0; b = 4'h0; check(4'h0, 1, 0, 0, 0);

        // XOR tests (op=100)
        op = 3'b100;
        a = 4'hF; b = 4'h5; check(4'hA, 0, 0, 0, 1);
        a = 4'hF; b = 4'hF; check(4'h0, 1, 0, 0, 0);

        // SHL tests (op=101)
        op = 3'b101;
        a = 4'b1011; check(4'b0110, 0, 1, 0, 0);
        a = 4'b0111; check(4'b1110, 0, 0, 0, 1);

        // SHR tests (op=110)
        op = 3'b110;
        a = 4'b1110; check(4'b0111, 0, 0, 0, 0);
        a = 4'b1001; check(4'b0100, 0, 1, 0, 0);

        // SLT tests (op=111)
        op = 3'b111;
        a = 4'h1; b = 4'h2; check(4'h1, 0, 0, 0, 0);
        a = 4'h2; b = 4'h1; check(4'h0, 1, 0, 0, 0);
        a = 4'h7; b = 4'h8; check(4'h0, 1, 0, 0, 0); // 7 < -8 is false
        a = 4'hF; b = 4'h0; check(4'h1, 0, 0, 0, 0); // -1 < 0 is true

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
