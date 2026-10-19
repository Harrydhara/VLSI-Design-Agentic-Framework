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

    // Helper for signed comparison (SLT)
    wire signed [3:0] a_s = {a[3], a};
    wire signed [3:0] b_s = {b[3], b};

    always @(*) begin
        // Default values to avoid latches
        y_reg = 4'b0;
        carry_reg = 1'b0;
        overflow_reg = 1'b0;

        case (op)
            3'b000: begin // ADD
                {carry_reg, y_reg} = a + b;
                // Overflow: same sign inputs result in different sign output
                if (a[3] == b[3] && y_reg[3] != a[3])
                    overflow_reg = 1'b1;
                else
                    overflow_reg = 1'b0;
            end

            3'b001: begin // SUB
                // Specification says carry is 1 when a >= b (no borrow)
                // In standard ALU terminology, "carry" for subtraction often means "not borrow".
                // The prompt specifies: "carry: 1 exactly when a >= b as unsigned numbers"
                if (a >= b) carry_reg = 1'b1;
                else        carry_reg = 1'b0;

                y_reg = a - b;
                // Overflow: different sign inputs result in different sign output
                // Note: subtraction is a + (-b). If signs of a and b are different, 
                // and the result sign differs from a, overflow occurred.
                if (a[3] != b[3] && y_reg[3] != a[3])
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

            3'b111: begin // SLT
                y_reg = (a_s < b_s) ? 4'd1 : 4'd0;
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
    assign zero = (y_reg == 4'b0);
    assign negative = y_reg[3];

endmodule
```

```verilog
module tb;
    reg [3:0] a, b;
    reg [2:0] op;
    wire [3:0] y;
    wire zero, carry, overflow, negative;

    // Reference model variables
    reg [3:0] m_y;
    reg       m_zero, m_carry, m_overflow, m_negative;

    integer passed, total;

    alu4 dut (
        .a(a), .b(b), .op(op),
        .y(y), .zero(zero), .carry(carry), .overflow(overflow), .negative(negative)
    );

    task check;
        begin
            total = total + 1;
            if (y === m_y && zero === m_zero && carry === m_carry && 
                overflow === m_overflow && negative === m_negative) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: a=%d b=%d op=%b | expected y=%d z=%b c=%b ov=%b n=%b | actual y=%d z=%b c=%b ov=%b n=%b",
                         a, b, op, m_y, m_zero, m_carry, m_overflow, m_negative,
                         y, zero, carry, overflow, negative);
            end
        end
    endtask

    // Reference model logic
    always @(*) begin
        m_y = 4'b0;
        m_carry = 1'b0;
        m_overflow = 1'b0;
        case (op)
            3'b000: begin // ADD
                {m_carry, m_y} = a + b;
                if (a[3] == b[3] && m_y[3] != a[3]) m_overflow = 1'b1;
            end
            3'b001: begin // SUB
                m_carry = (a >= b);
                m_y = a - b;
                if (a[3] != b[3] && m_y[3] != a[3]) m_overflow = 1'b1;
            end
            3'b010: m_y = a & b;
            3'b011: m_y = a | b;
            3'b100: m_y = a ^ b;
            3'b101: begin 
                m_y = {a[2:0], 1'b0}; 
                m_carry = a[3];
            end
            3'b110: begin 
                m_y = {1'b0, a[3:1]}; 
                m_carry = a[0];
            end
            3'b111: m_y = (($signed({a[3], a}) < $signed({b[3], b})) ? 4'd1 : 4'd0);
        endcase
        m_zero = (m_y == 4'b0);
        m_negative = m_y[3];
    end

    initial begin
        passed = 0;
        total = 0;

        // Test ADD
        op = 3'b000; a = 4'd5; b = 4'd2; #1; check; // 7, c=0, ov=0
        op = 3'b000; a = 4'd7; b = 4'd1; #1; check; // 8 (1000), c=0, ov=1 (7+1=8, sign change)
        op = 3'b000; a = 4'd15; b = 4'd1; #1; check; // 0, c=1, ov=0
        op = 3'b000; a = 4'd8; b = 4'd8; #1; check; // 0, c=1, ov=0 (8+8=16 -> 0)

        // Test SUB
        op = 3'b001; a = 4'd5; b = 4'd2; #1; check; // 3, c=1, ov=0
        op = 3'b001; a = 4'd2; b = 4'd5; #1; check; // 13 (1101), c=0, ov=0
        op = 3'b001; a = 4'd8; b = 4'd1; #1; check; // 7, c=1, ov=1 (signed: -8 - 1 = -9 -> overflow)
        op = 3'b001; a = 4'd0; b = 4'd0; #1; check; // 0, c=1, ov=0

        // Test AND/OR/XOR
        op = 3'b010; a = 4'b1010; b = 4'b1100; #1; check; // 1000 (8)
        op = 3'b011; a = 4'b1010; b = 4'b1100; #1; check; // 1110 (14)
        op = 3'b100; a = 4'b1010; b = 4'b1100; #1; check; // 0110 (6)

        // Test SHL/SHR
        op = 3'b101; a = 4'b1011; b = 4'd0; #1; check; // y=0110, c=1
        op = 3'b101; a = 4'b0111; b = 4'd0; #1; check; // y=1110, c=0
        op = 3'b110; a = 4'b1011; b = 4'd0; #1; check; // y=0101, c=1
        op = 3'b110; a = 4'b0111; b = 4'd0; #1; check; // y=0011, c=1

        // Test SLT (Signed)
        op = 3'b111; a = 4'd2; b = 4'd5; #1; check;  // 0
        op = 3'b111; a = 4'd5; b = 4'd2; #1; check;  // 0
        op = 3'b111; a = 4'b1111; b = 4'b0001; #1; check; // -1 < 1 -> 1
        op = 3'b111; a = 4'b0111; b = 4'b1000; #1; check; // 7 < -8 is false -> 0

        // Test Zero/Negative edge cases
        op = 3'b000; a = 4'd0; b = 4'd0; #1; check; // y=0, z=1, n=0
        op = 3'b000; a = 4'd8; b = 4'd0; #1; check; // y=8 (1000), z=0, n=1

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
```