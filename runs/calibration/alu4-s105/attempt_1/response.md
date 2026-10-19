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
                // Overflow for signed addition: same sign inputs produce different sign output
                if ((a[3] == b[3]) && (y_reg[3] != a[3]))
                    overflow_reg = 1'b1;
                else
                    overflow_reg = 1'b0;
            end
            3'b001: begin // SUB
                // Specification says carry is 1 when a >= b (no borrow)
                carry_reg = (a >= b);
                y_reg = a - b;
                // Overflow for signed subtraction: different sign inputs produce different sign output
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
                // Signed comparison: treat as 5-bit to handle sign extension correctly
                if (($signed({1'b0, a})) < ($signed({1'b0, b}))) // This is tricky in Verilog for 4-bit signed
                    y_reg = 4'd1;
                else
                    y_reg = 4'd0;
                // Correct way to do 4-bit signed comparison:
                if ((a[3] != b[3]) && (a[3] == 1'b1)) // a is neg, b is pos -> a < b
                    y_reg = 4'd1;
                else if (a[3] == b[3]) begin // same sign
                    if (a < b) y_reg = 4'd1;
                    else y_reg = 4'd0;
                end else begin // a is pos, b is neg -> a > b
                    y_reg = 4'd0;
                end
                // Re-calculating SLT properly:
                if ($signed(a) < $signed(b))
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
    assign zero = (y == 4'b0000);
    assign carry = carry_reg;
    assign overflow = overflow_reg;
    assign negative = y[3];

endmodule
```

```verilog
module tb;
    reg [3:0] a, b;
    reg [2:0] op;
    wire [3:0] y;
    wire zero, carry, overflow, negative;

    integer i, j, k;
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
        input [3:0] ea, eb;
        input [2:0] eop;
        input [3:0] ey;
        input ezero, ecarry, eoverflow, enegative;
        begin
            total = total + 1;
            if (y !== ey || zero !== ezero || carry !== ecarry || overflow !== eoverflow || negative !== enegative) begin
                $display("FAIL: a=%d b=%d op=%b | exp: y=%b z=%b c=%b v=%b n=%b | act: y=%b z=%b c=%b v=%b n=%b", 
                         ea, eb, eop, ey, ezero, ecarry, eoverflow, enegative, y, zero, carry, overflow, negative);
                passed = passed - 1;
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        passed = 0;
        total = 0;

        // ADD tests
        a = 4'd5; b = 4'd3; op = 3'b000; #1; // 8, c=0, v=0
        check(4'd5, 4'd3, 3'b000, 4'd8, 0, 0, 0, 0);
        a = 4'd10; b = 4'd7; op = 3'b000; #1; // 17 -> y=1, c=1, v=1 (signed: -6 + -7 = -13)
        // Wait, signed overflow check: a[3]=1, b[3]=1. sum is 17 (10001). y=1, carry=1.
        // a[3]==b[3] (1==1) and y[3]!=a[3] (0!=1) -> overflow = 1. Correct.
        check(4'd10, 4'd7, 3'b000, 4'd1, 0, 1, 1, 1);
        a = 4'd15; b = 4'd1; op = 3'b000; #1; // 16 -> y=0, c=1, v=0 (signed: -1 + 1 = 0)
        check(4'd15, 4'd1, 3'b000, 4'd0, 1, 1, 0, 0);

        // SUB tests
        a = 4'd10; b = 4'd5; op = 3'b001; #1; // 5, c=1 (a>=b), v=0
        check(4'd10, 4'd5, 3'b001, 4'd5, 0, 1, 0, 0);
        a = 4'd2; b = 4'd5; op = 3'b001; #1; // -3 (unsigned), c=0, v=0
        check(4'd2, 4'd5, 3'b001, 4'd13, 0, 0, 0, 1);
        a = 4'd7; b = 4'd8; op = 3'b001; #1; // a=0111, b=1000. diff sign. y=15 (1111). v=1?
        // SUB overflow: (a[3]!=b[3]) && (y[3]!=a[3]). 
        // a[3]=0, b[3]=1. y[3]=1. a[3]!=y[3] is true. So overflow=1. Correct.
        check(4'd7, 4'd8, 3'b001, 4'd15, 0, 0, 1, 1);

        // AND/OR/XOR tests
        a = 4'hF; b = 4'h5; op = 3'b010; #1; check(4'hF, 4'h5, 3'b010, 4'h5, 0, 0, 0, 0);
        a = 4'hF; b = 4'h5; op = 3'b011; #1; check(4'hF, 4'h5, 3'b011, 4'hF, 0, 0, 0, 1);
        a = 4'hF; b = 4'h5; op = 3'b100; #1; check(4'hF, 4'h5, 3'b100, 4'hA, 0, 0, 0, 1);

        // SHL/SHR tests
        a = 4'b1011; op = 3'b101; #1; check(4'b1011, 4'h0, 3'b101, 4'b0110, 0, 1, 0, 0);
        a = 4'b1011; op = 3'b110; #1; check(4'b1011, 4'h0, 3'b110, 4'b0101, 0, 1, 0, 0);
        a = 4'b0001; op = 3'b110; #1; check(4'b0001, 4'h0, 3'b110, 4'b0000, 1, 1, 0, 0);

        // SLT tests
        a = 4'd2; b = 4'd5; op = 3'b111; #1; check(4'd2, 4'd5, 3'b111, 4'd1, 0, 0, 0, 0);
        a = 4'd5; b = 4'd2; op = 3'b111; #1; check(4'd5, 4'd2, 3'b111, 4'd0, 1, 0, 0, 0);
        a = 4'sb1111; b = 4'sb0001; op = 3'b111; #1; // -1 < 1? Yes.
        check(4'sb1111, 4'sb0001, 3'b111, 4'd1, 0, 0, 0, 0);
        a = 4'sb1000; b = 4'sb0111; op = 3'b111; #1; // -8 < 7? Yes.
        check(4'sb1000, 4'sb0111, 3'b111, 4'd1, 0, 0, 0, 0);
        a = 4'sb0111; b = 4'sb1000; op = 3'b111; #1; // 7 < -8? No.
        check(4'sb0111, 4'sb1000, 3'b111, 4'd0, 1, 0, 0, 0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
```