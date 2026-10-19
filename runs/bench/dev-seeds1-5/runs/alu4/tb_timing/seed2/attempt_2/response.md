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
        y_reg = 4'b0;
        carry_reg = 1'b0;
        overflow_reg = 1'b0;

        case (op)
            3'b000: begin // ADD
                {carry_reg, y_reg} = a + b;
                if (a[3] == b[3])
                    overflow_reg = (y_reg[3] != a[3]);
                else
                    overflow_reg = 1'b0;
            end

            3'b001: begin // SUB
                carry_reg = (a >= b);
                y_reg = a - b;
                if (a[3] != b[3])
                    overflow_reg = (y_reg[3] != a[3]);
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

            3'b111: begin // SLT
                if ({a[3], a} < {b[3], b})
                    y_reg = 4'b0001;
                else
                    y_reg = 4'b0000;
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

    alu4 dut (
        .a(a), .b(b), .op(op),
        .y(y), .zero(zero), .carry(carry), .overflow(overflow), .negative(negative)
    );

    integer passed, total;

    reg [3:0] m_y;
    reg       m_zero, m_carry, m_overflow, m_negative;

    task check;
        begin
            total = total + 1;
            if (y === m_y && zero === m_zero && carry === m_carry && overflow === m_overflow && negative === m_negative) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: a=%d b=%d op=%b | expected y=%b z=%b c=%b o=%b n=%b, actual y=%b z=%b c=%b o=%b n=%b",
                         a, b, op, m_y, m_zero, m_carry, m_overflow, m_negative, 
                         y, zero, carry, overflow, negative);
            end
        end
    endtask

    // Reference model logic
    always @(*) begin
        m_y = 4'b0; m_zero = 1'b0; m_carry = 1'b0; m_overflow = 1'b0; m_negative = 1'b0;
        case (op)
            3'b000: begin // ADD
                {m_carry, m_y} = a + b;
                if (a[3] == b[3]) m_overflow = (m_y[3] != a[3]);
            end
            3'b001: begin // SUB
                m_carry = (a >= b);
                m_y = a - b;
                if (a[3] != b[3]) m_overflow = (m_y[3] != a[3]);
            end
            3'b010: m_y = a & b;
            3'b011: m_y = a | b;
            3'b100: m_y = a ^ b;
            3'b101: begin m_y = {a[2:0], 1'b0}; m_carry = a[3]; end
            3'b110: begin m_y = {1'b0, a[3:1]}; m_carry = a[0]; end
            3'b111: begin 
                if ({a[3], a} < {b[3], b}) m_y = 4'd1;
                else m_y = 4'd0;
            end
        endcase
        m_zero = (m_y == 4'b0);
        m_negative = m_y[3];
    end

    initial begin
        passed = 0; total = 0;
        
        // Test ADD
        a = 4'd5; b = 4'd2; op = 3'b000; #1 check;
        a = 4'd8; b = 4'd8; op = 3'b000; #1 check;
        a = 4'd7; b = 4'd1; op = 3'b000; #1 check;
        a = 4'd4; b = 4'd4; op = 3'b000; #1 check;

        // Test SUB
        a = 4'd5; b = 4'd2; op = 3'b001; #1 check;
        a = 4'd2; b = 4'd5; op = 3'b001; #1 check;
        a = 4'd7; b = 4'd8; op = 3'b001; #1 check;
        a = 4'd8; b = 4'd0; op = 3'b001; #1 check;

        // Test AND/OR/XOR
        a = 4'b1010; b = 4'b1100; op = 3'b010; #1 check;
        a = 4'b1010; b = 4'b1100; op = 3'b011; #1 check;
        a = 4'b1010; b = 4'b1100; op = 3'b100; #1 check;

        // Test SHL/SHR
        a = 4'b1011; op = 3'b101; #1 check;
        a = 4'b0011; op = 3'b101; #1 check;
        a = 4'b1011; op = 3'b110; #1 check;
        a = 4'b0011; op = 3'b110; #1 check;

        // Test SLT
        a = 4'd2; b = 4'd5; op = 3'b111; #1 check;
        a = 4'd5; b = 4'd2; op = 3'b111; #1 check;
        a = 4'b1111; b = 4'b0001; op = 3'b111; #1 check; // -1 < 1
        a = 4'b1011; b = 4'b1101; op = 3'b111; #1 check; // -5 < -3

        // Test Zero and Negative flags specifically
        a = 4'd0; b = 4'd0; op = 3'b010; #1 check;
        a = 4'd8; b = 4'd0; op = 3'b010; #1 check;

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
```