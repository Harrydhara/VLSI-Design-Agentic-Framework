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
                // carry is 1 exactly when a >= b (no borrow)
                carry_reg = (a >= b);
                y_reg = a - b;
                // overflow for signed subtraction: (a[3] != b[3]) && (y[3] != a[3])
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
        a = 4'h7; b = 4'h8; check(4'hF, 0, 0, 1, 1);

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
        a = 4'h7; b = 4'h8; check(4'h0, 1, 0, 0, 0);
        a = 4'hF; b = 4'h0; check(4'h1, 0, 0, 0, 0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
```