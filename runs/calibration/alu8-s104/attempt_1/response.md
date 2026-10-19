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

    // Internal wires for arithmetic calculations to handle carry/overflow easily
    wire [8:0] sum_add = a + b;
    wire [8:0] diff_sub = a - b; // This is actually (a - b) in 9-bit math
    // For SUB, we need unsigned comparison for carry and signed logic for overflow.
    // Let's use standard subtraction logic.
    
    always @(*) begin
        // Default values to prevent latches
        y_reg = 8'b0;
        carry_reg = 1'b0;
        overflow_reg = 1'b0;

        case (op)
            3'b000: begin // AND
                y_reg = a & b;
                carry_reg = 1'b0;
                overflow_reg = 1'b0;
            end
            3'b001: begin // OR
                y_reg = a | b;
                carry_reg = 1'b0;
                overflow_reg = 1'b0;
            end
            3'b010: begin // XOR
                y_reg = a ^ b;
                carry_reg = 1'b0;
                overflow_reg = 1'b0;
            end
            3'b011: begin // ADD
                y_reg = sum_add[7:0];
                carry_reg = sum_add[8];
                // Overflow: same sign inputs, different sign result
                if (a[7] == b[7] && y_reg[7] != a[7])
                    overflow_reg = 1'b1;
                else
                    overflow_reg = 1'b0;
            end
            3'b100: begin // SUB
                y_reg = a - b;
                // Carry: 1 when a >= b (unsigned), else 0
                carry_reg = (a >= b) ? 1'b1 : 1'b0;
                // Overflow: different sign inputs, result sign differs from 'a'
                if (a[7] != b[7] && y_reg[7] != a[7])
                    overflow_reg = 1'b1;
                else
                    overflow_reg = 1'b0;
            end
            3'b101: begin // SRA (Arithmetic Shift Right)
                y_reg = {a[7], a[7:1]};
                carry_reg = a[0];
                overflow_reg = 1'b0;
            end
            3'b110: begin // ROL (Rotate Left)
                y_reg = {a[6:0], a[7]};
                carry_reg = a[7];
                overflow_reg = 1'b0;
            end
            3'b111: begin // SLT (Set Less Than - Signed)
                // Compare signed values. In Verilog, $signed(a) < $signed(b) works.
                if ($signed(a) < $signed(b))
                    y_reg = 8'd1;
                else
                    y_reg = 8'd0;
                carry_reg = 1'b0;
                overflow_reg = 1'b0;
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

    integer i, j;
    integer passed, total;

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

    task check_result;
        input [7:0] exp_y;
        input exp_z;
        input exp_c;
        input exp_v;
        input exp_n;
        begin
            total = total + 1;
            if (y !== exp_y || zero !== exp_z || carry !== exp_c || overflow !== exp_v || negative !== exp_n) begin
                $display("FAIL: op=%b a=%d b=%d | Exp: y=%d z=%b c=%b v=%b n=%b | Got: y=%d z=%b c=%b v=%b n=%b", 
                         op, a, b, exp_y, exp_z, exp_c, exp_v, exp_n, y, zero, carry, overflow, negative);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        passed = 0;
        total = 0;

        // Test AND
        op = 3'b000; a = 8'hAA; b = 8'h55; check_result(8'h00, 1, 0, 0, 0);
        op = 3'b000; a = 8'hFF; b = 8'h0F; check_result(8'h0F, 0, 0, 0, 0);

        // Test OR
        op = 3'b001; a = 8'hAA; b = 8'h55; check_result(8'hFF, 0, 0, 0, 1);
        op = 3'b001; a = 8'h00; b = 8'h00; check_result(8'h00, 1, 0, 0, 0);

        // Test XOR
        op = 3'b010; a = 8'hAA; b = 8'h55; check_result(8'hFF, 0, 0, 0, 1);
        op = 3'b010; a = 8'hAA; b = 8'hAA; check_result(8'h00, 1, 0, 0, 0);

        // Test ADD
        op = 3'b011; a = 8'd10; b = 8'd20; check_result(8'd30, 0, 0, 0, 0);
        op = 3'b011; a = 8'hFF; b = 8'h01; check_result(8'h00, 1, 1, 0, 0); // Carry out
        op = 3'b011; a = 8'h7F; b = 8'h01; check_result(8'h80, 0, 0, 1, 1); // Overflow (pos+pos=neg)
        op = 3'b011; a = 8'h80; b = 8'h80; check_result(8'h00, 1, 1, 1, 0); // Overflow (neg+neg=pos)

        // Test SUB
        op = 3'b100; a = 8'd20; b = 8'd10; check_result(8'd10, 0, 1, 0, 0); // Carry (a>=b)
        op = 3'b100; a = 8'd10; b = 8'd20; check_result(8'hF6, 0, 0, 0, 1); // Carry (a<b), result is -10
        op = 3'b100; a = 8'h7F; b = 8'h80; check_result(8'hFF, 0, 0, 1, 1); // Overflow (pos-neg=neg)
        op = 3'b100; a = 8'h80; b = 8'h7F; check_result(8'h01, 0, 1, 1, 0); // Overflow (neg-pos=pos)

        // Test SRA
        op = 3'b101; a = 8'b1000_0011; b = 8'd0; check_result(8'b1100_0001, 0, 1, 0, 1); // SRA: bit7 stays, carry=a[0]
        op = 3'b101; a = 8'b0100_0010; b = 8'd0; check_result(8'b0010_0001, 0, 0, 0, 0); // SRA: bit7 stays

        // Test ROL
        op = 3'b110; a = 8'b1000_0011; b = 8'd0; check_result(8'b0000_0111, 0, 1, 0, 0); // ROL: bit7 to bit0
        op = 3'b110; a = 8'b0100_0011; b = 8'd0; check_result(8'b1000_0110, 0, 0, 0, 1); // ROL: bit7 to bit0

        // Test SLT
        op = 3'b111; a = 8'd5; b = 8'd10; check_result(8'd1, 0, 0, 0, 0); // 5 < 10
        op = 3'b111; a = 8'd10; b = 8'd5; check_result(8'd0, 1, 0, 0, 0); // 10 < 5 is false
        op = 3'b111; a = -8'd5; b = 8'd5; check_result(8'd1, 0, 0, 0, 0); // -5 < 5
        op = 3'b111; a = 8'd5; b = -8'd5; check_result(8'd0, 1, 0, 0, 0); // 5 < -5 is false

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
```