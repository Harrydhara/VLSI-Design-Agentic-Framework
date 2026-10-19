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

    task check_result;
        input [7:0] a_in;
        input [7:0] b_in;
        input [2:0] op_in;
        input [7:0] exp_y;
        input       exp_carry;
        input       exp_overflow;
        begin
            reg [7:0] act_y;
            reg act_zero, act_carry, act_overflow, act_negative;
            
            act_y = y;
            act_zero = zero;
            act_carry = carry;
            act_overflow = overflow;
            act_negative = negative;

            total = total + 1;

            if (act_y !== exp_y || act_zero !== (exp_y == 8'b0) || 
                act_carry !== exp_carry || act_overflow !== exp_overflow || 
                act_negative !== exp_y[7]) begin
                $display("FAIL: op=%b a=%d b=%d | exp: y=%d z=%b c=%b v=%b n=%b | act: y=%d z=%b c=%b v=%b n=%b",
                         op_in, a_in, b_in, exp_y, (exp_y==0), exp_carry, exp_overflow, exp_y[7],
                         act_y, act_zero, act_carry, act_overflow, act_negative);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        passed = 0;
        total = 0;

        // Test all combinations of op and a wide range of a, b
        // To keep simulation time reasonable but thorough, we test specific patterns and randoms
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 256; j = j + 1) begin
                // We use a subset of b to ensure coverage without infinite loops
                // But for an ALU, testing all a and b is feasible: 8 * 256 * 256 = 524,288 iterations.
                // Let's do a more targeted approach or just run the full loop if time permits.
                // For this task, we will iterate through all combinations of op, a, and b.
            end
        end

        // Re-structured: Full exhaustive test for 8-bit ALU is 2^3 * 2^8 * 2^8 = 524,288 tests.
        // This is well within limits for Verilog simulation.
        for (i = 0; i < 8; i = i + 1) begin // op
            for (j = 0; j < 256; j = j + 1) begin // a
                for (begin // b loop
                    // We'll use a nested loop structure for clarity
                end
                // Actually, let's just write the loops properly.
                end
            end
        end

        // Corrected Loop Structure
        for (i = 0; i < 8; i = i + 1) begin // op
            op = i[2:0];
            for (j = 0; j < 256; j = j + 1) begin // a
                a = j[7:0];
                // We will test all b for every op and a to be exhaustive.
                // To prevent the code from being too long, we use a loop for b inside.
            end
        end
    end

    // Since I cannot write nested loops easily in an 'initial' block without complexity, 
    // let's define the logic clearly.
    
    initial begin
        passed = 0;
        total = 0;
        
        for (i = 0; i < 8; i = i + 1) begin
            op = i[2:0];
            for (j = 0; j < 256; j = j + 1) begin
                a = j[7:0];
                // To keep it efficient for the testbench runner, we'll sample b.
                // However, specification implies correctness across all inputs.
                // Let's use a loop for b.
                for (begin // This is just a placeholder for logic flow
                end
            end
        end
    end
endmodule
```

Wait, I need to provide the *actual* working testbench code. Let me rewrite it properly following all rules.

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

    integer i, j, k;
    integer passed;
    integer total;
    
    reg [7:0] exp_y;
    reg       exp_carry;
    reg       exp_overflow;
    reg       exp_zero;
    reg       exp_negative;

    initial begin
        passed = 0;
        total = 0;

        for (i = 0; i < 8; i = i + 1) begin
            op = i[2:0];
            for (j = 0; j < 256; j = j + 1) begin
                a = j[7:0];
                for (k = 0; k < 256; k = k + 1) begin
                    b = k[7:0];

                    // Reference Model
                    exp_y = 8'b0;
                    exp_carry = 1'b0;
                    exp_overflow = 1'b0;

                    case (op)
                        3'b000: begin // AND
                            exp_y = a & b;
                        end
                        3'b001: begin // OR
                            exp_y = a | b;
                        end
                        3'b010: begin // XOR
                            exp_y = a ^ b;
                        end
                        3'b011: begin // ADD
                            {exp_carry, exp_y} = a + b;
                        end
                        3'b100: begin // SUB
                            // carry: 1 when a >= b (unsigned), else 0
                            // y: a - b (low 8 bits)
                            exp_y = a - b;
                            if (a >= b) exp_carry = 1'b1;
                            else        exp_carry = 1'b0;
                            
                            // overflow: 1 when signs of a and b are different AND y sign differs from a
                            // Note: spec says "a and b have different sign bits" for SUB.
                            if (a[7] != b[7] && exp_y[7] != a[7])
                                exp_overflow = 1'b1;
                        end
                        3'b101: begin // SRA
                            // Arithmetic right shift by 1
                            exp_y = {a[7], a[7:1]};
                            exp_carry = a[0];
                        end
                        3'b110: begin // ROL
                            // Rotate left by 1
                            exp_y = {a[6:0], a[7]};
                            exp_carry = a[7];
                        end
                        3'b111: begin // SLT
                            // Signed comparison
                            if ($signed(a) < $signed(b))
                                exp_y = 8'd1;
                            else
                                exp_y = 8'd0;
                        end
                    endcase

                    // Special Overflow for ADD (not covered in case above)
                    if (op == 3'b011) begin
                        if (a[7] == b[7] && exp_y[7] != a[7])
                            exp_overflow = 1'b1;
                        else
                            exp_overflow = 1'b0;
                    end

                    // Special Overflow for other ops is already 0 by initialization
                    if (op != 3'b011 && op != 3'b100) begin
                        exp_overflow = 1'b0;
                    end

                    exp_zero = (exp_y == 8'b0);
                    exp_negative = exp_y[7];

                    // Wait for combinational logic to settle
                    #1;

                    total = total + 1;
                    if (y !== exp_y || zero !== exp_zero || carry !== exp_carry || 
                        overflow !== exp_overflow || negative !== exp_negative) begin
                        $display("FAIL: op=%b a=%d b=%d | exp: y=%d z=%b c=%b v=%b n=%b | act: y=%d z=%b c=%b v=%b n=%b",
                                 op, a, b, exp_y, exp_zero, exp_carry, exp_overflow, exp_negative,
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