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
        y_reg       = 4'b0;
        carry_reg   = 1'b0;
        overflow_reg = 1'b0;

        case (op)
            3'b000: begin // ADD
                {carry_reg, y_reg} = a + b;
                // Overflow: same sign inputs result in different sign output
                overflow_reg = (a[3] == b[3]) && (y_reg[3] != a[3]);
            end
            3'b001: begin // SUB
                // Specification says carry is 1 when a >= b (no borrow)
                // In standard ALU terms, "carry" for subtraction often means "not borrow".
                // We follow the prompt: carry = 1 if a >= b.
                if (a >= b) begin
                    y_reg = a - b;
                    carry_reg = 1'b1;
                end else begin
                    y_reg = a - b;
                    carry_reg = 1'b0;
                end
                // Overflow: different sign inputs result in different sign output (relative to 'a')
                // Wait, the prompt says: (a[3] != b[3]) && (y[3] != a[3]). Let's follow exactly.
                overflow_reg = (a[3] != b[3]) && (y_reg[3] != a[3]);
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

    assign y        = y_reg;
    assign carry    = carry_reg;
    assign overflow = overflow_reg;
    assign zero     = (y_reg == 4'b0);
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
        .a(a), .b(b), .op(op),
        .y(y), .zero(zero), .carry(carry), .overflow(overflow), .negative(negative)
    );

    // Reference model
    reg [3:0] m_y;
    reg       m_zero, m_carry, m_overflow, m_negative;

    task check;
        begin
            total = total + 1;
            if (y === m_y && zero === m_zero && carry === m_carry && overflow === m_overflow && negative === m_negative) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: a=%d b=%d op=%d | expected y=%d z=%b c=%b o=%b n=%b, actual y=%d z=%b c=%b o=%b n=%b",
                         a, b, op, m_y, m_zero, m_carry, m_overflow, m_negative, 
                         y, zero, carry, overflow, negative);
            end
        end
    endtask

    // Update model based on spec logic
    always @(*) begin
        m_y = 0; m_carry = 0; m_overflow = 0;
        case (op)
            3'b000: begin // ADD
                {m_carry, m_y} = a + b;
                m_overflow = (a[3] == b[3]) && (m_y[3] != a[3]);
            end
            3'b001: begin // SUB
                m_y = a - b;
                m_carry = (a >= b);
                m_overflow = (a[3] != b[3]) && (m_y[3] != a[3]);
            end
            3'b010: begin m_y = a & b; end // AND
            3'b011: begin m_y = a | b; end // OR
            3'b100: begin m_y = a ^ b; end // XOR
            3'b101: begin m_y = {a[2:0], 1'b0}; m_carry = a[3]; end // SHL
            3'b110: begin m_y = {1'b0, a[3:1]}; m_carry = a[0]; end // SHR
            3'b111: begin 
                if ({a[3],a} < {b[3],b}) m_y = 4'd1; else m_y = 4'd0;
            end
        endcase
        m_zero = (m_y == 0);
        m_negative = m_y[3];
    end

    initial begin
        passed = 0; total = 0;
        a = 0; b = 0; op = 0;
        #1; // Wait for combinational settling

        // TEST ADD
        op = 3'b000; a = 4'd5;  b = 4'd2;  #1; check; // 7, c=0, o=0
        op = 3'b000; a = 4'd10; b = 4'd7;  #1; check; // 1 (17), c=1, o=1 (signed: -6 + 7 = 1)
        op = 3'b000; a = 4'd15; b = 4'd1;  #1; check; // 0, c=1, o=0
        op = 3'b000; a = 4'd7;  b = 4'd8;  #1; check; // 15, c=0, o=0

        // TEST SUB
        op = 3'b001; a = 4'd10; b = 4'd4;  #1; check; // 6, c=1, o=0
        op = 3'b001; a = 4'd4;  b = 4'd10; #1; check; // -6 (10), c=0, o=1 (signed: 4 - (-6) = 10? No. 4-10=-6. a[3]=0, b[3]=1. y[3]=1. (0!=1)&&(1!=0)=T)
        op = 3'b001; a = 4'd5;  b = 4'd5;  #1; check; // 0, c=1, o=0

        // TEST AND/OR/XOR
        op = 3'b010; a = 4'b1010; b = 4'b1100; #1; check; // 1000 (8)
        op = 3'b011; a = 4'b1010; b = 4'b1100; #1; check; // 1110 (14)
        op = 3'b100; a = 4'b1010; b = 4'b1100; #1; check; // 0110 (6)

        // TEST SHL/SHR
        op = 3'b101; a = 4'b1011; b = 0;      #1; check; // 0110, c=1
        op = 3'b101; a = 4'b0111; b = 0;      #1; check; // 1110, c=0
        op = 3'b110; a = 4'b1011; b = 0;      #1; check; // 0101, c=1
        op = 3'b110; a = 4'b0111; b = 0;      #1; check; // 0011, c=1

        // TEST SLT (Signed)
        op = 3'b111; a = 4'd2;  b = 4'd3;  #1; check; // 1
        op = 3'b111; a = 4'd3;  b = 4'd2;  #1; check; // 0
        op = 3'b111; a = 4'b1111; b = 4'b0001; #1; check; // -1 < 1 -> 1
        op = 3'b111; a = 4'b0001; b = 4'b1111; #1; check; // 1 < -1 -> 0

        // TEST ZERO/NEGATIVE
        op = 3'b010; a = 4'd0;  b = 4'd0;  #1; check; // y=0, z=1, n=0
        op = 3'b000; a = 4'b1000; b = 4'b0000; #1; check; // y=8 (1000), z=0, n=1

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
```