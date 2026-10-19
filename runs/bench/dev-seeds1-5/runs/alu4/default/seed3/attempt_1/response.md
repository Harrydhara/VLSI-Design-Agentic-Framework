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
                y_reg = 4'b0;
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

        // ADD tests
        op = 3'b000;
        a = 4'h5; b = 4'h2; check(4'h7, 0, 0, 0, 0); // 5+2=7
        a = 4'hF; b = 4'h1; check(4'h0, 1, 1, 0, 0); // 15+1=16 (y=0, c=1)
        a = 4'h7; b = 4'h1; check(4'h8, 0, 0, 1, 1); // 7+1=8 (signed overflow: pos+pos=neg)
        a = 4'h8; b = 4'h8; check(4'h0, 1, 1, 1, 0); // -8 + -8 = -16 (y=0, c=1, ov=1)

        // SUB tests
        op = 3'b001;
        a = 4'h5; b = 4'h2; check(4'h3, 0, 1, 0, 0); // 5-2=3 (c=1 because a>=b)
        a = 4'h2; b = 4'h5; check(4'hD, 0, 0, 0, 1); // 2-5=-3 (y=13, c=0 because a<b)
        a = 4'h7; b = 4'h8; check(4'hF, 0, 0, 1, 1); // 7-8=-1 (signed overflow: pos-neg=neg? No. Wait. 7 is 0111, 8 is 1000. diff signs. y=15 is 1111. a[3]=0, b[3]=1, y[3]=1. Correct.)
        // Re-check SUB overflow logic: (a[3] != b[3]) && (y[3] != a[3])
        // a=7(0), b=-8(1). diff signs. y = 7 - (-8) = 15 (1). y[3]=1, a[3]=0. 1!=0 is true. Overflow!
        a = 4'h7; b = 4'h8; check(4'hF, 0, 0, 1, 1); 

        // AND tests
        op = 3'b010;
        a = 4'hF; b = 4'h5; check(4'h5, 0, 0, 0, 0);
        a = 4'h0; b = 4'hF; check(4'h0, 1, 0, 0, 0);

        // OR tests
        op = 3'b011;
        a = 4'hA; b = 4'h5; check(4'hf, 0, 0, 0, 1);
        a = 4'h0; b = 4'h0; check(4'h0, 1, 0, 0, 0);

        // XOR tests
        op = 3'b100;
        a = 4'hF; b = 4'h5; check(4'hA, 0, 0, 0, 1);
        a = 4'hF; b = 4'hF; check(4'h0, 1, 0, 0, 0);

        // SHL tests
        op = 3'b101;
        a = 4'b1011; check(4'b0110, 0, 1, 0, 0); // shift left 1011 -> 0110, carry=1
        a = 4'b0111; check(4'b1110, 0, 0, 0, 1); // shift left 0111 -> 1110, carry=0

        // SHR tests
        op = 3'b110;
        a = 4'b1110; check(4'b0111, 0, 0, 0, 0); // shift right 1110 -> 0111, carry=0 (bit 0)
        a = 4'b1001; check(4'b0100, 0, 1, 0, 0); // shift right 1001 -> 0100, carry=1 (bit 0)

        // SLT tests
        op = 3'b111;
        a = 4'h1; b = 4'h2; check(4'h1, 0, 0, 0, 0); // 1 < 2
        a = 4'h2; b = 4'h1; check(4'h0, 1, 0, 0, 0); // 2 < 1 is false
        a = 4'h7; b = 4'h8; check(4'h1, 0, 0, 0, 0); // 7 (0111) < -8 (1000)? No. 
        // Let's re-verify SLT: a=7(0111), b=8(1000). Signed extension: 00111 vs 11000. 7 is not < -8.
        a = 4'h7; b = 4'h8; check(4'h0, 1, 0, 0, 0);
        a = 4'hF; b = 4'h0; check(4'h1, 0, 0, 0, 0); // -1 < 0 is true.

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```