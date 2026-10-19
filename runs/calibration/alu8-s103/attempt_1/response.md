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

    // Internal wires for arithmetic to handle carry/overflow easily
    wire [8:0] sum_add = a + b;
    wire [8:0] diff_sub = a - b; // This is actually 2's complement subtraction logic
    // For SUB, we need a-b. In Verilog, a-b for 8 bits is fine, but let's be explicit.
    // To get carry/borrow correctly for unsigned:
    // Carry out of ADD is sum_add[8].
    // Carry (no borrow) for SUB: if a >= b, carry = 1.

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
                if (a[7] == b[7]) begin
                    if (sum_add[7] != a[7])
                        overflow_reg = 1'b1;
                    else
                        overflow_reg = 1'b0;
                end else begin
                    overflow_reg = 1'b0;
                end
            end
            3'b100: begin // SUB
                y_reg = a - b;
                // Carry: 1 if a >= b (unsigned), else 0
                carry_reg = (a >= b) ? 1'b1 : 1'b0;
                // Overflow: different sign inputs, result sign differs from 'a'
                if (a[7] != b[7]) begin
                    if (y_reg[7] != a[7])
                        overflow_reg = 1'b1;
                    else
                        overflow_reg = 1'b0;
                end else begin
                    overflow_reg = 1'b0;
                end
            end
            3'b101: begin // SRA (Arithmetic shift right)
                y_reg = {a[7], a[7:1]};
                carry_reg = a[0];
                overflow_reg = 1'b0;
            end
            3'b110: begin // ROL (Rotate left)
                y_reg = {a[6:0], a[7]};
                carry_reg = a[7];
                overflow_reg = 1'b0;
            end
            3'b111: begin // SLT (Set Less Than signed)
                // Compare as signed. If a < b, y = 1, else 0.
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

    integer i;
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

    task check(input [7:0] exp_y, input exp_z, input exp_c, input exp_v, input exp_n);
        begin
            total = total + 1;
            if (y !== exp_y || zero !== exp_z || carry !== exp_c || overflow !== exp_v || negative !== exp_n) begin
                $display("FAIL: a=%d b=%d op=%b | Exp: y=%d z=%b c=%b v=%b n=%b | Got: y=%d z=%b c=%b v=%b n=%b", 
                         a, b, op, exp_y, exp_z, exp_c, exp_v, exp_n, y, zero, carry, overflow, negative);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        passed = 0;
        total = 0;

        // AND
        a = 8'hAA; b = 8'h55; op = 3'b000; #1; check(8'h00, 1, 0, 0, 0);
        a = 8'hFF; b = 8'h0F; op = 3'b000; #1; check(8'h0F, 0, 0, 0, 0);

        // OR
        a = 8'hAA; b = 8'h55; op = 3'b001; #1; check(8'hFF, 0, 0, 0, 1);
        a = 8'hF0; b = 8'h0F; op = 3'b001; #1; check(8'hFF, 0, 0, 0, 1);

        // XOR
        a = 8'hAA; b = 8'h55; op = 3'b010; #1; check(8'hFF, 0, 0, 0, 1);
        a = 8'hAA; b = 8'hAA; op = 3'b010; #1; check(8'h00, 1, 0, 0, 0);

        // ADD
        a = 8'd10; b = 8'd20; op = 3'b011; #1; check(8'd30, 0, 0, 0, 0);
        a = 8'hFF; b = 8'h01; op = 3'b011; #1; check(8'h00, 1, 1, 0, 0); // Carry out
        a = 8'h7F; b = 8'h01; op = 3'b011; #1; check(8'h80, 0, 0, 1, 1); // Signed Overflow (pos+pos=neg)
        a = 8'h80; b = 8'h80; op = 3'b011; #1; check(8'h00, 1, 1, 0, 0); // neg+neg=zero (no overflow)
        a = 8'h81; b = 8'h7F; op = 3'b011; #1; check(8'h00, 1, 0, 0, 0); // neg+pos=zero (not possible, but checking logic)
        // Re-check signed overflow: a=127, b=1 -> y=-128. a[7]=0, b[7]=0, y[7]=1. Overflow!
        a = 8'd127; b = 8'd1; op = 3'b011; #1; check(8'h80, 0, 0, 1, 1);

        // SUB
        a = 8'd50; b = 8'd20; op = 3'b100; #1; check(8'd30, 0, 1, 0, 0); // a >= b (carry=1)
        a = 8'd20; b = 8'd50; op = 3'b100; #1; check(8'd226, 0, 0, 0, 1); // a < b (carry=0), y is unsigned 226
        a = 8'h80; b = 8'h01; op = 3'b100; #1; check(8'h7F, 0, 0, 1, 0); // signed overflow: neg - pos = pos
        a = 8'h7F; b = 8'h80; op = 3'b100; #1; check(8'hFF, 0, 0, 1, 1); // signed overflow: pos - neg = neg

        // SRA
        a = 8'b1000_0011; b = 0; op = 3'b101; #1; check(8'b1100_0001, 0, 1, 0, 1); // bit 7 kept, carry is a[0]
        a = 8'b0111_1111; b = 0; op = 3'b101; #1; check(8'b0011_1111, 0, 1, 0, 0); // bit 7 kept (0), carry is a[0]

        // ROL
        a = 8'b1000_0001; b = 0; op = 3'b110; #1; check(8'b0000_0011, 0, 1, 0, 0); // bit 7 to bit 0
        a = 8'b0111_1111; b = 0; op = 3'b110; #1; check(8'b1111_1110, 0, 0, 0, 1); // bit 7 to bit 0

        // SLT
        a = 8'd5; b = 8'd10; op = 3'b111; #1; check(8'd1, 0, 0, 0, 0); // 5 < 10
        a = 8'd10; b = 8'd5; op = 3'b111; #1; check(8'd0, 1, 0, 0, 0); // 10 < 5 is false
        a = -8'd5; b = 8'd2; op = 3'b111; #1; check(8'd1, 0, 0, 0, 0); // -5 < 2
        a = 8'd127; b = -8'd1; op = 3'b111; #1; check(8'd0, 1, 0, 0, 0); // 127 < -1 is false

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
```