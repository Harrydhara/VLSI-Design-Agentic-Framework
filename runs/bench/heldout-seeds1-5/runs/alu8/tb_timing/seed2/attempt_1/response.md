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
                {carry_reg, y_reg} = a + b;
                // Overflow: same sign inputs, different sign result
                if (a[7] == b[7] && y_reg[7] != a[7])
                    overflow_reg = 1'b1;
                else
                    overflow_reg = 1'b0;
            end
            3'b100: begin // SUB
                y_reg = a - b;
                // Carry for SUB: 1 if a >= b (unsigned), else 0
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
            3'b111: begin // SLT (Set Less Than - signed)
                // Cast to signed 9-bit to handle comparison correctly if needed, 
                // but standard Verilog $signed handles it.
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
    assign zero = (y_reg == 8'b0);
    assign carry = carry_reg;
    assign overflow = overflow_reg;
    assign negative = y_reg[7];

endmodule
```

```verilog
module tb;
    reg [7:0] a, b;
    reg [2:0] op;
    wire [7:0] y;
    wire zero, carry, overflow, negative;

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

    reg [7:0] m_y;
    reg m_zero, m_carry, m_overflow, m_negative;

    task check;
        begin
            total = total + 1;
            if (y === m_y && zero === m_zero && carry === m_carry && overflow === m_overflow && negative === m_negative) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: a=%d b=%d op=%b | expected y=%d z=%b c=%b o=%b n=%b, actual y=%d z=%b c=%b o=%b n=%b",
                         a, b, op, m_y, m_zero, m_carry, m_overflow, m_negative, 
                         y, zero, carry, overflow, negative);
            end
        end
    endtask

    // Reference model logic
    always @(*) begin
        case (op)
            3'b000: begin m_y = a & b; m_carry = 0; m_overflow = 0; end
            3'b001: begin m_y = a | b; m_carry = 0; m_overflow = 0; end
            3'b010: begin m_y = a ^ b; m_carry = 0; m_overflow = 0; end
            3'b011: begin 
                {m_carry, m_y} = a + b;
                m_overflow = (a[7] == b[7] && m_y[7] != a[7]) ? 1 : 0;
            end
            3'b100: begin 
                m_y = a - b;
                m_carry = (a >= b) ? 1 : 0;
                m_overflow = (a[7] != b[7] && m_y[7] != a[7]) ? 1 : 0;
            end
            3'b101: begin m_y = {a[7], a[7:1]}; m_carry = a[0]; m_overflow = 0; end
            3'b110: begin m_y = {a[6:0], a[7]}; m_carry = a[7]; m_overflow = 0; end
            3'b111: begin m_y = ($signed(a) < $signed(b)) ? 8'd1 : 8'd0; m_carry = 0; m_overflow = 0; end
            default: begin m_y = 0; m_carry = 0; m_overflow = 0; end
        endcase
        m_zero = (m_y == 0);
        m_negative = m_y[7];
    end

    initial begin
        passed = 0;
        total = 0;

        // Test AND
        a = 8'hAA; b = 8'h55; op = 3'b000; #1; check; // y=0, z=1
        a = 8'hFF; b = 8'h0F; op = 3'b000; #1; check; // y=0x0F

        // Test OR
        a = 8'hAA; b = 8'h55; op = 3'b001; #1; check; // y=FF
        a = 8'h0F; b = 8'hF0; op = 3'b001; #1; check; // y=FF

        // Test XOR
        a = 8'hAA; b = 8'h55; op = 3'b010; #1; check; // y=FF
        a = 8'hFF; b = 8'hFF; op = 3'b010; #1; check; // y=0, z=1

        // Test ADD
        a = 8'h01; b = 8'h02; op = 3'b011; #1; check; // y=3, c=0
        a = 8'hFF; b = 8'h01; op = 3'b011; #1; check; // y=0, z=1, c=1
        a = 8'h7F; b = 8'h01; op = 3'b011; #1; check; // y=80 (signed overflow), o=1
        a = 8'h80; b = 8'h80; op = 3'b011; #1; check; // y=0, z=1, c=1, o=0

        // Test SUB
        a = 8'h05; b = 8'h02; op = 3'b100; #1; check; // y=3, c=1
        a = 8'h02; b = 8'h05; op = 3'b100; #1; check; // y=FD (signed -3), c=0
        a = 8'h80; b = 8'h01; op = 3'b100; #1; check; // y=7F, o=1 (neg-pos=pos)
        a = 8'h7F; b = 8'h80; op = 3'b100; #1; check; // y=FF, o=1 (pos-neg=neg)

        // Test SRA
        a = 8'b1000_0011; b = 0; op = 3'b101; #1; check; // y=1100_0001, c=1 (bit 0)
        a = 8'b0100_0000; b = 0; op = 3'b101; #1; check; // y=0010_0000, c=0

        // Test ROL
        a = 8'b1000_0001; b = 0; op = 3'b110; #1; check; // y=0000_0011 (wait: bit 7 to bit 0), y=0000_0011? No.
        // ROL a[6:0], a[7]. If a=10000001, y=00000011. Correct.
        a = 8'b1000_0001; op = 3'b110; #1; check; // y=00000011, c=1 (bit 7)
        a = 8'b0100_0001; op = 3'b110; #1; check; // y=10000010, c=0

        // Test SLT
        a = 8'd5; b = 8'd10; op = 3'b111; #1; check; // y=1
        a = 8'd10; b = 8'd5; op = 3'b111; #1; check; // y=0
        a = -8'd5; b = 8'd5; op = 3'b111; #1; check; // y=1 (signed)
        a = 8'd5; b = -8'd5; op = 3'b111; #1; check; // y=0

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
```