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

        // Test all combinations of op and a/b is too large (256*256*8), 
        // so we test specific patterns and corner cases.

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
            b = 8'hFF; op = 3'b011; check_alu(); // Carry test
            b = 8'h01; op = 3'b011; check_alu(); // Basic add
            a = 8'h7F; b = 8'h01; op = 3'b011; check_alu(); // Overflow pos
            a = 8'h80; b = 8'h80; op = 3'b011; check_alu(); // Overflow neg
        end

        // SUB tests (including borrow and overflow)
        for (i = 0; i < 256; i = i + 1) begin
            a = i;
            b = 8'h00; op = 3'b100; check_alu(); // Carry test (a>=b)
            b = 8'hFF; op = 3'b100; check_alu(); // Borrow test (a<b)
            a = 8'h7F; b = 8'h80; op = 3'b100; check_alu(); // Overflow sub
            a = 8'h80; b = 8'h7F; op = 3'b100; check_alu(); // Overflow sub
        end

        // SRA tests
        for (i = 0; i < 256; i = i + 1) begin
            a = i; b = 8'h00; op = 3'b101; check_alu();
            a = ~i; b = 8'h00; op = 3'b101; check_alu(); // Check sign extension
        end

        // ROL tests
        for (i = 0; i < 256; i = i + 1) begin
            a = i; b = 8'h00; op = 3'b110; check_alu();
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
        op = 3'b000; a = 8'hAA; b = 8'hAA; check_alu(); // y!=0, neg=1 (if AA is neg)
        a = 8'h80; b = 8'h00; op = 3'b000; check_alu(); // y=80, neg=1

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```