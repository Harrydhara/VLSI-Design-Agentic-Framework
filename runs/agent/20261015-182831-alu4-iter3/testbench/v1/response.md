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
    integer i, j;
    reg [4:0] expected_sum;
    reg [3:0] expected_y;
    reg expected_carry;
    reg expected_overflow;
    reg expected_zero;
    reg expected_negative;
    
    integer passed;
    integer total;

    task check_result;
        begin
            expected_y = uut.y; // Just to make sure we capture current values
            // Re-calculate everything based on spec for comparison
            // Note: The task is called after inputs are applied, 
            // but since it's combinational, we check immediately.
            
            // We use local variables in the task to avoid race conditions with uut outputs
            // However, in a purely combinational TB, we just compare current values.
        end
    endtask

    initial begin
        passed = 0;
        total = 0;

        for (i = 0; i < 8; i = i + 1) begin // op
            for (j = 0; j < 16; j = j + 1) begin // a
                for (k = 0; k < 16; k = k + 1) begin // b (using k as loop index for b)
                    // Wait, I need to define k. Let's use nested loops properly.
                end
            end
        end
    end

    // Re-writing the test logic more cleanly
    initial begin
        passed = 0;
        total = 0;

        for (i = 0; i < 8; i = i + 1) begin // op
            for (j = 0; j < 16; j = j + 1) begin // a
                for (k = 0; k < 16; k = k + 1) begin // b
                    // We need to declare k in the scope. Let's use integer k.
                end
            end
        end
    end
endmodule
```

Wait, I must provide a single valid Verilog block. Let me rewrite the testbench correctly with proper loop variables and logic.

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

    integer i, j, k;
    reg [4:0] ref_sum;
    reg [3:0] ref_y;
    reg ref_carry;
    reg ref_overflow;
    reg ref_zero;
    reg ref_negative;

    initial begin
        passed = 0;
        total = 0;

        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                for (k = 0; k < 16; k = k + 1) begin
                    a = j;
                    b = k;
                    op = i;

                    // Reference Model calculation based on specification
                    ref_y = 4'b0;
                    ref_carry = 1'b0;
                    ref_overflow = 1'b0;

                    case (op)
                        3'b000: begin // ADD
                            ref_sum = a + b;
                            ref_y = ref_sum[3:0];
                            ref_carry = ref_sum[4];
                            ref_overflow = (a[3] == b[3]) && (ref_y[3] != a[3]);
                        end
                        3'b001: begin // SUB
                            // spec: carry is 1 exactly when a >= b as unsigned numbers
                            // y is low 4 bits of a - b. In Verilog, a - b for 4-bit handles this.
                            ref_y = a - b;
                            ref_carry = (a >= b);
                            // overflow: (a[3] != b[3]) && (y[3] != a[3])
                            ref_overflow = (a[3] != b[3]) && (ref_y[3] != a[3]);
                        end
                        3'b010: begin // AND
                            ref_y = a & b;
                            ref_carry = 1'b0;
                            ref_overflow = 1'b0;
                        end
                        3'b011: begin // OR
                            ref_y = a | b;
                            ref_carry = 1'b0;
                            ref_overflow = 1'b0;
                        end
                        3'b100: begin // XOR
                            ref_y = a ^ b;
                            ref_carry = 1'b0;
                            ref_overflow = 1'b0;
                        end
                        3'b101: begin // SHL
                            ref_y = a << 1;
                            ref_carry = a[3];
                            ref_overflow = 1'b0;
                        end
                        3'b110: begin // SHR
                            ref_y = a >> 1;
                            ref_carry = a[0];
                            ref_overflow = 1'b0;
                        end
                        3'b111: begin // SLT
                            // signed two's complement comparison
                            if ($signed(a) < $signed(b))
                                ref_y = 4'd1;
                            else
                                ref_y = 4'd0;
                            ref_carry = 1'b0;
                            ref_overflow = 1'b0;
                        end
                    endcase

                    ref_zero = (ref_y == 4'b0);
                    ref_negative = ref_y[3];

                    // Check outputs
                    total = total + 1;
                    if (y !== ref_y || zero !== ref_zero || carry !== ref_carry || overflow !== ref_overflow || negative !== ref_negative) begin
                        $display("FAIL: op=%b a=%b b=%b | expected y=%b z=%b c=%b o=%b n=%b, actual y=%b z=%b c=%b o=%b n=%b", 
                                 op, a, b, ref_y, ref_zero, ref_carry, ref_overflow, ref_negative,
                                 y, zero, carry, overflow, negative);
                    end else begin
                        passed = passed + 1;
                    end
                end
            end
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

    integer passed;
    integer total;

endmodule
```

Wait, I need to ensure the variable declarations are at the top and valid. Let me clean up the structure into a single coherent block as requested.

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

    integer i, j, k;
    reg [4:0] ref_sum;
    reg [3:0] ref_y;
    reg ref_carry;
    reg ref_overflow;
    reg ref_zero;
    reg ref_negative;
    integer passed;
    integer total;

    initial begin
        passed = 0;
        total = 0;

        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                for (k = 0; k < 16; k = k + 1) begin
                    a = j[3:0];
                    b = k[3:0];
                    op = i[2:0];

                    // Reference Model calculation based on specification
                    ref_carry = 0;
                    ref_overflow = 0;
                    ref_y = 4'b0;

                    case (op)
                        3'b000: begin // ADD
                            ref_sum = a + b;
                            ref_y = ref_sum[3:0];
                            ref_carry = ref_sum[4];
                            ref_overflow = (a[3] == b[3]) && (ref_y[3] != a[3]);
                        end
                        3'b001: begin // SUB
                            ref_y = a - b;
                            ref_carry = (a >= b);
                            ref_overflow = (a[3] != b[3]) && (ref_y[3] != a[3]);
                        end
                        3'b010: begin // AND
                            ref_y = a & b;
                        end
                        3'b011: begin // OR
                            ref_y = a | b;
                        end
                        3'b100: begin // XOR
                            ref_y = a ^ b;
                        end
                        3'b101: begin // SHL
                            ref_y = {a[2:0], 1'b0};
                            ref_carry = a[3];
                        end
                        3'b110: begin // SHR
                            ref_y = {1'b0, a[3:1]};
                            ref_carry = a[0];
                        end
                        3'b111: begin // SLT
                            if ($signed(a) < $signed(b))
                                ref_y = 4'd1;
                            else
                                ref_y = 4'd0;
                        end
                    endcase

                    ref_zero = (ref_y == 4'b0);
                    ref_negative = ref_y[3];

                    // Wait for combinational logic to settle (not strictly needed in sim, but good practice)
                    #1;

                    total = total + 1;
                    if (y !== ref_y || zero !== ref_zero || carry !== ref_carry || overflow !== ref_overflow || negative !== ref_negative) begin
                        $display("FAIL: op=%b a=%b b=%b | expected y=%b z=%b c=%b o=%b n=%b, actual y=%b z=%b c=%b o=%b n=%b", 
                                 op, a, b, ref_y, ref_zero, ref_carry, ref_overflow, ref_negative,
                                 y, zero, carry, overflow, negative);
                    end else begin
                        passed = passed + 1;
                    end
                end
            end
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
```