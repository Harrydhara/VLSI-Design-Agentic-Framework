```verilog
module alu8(
    input  [7:0] a,
    input  [7:0] b,
    input  [2:0] op,
    output [7:0] y,
    output       zero,
    output       carry,
    output       overflow,
    output       negative
);

    reg [7:0] y_reg;
    reg       carry_reg;
    reg       overflow_reg;

    // Intermediate signals for arithmetic
    wire [8:0] sum = a + b;
    wire [8:0] diff = a - b;
    
    // Signed comparison (SLT)
    // To compare signed 8-bit, we extend to 9 bits to handle sign bit correctly
    wire [8:0] sa = {a[7], a};
    wire [8:0] sb = {b[7], b};

    always @(*) begin
        // Default values
        y_reg = 8'b0;
        carry_reg = 1'b0;
        overflow_reg = 1'b0;

        case (op)
            3'b000: begin // AND
                y_reg = a & b;
            end
            3'b001: begin // OR
                y_reg = a | b;
            end
            3'b010: begin // XOR
                y_reg = a ^ b;
            end
            3'b011: begin // ADD
                y_reg = sum[7:0];
                carry_reg = sum[8];
                // Overflow: same sign inputs, different sign result
                if (a[7] == b[7] && y_reg[7] != a[7])
                    overflow_reg = 1'b1;
                else
                    overflow_reg = 1'b0;
            end
            3'b100: begin // SUB
                y_reg = diff[7:0];
                // Carry (no borrow): a >= b unsigned
                carry_reg = (a >= b);
                // Overflow: different sign inputs, result sign differs from 'a'
                if (a[7] != b[7] && y_reg[7] != a[7])
                    overflow_reg = 1'b1;
                else
                    overflow_reg = 1'b0;
            end
            3'b101: begin // SRA (Arithmetic Shift Right)
                y_reg = {a[7], a[7:1]};
                carry_reg = a[0];
            end
            3'b110: begin // ROL (Rotate Left)
                y_reg = {a[6:0], a[7]};
                carry_reg = a[7];
            end
            3'b111: begin // SLT (Set Less Than signed)
                y_reg = (sa < sb) ? 8'd1 : 8'd0;
            end
            default: begin
                y_reg = 8'b0;
                carry_reg = 1'b0;
                overflow_reg = 1'b0;
            end
        endcase
    end

    assign y = y_reg;
    assign zero = (y == 8'b0);
    assign carry = carry_reg;
    assign overflow = overflow_reg;
    assign negative = y[7];

endmodule
```

```verilog
module tb;
    reg [7:0] a, b;
    reg [2:0] op;
    wire [7:0] y;
    wire zero, carry, overflow, negative;

    integer i, j, passed, total;

    alu8 dut (
        .a(a),
        .b(b),
        .op(op),
        .y(y),
        .zero(zero),
        .carry(carry),
        .overflow(overflow),
        .negative(negative)
    );

    task check(input [7:0] exp_y, input exp_z, input exp_c, input exp_o, input exp_n);
        begin
            total = total + 1;
            if (y !== exp_y || zero !== exp_z || carry !== exp_c || overflow !== exp_o || negative !== exp_n) begin
                $display("FAIL: a=%d b=%d op=%b | Exp: y=%d z=%b c=%b o=%b n=%b | Got: y=%d z=%b c=%b o=%b n=%b", 
                         a, b, op, exp_y, exp_z, exp_c, exp_o, exp_n, y, zero, carry, overflow, negative);
                passed = passed - 1;
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        passed = 0;
        total = 0;

        // AND
        op = 3'b000; a = 8'hAA; b = 8'h55; check(8'h00, 1, 0, 0, 0);
        op = 3'b000; a = 8'hFF; b = 8'h0F; check(8'h0F, 0, 0, 0, 0);

        // OR
        op = 3'b001; a = 8'hAA; b = 8'h55; check(8'hFF, 0, 0, 0, 1);
        op = 3'b001; a = 8'h00; b = 8'h00; check(8'h00, 1, 0, 0, 0);

        // XOR
        op = 3'b010; a = 8'hAA; b = 8'h55; check(8'hFF, 0, 0, 0, 1);
        op = 3'b010; a = 8'hAA; b = 8'hAA; check(8'h00, 1, 0, 0, 0);

        // ADD
        op = 3'b011; a = 8'd10; b = 8'd20; check(8'd30, 0, 0, 0, 0);
        op = 3'b011; a = 8'hFF; b = 8'h01; check(8'h00, 1, 1, 0, 0); // Carry out
        op = 3'b011; a = 8'h7F; b = 8'h01; check(8'h80, 0, 0, 1, 1); // Signed Overflow (pos+pos=neg)
        op = 3'b011; a = 8'h80; b = 8'h80; check(8'h00, 1, 1, 0, 0); // Carry out, no overflow (neg+neg=pos is wrong logic? No: -128 + -128 = -256. In 8bit: 0. Sign bit of a/b is 1. Result sign is 0. Overflow!)
        // Re-check ADD overflow rule: same sign inputs, result sign differs.
        // a=8'h80 (neg), b=8'h80 (neg). sum = 8'h100. y = 8'h00 (pos). Sign changed from neg to pos. Overflow = 1.
        op = 3'b011; a = 8'h80; b = 8'h80; check(8'h00, 1, 1, 1, 0);

        // SUB
        op = 3'b100; a = 8'd20; b = 8'd10; check(8'd10, 0, 1, 0, 0); // Carry (no borrow)
        op = 3'b100; a = 8'd10; b = 8'd20; check(8'd246, 0, 0, 0, 1); // Unsigned: 10-20 = -10 (246). Carry=0.
        op = 3'b100; a = 8'h7F; b = 8'h80; check(8'hFF, 0, 0, 1, 1); // Signed Overflow: pos - neg = neg (7F - 80 = FF). Sign changed from pos to neg.
        op = 3'b100; a = 8'h80; b = 8'h7F; check(8'h01, 0, 1, 1, 0); // Signed Overflow: neg - pos = pos (80 - 7F = 01). Sign changed from neg to pos.

        // SRA
        op = 3'b101; a = 8'b1000_0011; b = 8'h00; check(8'b1100_0001, 0, 1, 0, 1); // Arithmetic shift: bit 7 stays. Carry is bit 0.
        op = 3'b101; a = 8'b0100_0000; b = 8'h00; check(8'b0010_0000, 0, 0, 0, 0);

        // ROL
        op = 3'b110; a = 8'b1000_0011; b = 8'h00; check(8'b0000_0111, 0, 1, 0, 0); // Bit 7 moves to bit 0. Carry is bit 7.
        op = 3'b110; a = 8'b0100_0000; b = 8'h00; check(8'b1000_0000, 0, 0, 0, 1);

        // SLT
        op = 3'b111; a = 8'd5; b = 8'd10; check(8'd1, 0, 0, 0, 0); // 5 < 10
        op = 3'b111; a = 8'd10; b = 8'd5; check(8'd0, 1, 0, 0, 0); // 10 < 5 is false
        op = 3'b111; a = -8'd5; b = 8'd5; check(8'd1, 0, 0, 0, 0); // -5 < 5
        op = 3'b111; a = 8'd5; b = -8'd5; check(8'd0, 1, 0, 0, 0); // 5 < -5 is false
        op = 3'b111; a = -8'd5; b = -8'd10; check(8'd0, 1, 0, 0, 0); // -5 < -10 is false

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```