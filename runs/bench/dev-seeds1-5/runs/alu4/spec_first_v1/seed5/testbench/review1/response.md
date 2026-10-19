```verilog
module tb;
    // Inputs
    reg [3:0] a;
    reg [3:0] b;
    reg [2:0] op;

    // Outputs
    wire [3:0] y;
    wire zero;
    wire carry;
    wire overflow;
    wire negative;

    // Instantiate the Unit Under Test (UUT)
    alu4 uut (
        .a(a),
        .b(b),
        .op(op),
        .y(y),
        .zero(zero),
        .carry(carry),
        .overflow(overflow),
        .negative(negative)
    );

    // Verification variables
    integer i, j, k;
    reg [3:0] exp_y;
    reg exp_zero;
    reg exp_carry;
    reg exp_overflow;
    reg exp_negative;
    integer passed;
    integer total;

    task check_result;
        begin
            exp_zero = (exp_y == 4'b0000);
            exp_negative = exp_y[3];
            
            if (y !== exp_y || zero !== exp_zero || carry !== exp_carry || overflow !== exp_overflow || negative !== exp_negative) begin
                $display("FAIL: a=%d, b=%d, op=%b | Expected: y=%d, z=%b, c=%b, v=%b, n=%b | Actual: y=%d, z=%b, c=%b, v=%b, n=%b",
                         a, b, op, exp_y, exp_zero, exp_carry, exp_overflow, exp_negative, y, zero, carry, overflow, negative);
            end else begin
                passed = passed + 1;
            end
            total = total + 1;
        end
    endtask

    initial begin
        passed = 0;
        total = 0;

        // Iterate through all possible input combinations
        for (i = 0; i < 8; i = i + 1) begin // op
            for (j = 0; j < 16; j = j + 1) begin // a
                for (k = 0; k < 16; k = k + 1) begin // b
                    a = j[3:0];
                    b = k[3:0];
                    op = i[2:0];

                    // Reference Model logic based on specification
                    case (op)
                        3'b000: begin // ADD
                            {exp_carry, exp_y} = a + b;
                            exp_overflow = (a[3] == b[3]) && (exp_y[3] != a[3]);
                        end
                        3'b001: begin // SUB
                            // Specification says carry is 1 when a >= b as unsigned numbers
                            exp_carry = (a >= b);
                            exp_y = a - b;
                            // Overflow for signed subtraction: (a[3] != b[3]) && (y[3] != a[3])
                            exp_overflow = (a[3] != b[3]) && (exp_y[3] != a[3]);
                        end
                        3'b010: begin // AND
                            exp_y = a & b;
                            exp_carry = 0;
                            exp_overflow = 0;
                        end
                        3'b011: begin // OR
                            exp_y = a | b;
                            exp_carry = 0;
                            exp_overflow = 0;
                        end
                        3'b100: begin // XOR
                            exp_y = a ^ b;
                            exp_carry = 0;
                            exp_overflow = 0;
                        end
                        3'b101: begin // SHL
                            exp_y = {a[2:0], 1'b0};
                            exp_carry = a[3];
                            exp_overflow = 0;
                        end
                        3'b110: begin // SHR
                            exp_y = {1'b0, a[3:1]};
                            exp_carry = a[0];
                            exp_overflow = 0;
                        end
                        3'b111: begin // SLT (Signed)
                            // Convert to signed 4-bit integers for comparison
                            if ($signed({1'b0, a}) < $signed({1'b0, b})) begin
                                // This is incorrect logic in the previous version. 
                                // The spec says "as signed two's complement numbers".
                                // In Verilog, to treat a 4-bit reg as signed:
                            end
                            // Correct way for 4-bit signed comparison:
                            if ($signed(a) < $signed(b)) exp_y = 4'd1;
                            else exp_y = 4'd0;
                            exp_carry = 0;
                            exp_overflow = 0;
                        end
                        default: begin
                            exp_y = 0; exp_carry = 0; exp_overflow = 0;
                        end
                    endcase

                    #1; // Wait for combinational logic to settle
                    check_result();
                end
            end
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```

Wait, I see the error in my previous thought process. The user provided failure logs where `a=0` and `b=8..15` resulted in `y=1`. 
In signed 4-bit:
`a = 0` is `0000` (decimal 0).
`b = 8` is `1000` (decimal -8).
Is `0 < -8`? No. So `y` should be `0`.
The failure log shows the design produced `y=1`, meaning the design thinks `0 < -8`. This means the design is likely treating them as unsigned or has a logic error, but my testbench *should* have expected `y=0`.

Looking at my previous code:
`if ($signed(a) < $signed(b)) exp_y = 4'd1;`
In Verilog, if `a` and `b` are declared as `reg [3:0]`, `$signed(a)` correctly performs sign-extension to the width of the expression.
For `a=0 (4'b0000)`, `$signed(a)` is `...0000`.
For `b=8 (4'b1000)`, `$signed(b)` is `...11111000` (-8).
Is `0 < -8`? No. So `exp_y` should be `0`.

The failure log says: 
`FAIL: a= 0, b= 8, op=111 | Expected: y= 0 ... | Actual: y= 1`
This means my testbench *did* expect `y=0`, and the design failed. My testbench was correct.

Wait, I must re-read the prompt instructions. "If your testbench is right, reply with exactly: TESTBENCH OK".

Let me double check the SLT logic one more time.
`a=0 (0000)`, `b=8 (1000)`. 
Signed values: `a=0`, `b=-8`.
`0 < -8` is False. Expected `y=0`.
The log says: `Expected: y= 0 ... Actual: y= 1`.
This confirms the design is wrong and my testbench correctly identified it.

TESTBENCH OK