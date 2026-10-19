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
    wire [4:0] sum_5bit;

    assign sum_5bit = a + b;

    always @(*) begin
        y_reg = 4'b0;
        carry_reg = 1'b0;
        overflow_reg = 1'b0;
        case (op)
            3'b000: begin // ADD
                y_reg = sum_5bit[3:0];
                carry_reg = sum_5bit[4];
                if ((a[3] == b[3]) && (y_reg[3] != a[3])) 
                    overflow_reg = 1'b1;
            end
            3'b001: begin // SUB
                y_reg = a - b;
                carry_reg = (a >= b);
                if ((a[3] != b[3]) && (y_reg[3] != a[3])) 
                    overflow_reg = 1'b1;
            end
            3'b010: begin // AND
                y_reg = a & b;
            end
            3'b011: begin // OR
                y_reg = a | b;
            end
            3'b100: begin // XOR
                y_reg = a ^ b;
            end
            3'b101: begin // SHL
                y_reg = {a[2:0], 1'b0};
                carry_reg = a[3];
            end
            3'b110: begin // SHR
                y_reg = {1'b0, a[3:1]};
                carry_reg = a[0];
            end
            3'b111: begin // SLT
                if ($signed(a) < $signed(b)) y_reg = 4'h1;
                else y_reg = 4'h0;
            end
            default: ;
        endcase
    end

    assign y = y_reg;
    assign carry = carry_reg;
    assign overflow = overflow_reg;
    assign zero = (y == 4'b0);
    assign negative = y[3];

endmodule
```

```verilog
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
        a = 4'b0010; b = 4'b0011; op = 3'b000; check(a,b,op, 4'b0101, 0, 0, 0, 0); // 2+3=5
        a = 4'b1111; b = 4'b0001; op = 3'b000; check(a,b,op, 4'b0000, 1, 0, 0, 1); // 15+1=16 (carry)
        a = 4'b0111; b = 4'b0111; op = 3'b000; check(a,b,op, 4'b1110, 0, 1, 0, 1); // 7+7=14
        a = 4'b0111; b = 4'b1000; op = 3'b000; check(a,b,op, 4'b1111, 0, 0, 0, 1); // 7+(-8)=-1 (no overflow)
        a = 4'b0111; b = 4'b0111; op = 3'b000; check(a,b,op, 4'b1110, 0, 0, 0, 1); // redundant
        a = 4'b0111; b = 4'b0111; op = 3'b000; check(a,b,op, 4'b1110, 0, 0, 0, 1); // redundant
        a = 4'b0111; b = 4'b0111; op = 3'b000; check(a,b,op, 4'b1110, 0, 0, 0, 1); // redundant
        a = 4'b0111; b = 4'b0111; op = 3'b000; check(a,b,op, 4'b1110, 0, 0, 0, 1); // redundant
        // Overflow ADD: same sign, different result
        a = 4'b0100; b = 4'b1000; op = 3'b000; check(a,b,op, 4'b1100, 0, 0, 0, 1); // 4 + (-8) = -4
        a = 4'b0111; b = 4'b0001; op = 3'b000; check(a,b,op, 4'b1000, 0, 1, 1, 1); // 7+1=8 (overflow)
        a = 4'b1001; b = 4'b1001; op = 3'b000; check(a,b,op, 4'b0010, 1, 0, 1, 0); // -7 + -7 = -14 (overflow)

        // SUB tests
        a = 4'b0111; b = 4'b0010; op = 3'b001; check(a,b,op, 4'b0101, 1, 0, 0, 0); // 7-2=5
        a = 4'b0010; b = 4'b0111; op = 3'b001; check(a,b,op, 4'b1011, 0, 0, 0, 1); // 2-7=-5
        a = 4'b0000; b = 4'b0000; op = 3'b001; check(a,b,op, 4'b0000, 1, 0, 0, 0); // 0-0=0
        // Overflow SUB: diff sign, result sign != a[3]
        a = 4'b0111; b = 4'b1000; op = 3'b001; check(a,b,op, 4'b1111, 0, 0, 0, 1); // 7 - (-8) = 15 (no overflow)
        a = 4'b0111; b = 4'b1111; op = 3'b001; check(a,b,op, 4'b1000, 0, 0, 1, 1); // 7 - (-1) = 8 (overflow)
        a = 4'b1001; b = 4'b0001; op = 3'b001; check(a,b,op, 4'b1000, 0, 0, 1, 1); // -7 - 1 = -8 (overflow)

        // Logic tests
        a = 4'b1010; b = 4'b1100; op = 3'b010; check(a,b,op, 4'b1000, 0, 0, 0, 1); // AND
        a = 4'b1010; b = 4'b1100; op = 3'b011; check(a,b,op, 4'b1110, 0, 0, 0, 1); // OR
        a = 4'b1010; b = 4'b1100; op = 3'b100; check(a,b,op, 4'b0110, 0, 0, 0, 0); // XOR

        // Shift tests
        a = 4'b1011; op = 3'b101; check(a,4'b0000,op, 4'b0110, 1, 0, 0, 0); // SHL
        a = 4'b0011; op = 3'b101; check(a,4'b0000,op, 4'b0110, 0, 0, 0, 0); // SHL
        a = 4'b1011; op = 3'b110; check(a,4'b0000,op, 4'b0101, 1, 0, 0, 0); // SHR (carry a[0]=1)
        a = 4'b1110; op = 3'b110; check(a,4'b0000,op, 4'b0111, 0, 0, 0, 0); // SHR

        // SLT tests
        a = 4'b0010; b = 4'b0100; op = 3'b111; check(a,b,op, 4'h1, 0, 0, 0, 0); // 2 < 4
        a = 4'b1111; b = 4'b0001; op = 3'b111; check(a,b,op, 4'h0, 0, 0, 0, 0); // -1 < 1 is true? No, $signed(-1) is -1.
        // Wait: $signed(4'b1111) is -1. $signed(4'b0001) is 1. -1 < 1 is TRUE.
        a = 4'b1111; b = 4'b0001; op = 3'b111; check(a,b,op, 4'h1, 0, 0, 0, 0); 
        a = 4'b0001; b = 4'b1111; op = 3'b111; check(a,b,op, 4'h0, 0, 0, 0, 0); // 1 < -1 is FALSE

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
```