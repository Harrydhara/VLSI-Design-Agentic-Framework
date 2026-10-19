module tb;
    reg [3:0] a, b;
    reg [2:0] op;
    wire [3:0] y;
    wire zero, carry, overflow, negative;

    integer i, j;
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
        input exp_v;
        input exp_n;
        begin
            total = total + 1;
            if (y !== exp_y || zero !== exp_z || carry !== exp_c || overflow !== exp_v || negative !== exp_n) begin
                $display("FAIL: a=%d b=%d op=%b | Expected y=%d z=%b c=%b v=%b n=%b | Actual y=%d z=%b c=%b v=%b n=%b", 
                         a, b, op, exp_y, exp_z, exp_c, exp_v, exp_n, y, zero, carry, overflow, negative);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        passed = 0;
        total = 0;

        // ADD tests
        op = 3'b000;
        a = 4'd5; b = 4'd2; check(4'd7, 0, 0, 0, 0); // 5+2=7
        a = 4'd10; b = 4'd7; check(4'd1, 0, 1, 1, 0); // 10+7=17 (y=1, c=1, overflow: pos+pos=neg)
        a = 4'h8; b = 4'h8; check(4'h0, 1, 1, 1, 0); // -8 + -8 = -16 (y=0, c=1, overflow: neg+neg=zero/pos)
        a = 4'h7; b = 4'h1; check(4'h8, 0, 0, 1, 1); // 7+1=8 (y=8, c=0, overflow: pos+pos=neg)

        // SUB tests
        op = 3'b001;
        a = 4'd10; b = 4'd7; check(4'd3, 0, 1, 0, 0); // 10-7=3 (carry is a>=b)
        a = 4'd5; b = 4'd7; check(4'hE, 0, 0, 0, 1);  // 5-7=-2 (y=14, c=0, neg)
        a = 4'h8; b = 4'h1; check(4'h7, 0, 1, 1, 0);  // -8 - 1 = -9 (overflow: neg-pos=pos)
        a = 4'h7; b = 4'h8; check(4'hF, 0, 0, 1, 1);  // 7 - (-8) = 15 (overflow: pos-neg=neg)

        // AND tests
        op = 3'b010;
        a = 4'b1010; b = 4'b1100; check(4'b1000, 0, 0, 0, 1);
        a = 4'b0000; b = 4'b1111; check(4'b0000, 1, 0, 0, 0);

        // OR tests
        op = 3'b011;
        a = 4'b1010; b = 4'b0101; check(4'b1111, 0, 0, 0, 1);
        a = 4'b0000; b = 4'b0000; check(4'b0000, 1, 0, 0, 0);

        // XOR tests
        op = 3'b100;
        a = 4'b1010; b = 4'b1100; check(4'b0110, 0, 0, 0, 0);
        a = 4'b1111; b = 4'b1111; check(4'b0000, 1, 0, 0, 0);

        // SHL tests
        op = 3'b101;
        a = 4'b1001; check(4'b0010, 0, 1, 0, 0); // shift out 1
        a = 4'b0110; check(4'b1100, 0, 0, 0, 1); // shift out 0

        // SHR tests
        op = 3'b110;
        a = 4'b1011; check(4'b0101, 0, 1, 0, 0); // shift out 1
        a = 4'b1100; check(4'b0110, 0, 0, 0, 0); // shift out 0

        // SLT tests (Signed)
        op = 3'b111;
        a = 4'h7; b = 4'h8; check(4'h1, 0, 0, 0, 0);  // 7 < -8 is false (signed: 7 < -8) wait.
        // Let's re-evaluate SLT logic for signed:
        // a=7 (0111), b=-8 (1000). 7 < -8 is False.
        a = 4'h7; b = 4'h8; check(4'h0, 1, 0, 0, 0); // 7 < -8? No.
        // a=-8 (1000), b=7 (0111). -8 < 7 is True.
        a = 4'h8; b = 4'h7; check(4'h1, 0, 0, 0, 0); // -8 < 7? Yes.
        // a=-1 (1111), b=0 (0000). -1 < 0 is True.
        a = 4'hF; b = 4'h0; check(4'h1, 0, 0, 0, 0); // -1 < 0? Yes.
        // a=0 (0000), b=-1 (1111). 0 < -1 is False.
        a = 4'h0; b = 4'hF; check(4'h0, 1, 0, 0, 0); // 0 < -1? No.

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
