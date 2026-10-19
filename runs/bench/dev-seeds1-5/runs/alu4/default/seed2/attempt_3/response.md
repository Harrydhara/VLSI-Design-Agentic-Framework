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
                if ((a[3] == b[3]) && (y_reg[3] != a[3]))
                    overflow_reg = 1'b1;
                else
                    overflow_reg = 1'b0;
            end
            3'b001: begin // SUB
                // carry is 1 exactly when a >= b as unsigned numbers
                carry_reg = (a >= b);
                y_reg = a - b;
                // overflow for subtraction: (a[3] != b[3]) && (y[3] != a[3])
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
                // Signed comparison using two's complement logic
                if ((a[3] != b[3]) && (a[3] == 1'b1))
                    y_reg = 4'b0001;
                else if ((a[3] == b[3]) && (($signed(a) < $signed(b))))
                    y_reg = 4'b0001;
                else
                    y_reg = 4'b0000;
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
    assign zero = (y_reg == 4'b0000);
    assign carry = carry_reg;
    assign overflow = overflow_reg;
    assign negative = y_reg[3];

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
        input [3:0] exp_y;
        input exp_z;
        input exp_c;
        input exp_o;
        input exp_n;
        begin
            total = total + 1;
            if (y !== exp_y || zero !== exp_z || carry !== exp_c || overflow !== exp_o || negative !== exp_n) begin
                $display("FAIL: op=%b a=%b b=%b | expected y=%b z=%b c=%b o=%b n=%b | actual y=%b z=%b c=%b o=%b n=%b", 
                         op, a, b, exp_y, exp_z, exp_c, exp_o, exp_n, y, zero, carry, overflow, negative);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        passed = 0;
        total = 0;

        // ADD tests (op=000)
        a = 4'b0010; b = 4'b0011; op = 3'b000; check_result(4'b0101, 0, 0, 0, 0); // 2+3=5
        a = 4'b1111; b = 4'b0001; op = 3'b000; check_result(4'b0000, 1, 1, 0, 0); // 15+1=16 (y=0, c=1)
        a = 4'b0111; b = 4'b0111; op = 3'b000; check_result(4'b1110, 0, 0, 1, 1); // 7+7=14 (signed overflow)
        a = 4'b1000; b = 4'b1000; op = 3'b000; check_result(4'b0000, 1, 1, 1, 0); // -8 + -8 = -16 (y=0, c=1, overflow: neg+neg=pos? no, here y[3]=0)

        // SUB tests (op=001)
        a = 4'b0101; b = 4'b0010; op = 3'b001; check_result(4'b0011, 0, 1, 0, 0); // 5-2=3 (c=1 because a>=b)
        a = 4'b0010; b = 4'b0101; op = 3'b001; check_result(4'b1101, 0, 0, 0, 1); // 2-5=-3 (c=0 because a<b)
        a = 4'b0111; b = 4'b1000; op = 3'b001; check_result(4'b1111, 0, 0, 1, 1); // 7 - (-8) = 15 (signed overflow: a[3]!=b[3] and y[3]!=a[3])

        // AND tests (op=010)
        a = 4'b1010; b = 4'b1100; op = 3'b010; check_result(4'b1000, 0, 0, 0, 1);
        a = 4'b0101; b = 4'b1010; op = 3'b010; check_result(4'b0000, 1, 0, 0, 0);

        // OR tests (op=011)
        a = 4'b1010; b = 4'b0101; op = 3'b011; check_result(4'b1111, 0, 0, 0, 1);
        a = 4'b0000; b = 4'b0000; op = 3'b011; check_result(4'b0000, 1, 0, 0, 0);

        // XOR tests (op=100)
        a = 4'b1111; b = 4'b1111; op = 3'b100; check_result(4'b0000, 1, 0, 0, 0);
        a = 4'b1111; b = 4'b0000; op = 3'b100; check_result(4'b1111, 0, 0, 0, 1);

        // SHL tests (op=101)
        a = 4'b1011; b = 4'b0000; op = 3'b101; check_result(4'b0110, 0, 1, 0, 0); // shift left: y=0110, carry=a[3]=1
        a = 4'b0111; b = 4'b0000; op = 3'b101; check_result(4'b1110, 0, 0, 0, 1); // shift left: y=1110, carry=a[3]=0

        // SHR tests (op=110)
        a = 4'b1101; b = 4'b0000; op = 3'b110; check_result(4'b0110, 0, 1, 0, 0); // shift right: y=0110, carry=a[0]=1
        a = 4'b1010; b = 4'b0000; op = 3'b110; check_result(4'b0101, 0, 0, 0, 0); // shift right: y=0101, carry=a[0]=0

        // SLT tests (op=111)
        a = 4'b0010; b = 4'b0100; op = 3'b111; check_result(4'b0001, 0, 0, 0, 0); // 2 < 4 is true
        a = 4'b0100; b = 4'b0010; op = 3'b111; check_result(4'b0000, 1, 0, 0, 0); // 4 < 2 is false
        a = 4'b1111; b = 4'b0001; op = 3'b111; check_result(4'b0001, 0, 0, 0, 0); // -1 < 1 is true
        a = 4'b1000; b = 4'b1111; op = 3'b111; check_result(4'b0001, 0, 0, 0, 0); // -8 < -1 is true
        a = 4'b0111; b = 4'b1000; op = 3'b111; check_result(4'b0000, 1, 0, 0, 0); // 7 < -8 is false

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
```