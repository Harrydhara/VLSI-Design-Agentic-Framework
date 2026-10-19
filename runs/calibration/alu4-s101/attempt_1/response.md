```verilog
module alu4(
    input  [3:0] a,
    input  [3:0] b,
    input  [2:0] op,
    output [3:0] y,
    output       zero,
    output       carry,
    output       overflow,
    output       negative
);

    reg [3:0] y_reg;
    reg       carry_reg;
    reg       overflow_reg;

    always @(*) begin
        // Default values to prevent latches
        y_reg = 4'b0000;
        carry_reg = 1'b0;
        overflow_reg = 1'b0;

        case (op)
            3'b000: begin // ADD
                {carry_reg, y_reg} = a + b;
                // Overflow for signed addition: same sign inputs result in different sign output
                if ((a[3] == b[3]) && (y_reg[3] != a[3]))
                    overflow_reg = 1'b1;
                else
                    overflow_reg = 1'b0;
            end
            3'b001: begin // SUB
                // For subtraction, carry is defined as "no borrow" (a >= b)
                carry_reg = (a >= b);
                y_reg = a - b;
                // Overflow for signed subtraction: different sign inputs result in different sign output
                if ((a[3] != b[3]) && (y_reg[3] != a[3]))
                    overflow_reg = 1'b1;
                else
                    overflow_reg = 1'b0;
            end
            3'b010: begin // AND
                y_reg = a & b;
                carry_reg = 1'b0;
                overflow_reg = 1'b0;
            end
            3'b011: begin // OR
                y_reg = a | b;
                carry_reg = 1'b0;
                overflow_reg = 1'b0;
            end
            3'b100: begin // XOR
                y_reg = a ^ b;
                carry_reg = 1'b0;
                overflow_reg = 1'b0;
            end
            3'b101: begin // SHL
                y_reg = {a[2:0], 1'b0};
                carry_reg = a[3];
                overflow_reg = 1'b0;
            end
            3'b110: begin // SHR
                y_reg = {1'b0, a[3:1]};
                carry_reg = a[0];
                overflow_reg = 1'b0;
            end
            3'b111: begin // SLT (Signed Less Than)
                // Signed comparison: extend to 5 bits to handle sign bit correctly
                if ({a[3], a} < {b[3], b})
                    y_reg = 4'h1;
                else
                    y_reg = 4'h0;
                carry_reg = 1'b0;
                overflow_reg = 1'b0;
            end
            default: begin
                y_reg = 4'b0000;
                carry_reg = 1'b0;
                overflow_reg = 1'b0;
            end
        endcase
    end

    assign y = y_reg;
    assign carry = carry_reg;
    assign overflow = overflow_reg;
    assign zero = (y_reg == 4'b0000);
    assign negative = y_reg[3];

endmodule
```

```verilog
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
                $display("FAIL: op=%b a=%b b=%b | Exp: y=%b z=%b c=%b v=%b n=%b | Got: y=%b z=%b c=%b v=%b n=%b", 
                         op, a, b, exp_y, exp_z, exp_c, exp_v, exp_n, y, zero, carry, overflow, negative);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        passed = 0;
        total = 0;

        // ADD: 000
        a = 4'd5; b = 4'd3; op = 3'b000; #1; // 8, c=0, v=0
        check(4'd8, 0, 0, 0, 0);
        a = 4'd12; b = 4'd5; op = 3'b000; #1; // 17 -> y=1, c=1, v=1 (signed: -4 + 5 = 1, but overflow if treated as signed? No. Let's check spec)
        // Spec says: overflow is (a[3]==b[3]) && (y[3]!=a[3]). 
        // a=12(1100), b=5(0101). Signs differ, so overflow must be 0.
        a = 4'b1100; b = 4'b0101; op = 3'b000; #1; // y=0001, c=1, v=0 (signs diff)
        check(4'b0001, 0, 1, 0, 0);
        a = 4'b1000; b = 4'b1111; op = 3'b000; #1; // -8 + -1 = -9. y=0111 (7), c=1, v=1 (signs same, result sign diff)
        check(4'b0111, 0, 1, 1, 0);

        // SUB: 001
        a = 4'd10; b = 4'd4; op = 3'b001; #1; // 6, c=1 (no borrow), v=0
        check(4'd6, 0, 1, 0, 0);
        a = 4'd3; b = 4'd5; op = 3'b001; #1; // -2, c=0 (borrow), v=0
        check(4'b1110, 0, 0, 0, 1);
        a = 4'b0111; b = 4'b1000; op = 3'b001; #1; // 7 - (-8) = 15. y=1111 (signed -1), c=1, v=1
        check(4'b1111, 0, 1, 1, 1);

        // AND: 010
        a = 4'b1010; b = 4'b1100; op = 3'b010; #1;
        check(4'b1000, 0, 0, 0, 1);

        // OR: 011
        a = 4'b1010; b = 4'b1100; op = 3'b011; #1;
        check(4'b1110, 0, 0, 0, 1);

        // XOR: 100
        a = 4'b1010; b = 4'b1100; op = 3'b100; #1;
        check(4'b0110, 0, 0, 0, 0);

        // SHL: 101
        a = 4'b1011; op = 3'b101; #1; // y=0110, c=1
        check(4'b0110, 0, 1, 0, 0);
        a = 4'b0011; op = 3'b101; #1; // y=0110, c=0
        check(4'b0110, 0, 0, 0, 0);

        // SHR: 110
        a = 4'b1011; op = 3'b110; #1; // y=0101, c=1 (a[0])
        check(4'b0101, 0, 1, 0, 0);
        a = 4'b0011; op = 3'b110; #1; // y=0001, c=1 (a[0])
        check(4'b0001, 0, 1, 0, 0);

        // SLT: 111
        a = 4'b0010; b = 4'b0100; op = 3'b111; #1; // 2 < 4 -> 1
        check(4'h1, 0, 0, 0, 0);
        a = 4'b1110; b = 4'b1100; op = 3'b111; #1; // -2 < -4 is false -> 0
        check(4'h0, 1, 0, 0, 0);
        a = 4'b1110; b = 4'b0001; op = 3'b111; #1; // -2 < 1 is true -> 1
        check(4'h1, 0, 0, 0, 0);

        // Zero check
        a = 4'd0; b = 4'd0; op = 3'b010; #1; // AND 0&0=0
        check(4'h0, 1, 0, 0, 0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
```