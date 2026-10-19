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

    wire [4:0] sum_add = a + b;
    wire [4:0] sub_res = a - b; // 5-bit to handle borrow/unsigned logic

    always @(*) begin
        // Default values
        y_reg = 4'b0000;
        carry_reg = 1'b0;
        overflow_reg = 1'b0;

        case (op)
            3'b000: begin // ADD
                y_reg = sum_add[3:0];
                carry_reg = sum_add[4];
                // Overflow for signed addition: same sign inputs, different sign result
                overflow_reg = (a[3] == b[3]) && (y_reg[3] != a[3]);
            end
            3'b001: begin // SUB
                y_reg = sum_add[3:0]; // Using subtraction logic via addition/subtraction rules
                // The spec says carry is 1 when a >= b (unsigned)
                // In 4-bit unsigned, a - b results in no borrow if a >= b.
                // However, the prompt asks for "carry" to be 1 exactly when a >= b.
                carry_reg = (a >= b);
                // Overflow: (a[3] != b[3]) && (y[3] != a[3])
                // Note: subtraction is a + (-b). Signed overflow occurs if signs of a and b are different 
                // and the result sign differs from a.
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
            3'b111: begin // SLT (Signed Less Than)
                // Signed comparison: if a < b then 1 else 0
                if ($signed(a) < $signed(b))
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

    // Re-calculating SUB y correctly because sum_add was used for both.
    // Let's fix the logic inside the case to be cleaner.
    // Redefining the block below using a more robust approach.
endmodule
```

Wait, I noticed a mistake in my scratchpad logic (using `sum_add` for SUB). Let me rewrite the full design correctly within one block.

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

    reg [3:0] y_out;
    reg       c_out;
    reg       v_out;

    always @(*) begin
        y_out = 4'b0;
        c_out = 1'b0;
        v_out = 1'b0;
        case (op)
            3'b000: begin // ADD
                y_out = a + b;
                c_out = ((a[3] == 1 && b[3] == 1 && y_out[3] == 0) || (a[3] == 0 && b[3] == 0 && y_out[3] == 1)) ? 0 : 0; // placeholder
                // Correct Carry: bit 4 of a+b
                c_out = (a + b > 4'hF);
                // Correct Overflow: (a[3]==b[3]) && (y[3]!=a[3])
                v_out = (a[3] == b[3]) && (y_out[3] != a[3]);
            end
            3'b001: begin // SUB
                y_out = a - b;
                c_out = (a >= b);
                v_out = (a[3] != b[3]) && (y_out[3] != a[3]);
            end
            3'b010: begin // AND
                y_out = a & b;
            end
            3'b011: begin // OR
                y_out = a | b;
            end
            3'b100: begin // XOR
                y_out = a ^ b;
            end
            3'b101: begin // SHL
                y_out = {a[2:0], 1'b0};
                c_out = a[3];
            end
            3'b110: begin // SHR
                y_out = {1'b0, a[3:1]};
                c_out = a[0];
            end
            3'b111: begin // SLT
                if ($signed(a) < $signed(b)) y_out = 4'h1;
                else y_out = 4'h0;
            end
        endcase
    end

    assign y = y_out;
    assign carry = c_out;
    assign overflow = v_out;
    assign zero = (y == 4'b0);
    assign negative = y[3];

endmodule
```

Actually, I will provide the final clean version.

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
        y_reg = 4'b0;
        carry_reg = 1'b0;
        overflow_reg = 1'b0;
        case (op)
            3'b000: begin // ADD
                {carry_reg, y_reg} = a + b;
                if ((a[3] == b[3]) && (y_reg[3] != a[3])) 
                    overflow_reg = 1'b1;
            end
            3'b001: begin // SUB
                y_reg = a - b;
                carry_reg = (a >= b);
                if ((a[3] != b[3]) && (y_reg[3] != a[3])) 
                    overflow_reg = 1'b1;
            end
            3'b010: begin // AND
                y_reg = a & b;
            end
            3'b011: begin // OR
                y_reg = a | b;
            end
            3'b100: begin // XOR
                y_reg = a ^ b;
            end
            3'b101: begin // SHL
                y_reg = {a[2:0], 1'b0};
                carry_reg = a[3];
            end
            3'b110: begin // SHR
                y_reg = {1'b0, a[3:1]};
                carry_reg = a[0];
            end
            3'b111: begin // SLT
                if ($signed(a) < $signed(b)) y_reg = 4'h1;
                else y_reg = 4'h0;
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

Final check on SUB: "carry is 1 exactly when a >= b as unsigned numbers". My code `carry_reg = (a >= b)` does this.
Overflow for SUB: "(a[3] != b[3]) && (y[3] != a[3])". My code does this.

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
        y_reg = 4'b0;
        carry_reg = 1'b0;
        overflow_reg = 1'b0;
        case (op)
            3'b000: begin // ADD
                {carry_reg, y_reg} = a + b;
                if ((a[3] == b[3]) && (y_reg[3] != a[3])) 
                    overflow_reg = 1'b1;
            end
            3'b001: begin // SUB
                y_reg = a - b;
                carry_reg = (a >= b);
                if ((a[3] != b[3]) && (y_reg[3] != a[3])) 
                    overflow_reg = 1'b1;
            end
            3'b010: begin // AND
                y_reg = a & b;
            end
            3'b011: begin // OR
                y_reg = a | b;
            end
            3'b100: begin // XOR
                y_reg = a ^ b;
            end
            3'b101: begin // SHL
                y_reg = {a[2:0], 1'b0};
                carry_reg = a[3];
            end
            3'b110: begin // SHR
                y_reg = {1'b0, a[3:1]};
                carry_reg = a[0];
            end
            3'b111: begin // SLT
                if ($signed(a) < $signed(b)) y_reg = 4'h1;
                else y_reg = 4'h0;
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

Wait, one detail: `a + b` in Verilog for 4-bit operands results in a 4-bit value. To get the carry bit (the 5th bit), I must use a wider temporary variable or concatenation. `{carry_reg, y_reg} = a + b;` works because it expands the RHS to 5 bits before assigning.

Final check on SUB overflow:
If a=7 (0111) and b=-8 (1000), then a-b = 7 - (-8) = 15 (1111).
a[3]=0, b[3]=1. y[3]=1.
(a[3] != b[3]) is true. (y[3] != a[3]) is (1 != 0) which is true. Overflow = 1. Correct.

Final check on SUB carry:
If a=5, b=2. a >= b is true. Carry = 1.
If a=2, b=5. a >= b is false. Carry = 0.
Matches "carry is 1 exactly when a >= b".

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
        y_reg = 4'b0;
        carry_reg = 1'b0;
        overflow_reg = 1'b0;
        case (op)
            3'b000: begin // ADD
                {carry_reg, y_reg} = a + b;
                if ((a[3] == b[3]) && (y_reg[3] != a[3])) 
                    overflow_reg = 1'b1;
            end
            3'b001: begin // SUB
                y_reg = a - b;
                carry_reg = (a >= b);
                if ((a[3] != b[3]) && (y_reg[3] != a[3])) 
                    overflow_reg = 1'b1;
            end
            3'b010: begin // AND
                y_reg = a & b;
            end
            3'b011: begin // OR
                y_reg = a | b;
            end
            3'b100: begin // XOR
                y_reg = a ^ b;
            end
            3'b101: begin // SHL
                y_reg = {a[2:0], 1'b0};
                carry_reg = a[3];
            end
            3'b110: begin // SHR
                y_reg = {1'b0, a[3:1]};
                carry_reg = a[0];
            end
            3'b111: begin // SLT
                if ($signed(a) < $signed(b)) y_reg = 4'h1;
                else y_reg = 4'h0;
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

One more thing: `a + b` in `{carry_reg, y_reg} = a + b;` might be interpreted as 4-bit addition if the compiler is strict. To ensure 5-bit addition, I'll use a temporary 5-bit wire.

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
    wire [4:0] sum_5bit;

    assign sum_5bit = a + b;

    always @(*) begin
        y_reg = 4'b0;
        carry_reg = 1'b0;
        overflow_reg = 1'b0;
        case (op)
            3'b000: begin // ADD
                y_reg = sum_5bit[3:0];
                carry_reg = sum_5bit[4];
                if ((a[3] == b[3]) && (y_reg[3] != a[3])) 
                    overflow_reg = 1'b1;
            end
            3'b001: begin // SUB
                y_reg = a - b;
                carry_reg = (a >=