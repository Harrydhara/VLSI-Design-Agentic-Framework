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

    task check(input [3:0] ea, input [3:0] eb, input [2:0] eop, 
                    input [3:0] ey, input ec, input eo, input ez, input en);
        total = total + 1;
        if (y !== ey || carry !== ec || overflow !== eo || zero !== ez || negative !== en) begin
            $display("FAIL: a=%b b=%b op=%b | exp: y=%b c=%b o=%b z=%b n=%b | act: y=%b c=%b o=%b z=%b n=%b", 
                     a, b, op, ey, ec, eo, ez, en, y, carry, overflow, zero, negative);
            passed = passed + 0;
        end else begin
            passed = passed + 1;
        end
    endtask

    initial begin
        passed = 0;
        total = 0;

        // ADD: 5+3=8 (no carry, no ovf), 7+1=8 (no carry, ovf if signed? wait)
        // Signed overflow check: a[3]==b[3] and y[3]!=a[3]. 
        // 4'b0111(7) + 4'b0001(1) = 4'b1000(-8). a[3]=0, b[3]=0, y[3]=1. Correct.
        a = 4'b0111; b = 4'b0001; op = 3'b000; check(a,b,op, 4'b1000, 0, 1, 0, 1); // 7+1=8 (y=8, carry=0, ovf=1)
        a = 4'b0010; b = 4'b0011; op = 3'b000; check(a,b,op, 4'b0101, 0, 0, 0, 0); // 2+3=5
        a = 4'b1111; b = 4'b0001; op = 3'b000; check(a,b,op, 4'b0000, 1, 0, 0, 1); // -1+1=0 (carry=1 because sum is 5-bit 10000)
        // Wait, sum of 1111 + 0001 = 10000. y=0, carry=1. a[3]=1, b[3]=0 -> no overflow.

        // SUB: a >= b (carry=1), a < b (carry=0)
        a = 4'b0101; b = 4'b0010; op = 3'b001; check(a,b,op, 4'b0011, 1, 0, 0, 0); // 5-2=3 (carry=1)
        a = 4'b0010; b = 4'b0101; op = 3'b001; check(a,b,op, 4'b1101, 0, 0, 0, 1); // 2-5=-3 (carry=0)
        // Overflow SUB: a[3]!=b[3] and y[3]!=a[3].
        // 7 - (-1) => 0111 - 1111 = 4'b1000. a[3]=0, b[3]=1, y[3]=1. Correct.
        a = 4'b0111; b = 4'b1111; op = 3'b001; check(a,b,op, 4'b1000, 0, 0, 1, 1);

        // AND
        a = 4'b1010; b = 4'b1100; op = 3'b010; check(a,b,op, 4'b1000, 0, 0, 0, 1);
        // OR
        a = 4'b1010; b = 4'b0101; op = 3'b011; check(a,b,op, 4'b1111, 0, 0, 0, 1);
        // XOR
        a = 4'b1010; b = 4'b1100; op = 3'b100; check(a,b,op, 4'b0110, 0, 0, 0, 0);

        // SHL
        a = 4'b1011; op = 3'b101; b = 4'b0000; check(a,b,op, 4'b0110, 1, 0, 0, 0); // shift out 1
        a = 4'b0011; op = 3'b101; b = 4'b0000; check(a,b,op, 4'b0110, 0, 0, 0, 0); // shift out 0

        // SHR
        a = 4'b1101; op = 3'b110; b = 4'b0000; check(a,b,op, 4'b0110, 1, 0, 0, 0); // shift out 1
        a = 4'b0110; op = 3'b110; b = 4'b0000; check(a,b,op, 4'b0011, 0, 0, 0, 0); // shift out 0

        // SLT (Signed)
        a = 4'b0001; b = 4'b0010; op = 3'b111; check(a,b,op, 4'b0001, 0, 0, 0, 0); // 1 < 2 is true
        a = 4'b1111; b = 4'b0001; op = 3'b111; check(a,b,op, 4'b0001, 0, 0, 0, 0); // -1 < 1 is true
        a = 4'b1111; b = 4'b1110; op = 3'b111; check(a,b,op, 4'b0000, 0, 0, 0, 0); // -1 < -2 is false
        a = 4'b0000; b = 4'b0000; op = 3'b111; check(a,b,op, 4'b0000, 0, 0, 0, 0); // 0 < 0 is false

        // Zero and Negative checks
        a = 4'b0000; b = 4'b0000; op = 3'b010; check(a,b,op, 4'b0000, 1, 0, 0, 0); // zero=1
        a = 4'b1000; b = 4'b0000; op = 3'b010; check(a,b,op, 4'b1000, 0, 0, 0, 1); // neg=1

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
