module tb;
    reg [3:0] a, b;
    reg [2:0] op;
    wire [3:0] y;
    wire zero, carry, overflow, negative;

    integer passed, total;

    alu4 dut (
        .a(a), .b(b), .op(op), 
        .y(y), .zero(zero), .carry(carry), 
        .overflow(overflow), .negative(negative)
    );

    task check(input [3:0] ea, input [3:0] eb, input [2:0] eop, 
               input [3:0] ey, input ec, input ev, input ez, input en);
        begin
            total = total + 1;
            if (y !== ey || carry !== ec || overflow !== ev || zero !== ez || negative !== en) begin
                $display("FAIL: a=%b b=%b op=%b | exp: y=%b c=%b v=%b z=%b n=%b | act: y=%b c=%b v=%b z=%b n=%b", 
                         a, b, op, ey, ec, ev, ez, en, y, carry, overflow, zero, negative);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        passed = 0; total = 0;

        // ADD tests
        a = 4'b0010; b = 4'b0011; op = 3'b000; check(a,b,op, 4'b0101, 0, 0, 0, 0);
        a = 4'b1111; b = 4'b0001; op = 3'b000; check(a,b,op, 4'b0000, 1, 0, 1, 0); // Corrected: overflow for 15+1 is (0==0 && 0!=0) -> false. Wait, sign bits are a[3]=1, b[3]=0. So no overflow.
        // Re-evaluating ADD Overflow logic: (a[3]==b[3]) && (y[3]!=a[3])
        a = 4'b1111; b = 4'b0001; op = 3'b000; check(a,b,op, 4'b0000, 1, 0, 0, 0); // 15+1=16. a[3]=1, b[3]=0 -> no overflow.
        a = 4'b0111; b = 4'b0111; op = 3'b000; check(a,b,op, 4'b1110, 0, 0, 0, 1); // 7+7=14. a[3]=0, b[3]=0, y[3]=1 -> overflow!
        // Wait, my manual check was wrong. Let's use the logic: (a[3]==b[3]) && (y[3]!=a[3])
        // 7+7=14 (0111 + 0111 = 1110). a[3]=0, b[3]=0. y[3]=1. (0==0) && (1!=0) is TRUE.
        a = 4'b0111; b = 4'b0111; op = 3'b000; check(a,b,op, 4'b1110, 0, 1, 0, 1); // Corrected: carry is bit 4 of sum. 7+7=14 (no carry).
        // Let's re-run carefully.
        a = 4'b0111; b = 4'b0111; op = 3'b000; check(a,b,op, 4'b1110, 0, 1, 0, 1); // Wait, sum is 14. Carry bit is 0.
        // Let's just use simple cases to avoid confusion.
        a = 4'b0001; b = 4'b0001; op = 3'b000; check(a,b,op, 4'b0010, 0, 0, 0, 0);
        a = 4'b1111; b = 4'b1111; op = 3'b000; check(a,b,op, 4'b1110, 1, 1, 0, 1); // -1 + -1 = -2. a[3]=1, b[3]=1, y[3]=1. No overflow. Carry=1.
        a = 4'b0111; b = 4'b0111; op = 3'b000; check(a,b,op, 4'b1110, 0, 0, 1, 1); // 7+7=14. a[3]=0, b[3]=0, y[3]=1. Overflow!

        // SUB tests
        a = 4'b0111; b = 4'b0010; op = 3'b001; check(a,b,op, 4'b0101, 1, 0, 0, 0); // 7-2=5
        a = 4'b0010; b = 4'b0111; op = 3'b001; check(a,b,op, 4'b1011, 0, 0, 0, 1); // 2-7=-5
        a = 4'b0111; b = 4'b1111; op = 3'b001; check(a,b,op, 4'b1000, 0, 0, 1, 1); // 7 - (-1) = 8. a[3]=0, b[3]=1, y[3]=1. Overflow!
        a = 4'b1001; b = 4'b0001; op = 3'b001; check(a,b,op, 4'b1000, 0, 0, 1, 1); // -7-1=-8. a[3]=1, b[3]=0, y[3]=1. Overflow!

        // Logic
        a = 4'b1010; b = 4'b1100; op = 3'b010; check(a,b,op, 4'b1000, 0, 0, 0, 1);
        a = 4'b1010; b = 4'b1100; op = 3'b011; check(a,b,op, 4'b1110, 0, 0, 0, 1);
        a = 4'b1010; b = 4'b1100; op = 3'b100; check(a,b,op, 4'b0110, 0, 0, 0, 0);

        // Shift
        a = 4'b1011; op = 3'b101; check(a,4'b0000,op, 4'b0110, 1, 0, 0, 0);
        a = 4'b1011; op = 3'b110; check(a,4'b0000,op, 4'b0101, 1, 0, 0, 0);

        // SLT
        a = 4'b0010; b = 4'b0100; op = 3'b111; check(a,b,op, 4'h1, 0, 0, 0, 0);
        a = 4'b1111; b = 4'b0001; op = 3'b111; check(a,b,op, 4'h1, 0, 0, 0, 0); // -1 < 1
        a = 4'b0001; b = 4'b1111; op = 3'b111; check(a,b,op, 4'h0, 0, 0, 0, 0); // 1 < -1

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
