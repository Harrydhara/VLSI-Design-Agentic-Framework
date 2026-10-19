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
                // Specification says carry is 1 when a >= b (no borrow)
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

    task check_result;
        input [3:0] exp_y;
        input exp_z;
        input exp_c;
        input exp_o;
        input exp_n;
        begin
            total = total + 1;
            if (y !== exp_y || zero !== exp_z || carry !== exp_c || overflow !== exp_o || negative !== exp_n) begin
                $display("FAIL: op=%b a=%b b=%b | Expected: y=%b z=%b c=%b o=%b n=%b | Actual: y=%b z=%b c=%b o=%b n=%b", 
                         op, a, b, exp_y, exp_z, exp_c, exp_o, exp_n, y, zero, carry, overflow, negative);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        passed = 0;
        total = 0;

        // ADD tests
        op = 3'b000; a = 4'd5; b = 4'd2; check_result(4'd7, 0, 0, 0, 0); // 5+2=7
        op = 3'b000; a = 4'd10; b = 4'd7; check_result(4'd1, 0, 1, 0, 0); // 10+7=17 (y=1, c=1)
        op = 3'b000; a = 4'b0111; b = 4'b0001; check_result(4'b1000, 0, 0, 1, 1); // 7+1=8 (signed overflow)
        op = 3'b000; a = 4'b1000; b = 4'b1111; check_result(4'b0111, 0, 1, 1, 0); // -8 + -1 = -9 (y=7, c=1, overflow)

        // SUB tests
        op = 3'b001; a = 4'd5; b = 4'd2; check_result(4'd3, 0, 1, 0, 0); // 5-2=3 (c=1 because 5>=2)
        op = 3'b001; a = 4'd2; b = 4'd5; check_result(4'd13, 0, 0, 0, 1); // 2-5=-3 (y=13, c=0 because 2<5)
        op = 3'b001; a = 4'b0111; b = 4'b1000; check_result(4'b1001, 0, 0, 1, 1); // 7 - (-8) = 15 (overflow)
        op = 3'b001; a = 4'b1000; b = 4'b0111; check_result(4'b0001, 0, 1, 1, 0); // -8 - 7 = -15 (overflow)

        // AND tests
        op = 3'b010; a = 4'b1010; b = 4'b1100; check_result(4'b1000, 0, 0, 0, 1);
        op = 3'b010; a = 4'b0101; b = 4'b1010; check_result(4'b0000, 1, 0, 0, 0);

        // OR tests
        op = 3'b011; a = 4'b1010; b = 4'b0101; check_result(4'b1111, 0, 0, 0, 1);
        op = 3'b011; a = 4'b0000; b = 4'b0000; check_result(4'b0000, 1, 0, 0, 0);

        // XOR tests
        op = 3'b100; a = 4'b1010; b = 4'b1100; check_result(4'b0110, 0, 0, 0, 0);
        op = 3'b100; a = 4'b1111; b = 4'b1111; check_result(4'b0000, 1, 0, 0, 0);

        // SHL tests
        op = 3'b101; a = 4'b1011; b = 4'd0; check_result(4'b0110, 0, 1, 0, 0); // shift out 1
        op = 3'b101; a = 4'b0101; b = 4'd0; check_result(4'b1010, 0, 0, 0, 1); // shift out 0

        // SHR tests
        op = 3'b110; a = 4'b1011; b = 4'd0; check_result(4'b0101, 0, 1, 0, 0); // shift out 1
        op = 3'b110; a = 4'b1100; b = 4'd0; check_result(4'b0110, 0, 0, 0, 0); // shift out 0

        // SLT tests
        op = 3'b111; a = 4'b0001; b = 4'b0010; check_result(4'b0001, 0, 0, 0, 0); // 1 < 2 (true)
        op = 3'b111; a = 4'b1111; b = 4'b0001; check_result(4'b0000, 1, 0, 0, 0); // -1 < 1 (false)
        op = 3'b111; a = 4'b1000; b = 4'b1111; check_result(4'b0001, 0, 0, 0, 0); // -8 < -1 (true)
        op = 3'b111; a = 4'b0000; b = 4'b0000; check_result(4'b0000, 1, 0, 0, 0); // 0 < 0 (false)

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```