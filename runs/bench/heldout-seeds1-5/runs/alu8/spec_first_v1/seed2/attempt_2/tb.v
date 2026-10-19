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
            
            // Reference Model Calculation - Completely independent of DUT outputs
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
                    // Use 9-bit math to find carry and result
                    // Specification: "carry: bit 8 of the 9-bit sum a + b"
                    if ({1'b0, a} + {1'b0, b} > 9'hFF) begin
                        ref_carry = 1;
                    end else begin
                        ref_carry = 0;
                    end
                    ref_y = a + b;
                    // Overflow: same sign bit of a and b, but result sign differs
                    if (a[7] == b[7] && ref_y[7] != a[7])
                        ref_overflow = 1;
                    else
                        ref_overflow = 0;
                end
                3'b100: begin // SUB
                    // Specification: "carry: 1 exactly when a >= b as unsigned numbers"
                    if (a >= b) ref_carry = 1;
                    else        ref_carry = 0;
                    
                    ref_y = a - b;
                    // Overflow: different sign bits of a and b, but result sign differs from a
                    if (a[7] != b[7] && ref_y[7] != a[7])
                        ref_overflow = 1;
                    else
                        ref_overflow = 0;
                end
                3'b101: begin // SRA
                    // Arithmetic shift right: bit 7 keeps its value
                    ref_y = {a[7], a[7:1]};
                    ref_carry = a[0];
                    ref_overflow = 0;
                end
                3'b110: begin // ROL
                    // Rotate left: bit 7 moves to bit 0
                    ref_y = {a[6:0], a[7]};
                    ref_carry = a[7];
                    ref_overflow = 0;
                end
                3'b111: begin // SLT
                    // Signed comparison
                    if ($signed(a) < $signed(b)) ref_y = 8'd1;
                    else                         ref_y = 8'd0;
                    ref_carry = 0;
                    ref_overflow = 0;
                end
                default: begin
                    ref_y = 8'h00; ref_carry = 0; ref_overflow = 0;
                end
            endcase

            ref_zero     = (ref_y == 8'b0);
            ref_negative = ref_y[7];

            // Comparison - Check against DUT outputs
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
        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
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
