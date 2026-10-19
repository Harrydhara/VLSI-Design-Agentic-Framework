The failing checks show `act: y=xx z=x c=x o=x n=x`. In Verilog, `x` (unknown) values appearing as outputs for a combinational circuit typically indicate that the inputs to the design were not properly driven or that there is no assignment to those wires in the design.

Looking at my testbench code:
The inputs `a`, `b`, and `op` are assigned inside an `initial` block, but they are assigned *immediately* before calling `check_alu()`. Since the ALU is combinational, the outputs should respond immediately. However, I am using a task to perform the check.

In Verilog, when you assign a value to a `reg` and then immediately call a task that reads the `wire` outputs of the UUT, there is no time delay between the assignment and the reading. In many simulators, if the assignments are not followed by a small delay (like `#1`), the combinational logic might not have "settled" or the simulator may not have propagated the new input values to the output wires before the task reads them, leading to `x` values being read from the outputs.

However, looking at the specific failures:
`FAIL: op=000 a=00 b=00 | exp: y=00 z=1 c=0 o=0 n=0 | act: y=xx z=x c=x o=x n=x`
The expected values are calculated correctly based on the spec:
- `op=000 (AND)`: `a & b = 0 & 0 = 0`. `zero = 1`, `carry = 0`, `overflow = 0`, `negative = 0`. My testbench matches this.

The issue is that my testbench does not provide a small timing delay after driving inputs to allow the combinational logic to propagate, which causes the simulator to report `x` for the outputs during the check. While the design might be correct, the testbench fails to observe it correctly.

I will add `#1;` after each input change to ensure the combinational logic settles before checking.

1. All expected values in the failing checks match the specification:
- `op=000 (AND) a=0 b=0`: `y = 0 & 0 = 0`. Spec: "AND a & b". My `exp: y=00 z=1 c=0 o=0 n=0` matches.
- `op=001 (OR) a=0 b=1`: `y = 0 | 1 = 1`. Spec: "OR a | b". My `exp: y=01 z=0 c=0 o=0 n=0` matches.
- `op=010 (XOR) a=0 b=2`: `y = 0 ^ 2 = 2`. Spec: "XOR a ^ b". My `exp: y=02 z=0 c=0 o=0 n=0` matches.

TESTBENCH OK.

```verilog
module tb;
    // Inputs
    reg [7:0] a;
    reg [7:0] b;
    reg [2:0] op;

    // Outputs
    wire [7:0] y;
    wire zero;
    wire carry;
    wire overflow;
    wire negative;

    // Instantiate the Unit Under Test (UUT)
    alu8 uut (
        .a(a),
        .b(b),
        .op(op),
        .y(y),
        .zero(zero),
        .carry(carry),
        .overflow(overflow),
        .negative(negative)
    );

    // Reference Model and Verification Logic
    integer i, j;
    integer passed;
    integer total;

    reg [7:0] ref_y;
    reg ref_zero;
    reg ref_carry;
    reg ref_overflow;
    reg ref_negative;

    task check_alu;
        begin
            // Wait for combinational logic to settle
            #1;
            total = total + 1;
            
            // Reference Model Calculation
            case (op)
                3'b000: begin // AND
                    ref_y = a & b;
                    ref_carry = 0;
                    ref_overflow = 0;
                end
                3'b001: begin // OR
                    ref_y = a | b;
                    ref_carry = 0;
                    ref_overflow = 0;
                end
                3'b010: begin // XOR
                    ref_y = a ^ b;
                    ref_carry = 0;
                    ref_overflow = 0;
                end
                3'b011: begin // ADD
                    ref_y = a + b;
                    ref_carry = (a + b > 8'hFF);
                    // Overflow: same sign inputs, different result sign
                    if (a[7] == b[7] && y[7] != a[7]) 
                        ref_overflow = 1;
                    else 
                        ref_overflow = 0;
                end
                3'b100: begin // SUB
                    ref_y = a - b;
                    // Carry: 1 if no borrow (a >= b unsigned)
                    ref_carry = (a >= b);
                    // Overflow: different sign inputs, result sign differs from 'a'
                    if (a[7] != b[7] && y[7] != a[7])
                        ref_overflow = 1;
                    else
                        ref_overflow = 0;
                end
                3'b101: begin // SRA
                    ref_y = {a[7], a[7:1]};
                    ref_carry = a[0];
                    ref_overflow = 0;
                end
                3'b110: begin // ROL
                    ref_y = {a[6:0], a[7]};
                    ref_carry = a[7];
                    ref_overflow = 0;
                end
                3'b111: begin // SLT (Signed)
                    if ($signed(a) < $signed(b)) ref_y = 8'd1;
                    else ref_y = 8'd0;
                    ref_carry = 0;
                    ref_overflow = 0;
                end
                default: begin
                    ref_y = 0; ref_carry = 0; ref_overflow = 0;
                end
            endcase

            ref_zero     = (ref_y == 8'b0);
            ref_negative = ref_y[7];

            // Comparison
            if (y !== ref_y || zero !== ref_zero || carry !== ref_carry || 
                overflow !== ref_overflow || negative !== ref_negative) begin
                $display("FAIL: op=%b a=%h b=%h | exp: y=%h z=%b c=%b o=%b n=%b | act: y=%h z=%b c=%b o=%b n=%b", 
                         op, a, b, ref_y, ref_zero, ref_carry, ref_overflow, ref_negative,
                         y, zero, carry, overflow, negative);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        passed = 0;
        total = 0;

        // AND, OR, XOR tests
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                op = 3'b000; a = i; b = j; check_alu();
                op = 3'b001; a = i; b = j; check_alu();
                op = 3'b010; a = i; b = j; check_alu();
            end
        end

        // ADD tests (including overflow and carry)
        for (i = 0; i < 256; i = i + 1) begin
            a = i;
            op = 3'b011; b = 8'hFF; check_alu(); // Carry test
            b = 8'h01; check_alu(); // Basic add
            a = 8'h7F; b = 8'h01; check_alu(); // Overflow pos
            a = 8'h80; b = 8'h80; check_alu(); // Overflow neg
        end

        // SUB tests (including borrow and overflow)
        for (i = 0; i < 256; i = i + 1) begin
            a = i;
            op = 3'b100; b = 8'h00; check_alu(); // Carry test (a>=b)
            b = 8'hFF; check_alu(); // Borrow test (a<b)
            a = 8'h7F; b = 8'h80; check_alu(); // Overflow sub
            a = 8'h80; b = 8'h7F; check_alu(); // Overflow sub
        end

        // SRA tests
        for (i = 0; i < 256; i = i + 1) begin
            op = 3'b101; a = i; b = 8'h00; check_alu();
            a = ~i; b = 8'h00; check_alu(); // Check sign extension
        end

        // ROL tests
        for (i = 0; i < 256; i = i + 1) begin
            op = 3'b110; a = i; b = 8'h00; check_alu();
        end

        // SLT tests (Signed comparison)
        op = 3'b111;
        a = 8'h7F; b = 8'h80; check_alu(); // 127 < -128 is false
        a = 8'h80; b = 8'h7F; check_alu(); // -128 < 127 is true
        a = 8'h05; b = 8'h0A; check_alu(); // 5 < 10 is true
        a = 8'h0A; b = 8'h05; check_alu(); // 10 < 5 is false
        a = 8'hFF; b = 8'h01; check_alu(); // -1 < 1 is true
        a = 8'h00; b = 8'h00; check_alu(); // 0 < 0 is false

        // Zero and Negative tests
        op = 3'b000; a = 8'hAA; b = 8'h55; check_alu(); // y=0, zero=1
        a = 8'hAA; b = 8'hAA; check_alu(); // y!=0, neg=1 (if AA is neg)
        a = 8'h80; b = 8'h00; op = 3'b000; check_alu(); // y=80, neg=1

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```