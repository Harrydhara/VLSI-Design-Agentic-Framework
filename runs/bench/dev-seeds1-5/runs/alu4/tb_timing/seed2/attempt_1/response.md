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
        // Default values to prevent latches
        y_reg = 4'b0;
        carry_reg = 1'b0;
        overflow_reg = 1'b0;

        case (op)
            3'b000: begin // ADD
                {carry_reg, y_reg} = a + b;
                // Overflow for signed addition: same sign inputs result in different sign output
                if (a[3] == b[3])
                    overflow_reg = (y_reg[3] != a[3]);
                else
                    overflow_reg = 1'b0;
            end

            3'b001: begin // SUB
                // Specification says carry is 1 when a >= b as unsigned numbers
                carry_reg = (a >= b);
                y_reg = a - b;
                // Overflow for signed subtraction: different sign inputs result in different sign output
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

            3'b111: begin // SLT (Set Less Than)
                y_reg = (a_s < b_s) ? 4'b0001 : 4'b0000;
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

    // Reference model for the ALU logic
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

    // Update model based on inputs
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
            3'b111: begin m_y = (($signed({a[3],a}) < $signed({b[3],b})) ? 4'd1 : 4'd0); end
        endcase
        m_zero = (m_y == 0);
        m_negative = m_y[3];
    end

    initial begin
        passed = 0; total = 0;
        
        // Test ADD
        a = 4'd5; b = 4'd2; op = 3'b000; #1 check; // y=7, c=0, o=0
        a = 4'd8; b = 4'd8; op = 3'b000; #1 check; // y=0, c=1, o=0 (unsigned 16)
        a = 4'd7; b = 4'd1; op = 3'b000; #1 check; // y=8, c=0, o=1 (signed: 7+1=8, sign change)
        a = 4'd4; b = 4'd4; op = 3'b000; #1 check; // y=8, c=0, o=1

        // Test SUB
        a = 4'd5; b = 4'd2; op = 3'b001; #1 check; // y=3, c=1, o=0
        a = 4'd2; b = 4'd5; op = 3'b001; #1 check; // y=13 (signed -3), c=0, o=0
        a = 4'd7; b = 4'd8; op = 3'b001; #1 check; // y=15 (signed -1), c=0, o=1 (7-8=-1, sign change)
        a = 4'd8; b = 4'd0; op = 3'b001; #1 check; // y=8, c=1, o=0

        // Test AND/OR/XOR
        a = 4'b1010; b = 4'b1100; op = 3'b010; #1 check; // AND: 1000
        a = 4'b1010; b = 4'b1100; op = 3'b011; #1 check; // OR:  1110
        a = 4'b1010; b = 4'b1100; op = 3'b100; #1 check; // XOR: 0110

        // Test SHL/SHR
        a = 4'b1011; op = 3'b101; #1 check; // SHL: y=0110, c=1
        a = 4'b0011; op = 3'b101; #1 check; // SHL: y=0110, c=0
        a = 4'b1011; op = 3'b110; #1 check; // SHR: y=0101, c=1
        a = 4'b0011; op = 3'b110; #1 check; // SHR: y=0001, c=1

        // Test SLT
        a = 4'd2; b = 4'd5; op = 3'b111; #1 check; // 2 < 5 -> 1
        a = 4'd5; b = 4'd2; op = 3'b111; #1 check; // 5 < 2 -> 0
        a = 4'd-1; b = 4'd1; op = 3'b111; #1 check; // -1 < 1 -> 1 (signed)
        a = 4'd-5; b = 4'd-2; op = 3'b111; #1 check; // -5 < -2 -> 1

        // Test Zero and Negative flags specifically
        a = 4'd0; b = 4'd0; op = 3'b010; #1 check; // y=0, zero=1, neg=0
        a = 4'd8; b = 4'd0; op = 3'b010; #1 check; // y=8, zero=0, neg=1

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
```