module tb;
    reg [7:0] a, b;
    reg [2:0] op;
    wire [7:0] y;
    wire zero, carry, overflow, negative;

    integer passed, total;

    alu8 dut (
        .a(a), .b(b), .op(op),
        .y(y), .zero(zero), .carry(carry), .overflow(overflow), .negative(negative)
    );

    reg [7:0] m_y;
    reg m_zero, m_carry, m_overflow, m_negative;

    task check;
        begin
            total = total + 1;
            if (y === m_y && zero === m_zero && carry === m_carry && overflow === m_overflow && negative === m_negative) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: a=%d b=%d op=%b | expected y=%d z=%b c=%b o=%b n=%b, actual y=%d z=%b c=%b o=%b n=%b",
                         a, b, op, m_y, m_zero, m_carry, m_overflow, m_negative, 
                         y, zero, carry, overflow, negative);
            end
        end
    endtask

    // Reference Model logic
    always @(*) begin
        case (op)
            3'b000: begin // AND
                m_y = a & b; m_carry = 0; m_overflow = 0;
            end
            3'b001: begin // OR
                m_y = a | b; m_carry = 0; m_overflow = 0;
            end
            3'b010: begin // XOR
                m_y = a ^ b; m_carry = 0; m_overflow = 0;
            end
            3'b011: begin // ADD
                {m_carry, m_y} = a + b;
                m_overflow = (a[7] == b[7] && m_y[7] != a[7]);
            end
            3'b100: begin // SUB
                m_y = a - b;
                m_carry = (a >= b);
                m_overflow = (a[7] != b[7] && m_y[7] != a[7]);
            end
            3'b101: begin // SRA
                m_y = {a[7], a[7:1]};
                m_carry = a[0];
                m_overflow = 0;
            end
            3'b110: begin // ROL
                m_y = {a[6:0], a[7]};
                m_carry = a[7];
                m_overflow = 0;
            end
            3'b111: begin // SLT
                if ($signed(a) < $signed(b)) m_y = 8'h01; else m_y = 8'h00;
                m_carry = 0; m_overflow = 0;
            end
            default: begin m_y = 0; m_carry = 0; m_overflow = 0; end
        endcase
        m_zero = (m_y == 8'b0);
        m_negative = m_y[7];
    end

    initial begin
        passed = 0; total = 0;
        a = 0; b = 0; op = 0;
        #1; // Wait for combinational settling

        // Test AND
        op = 3'b000; a = 8'hAA; b = 8'h55; #1; check;
        op = 3'b000; a = 8'hFF; b = 8'h0F; #1; check;

        // Test OR
        op = 3'b001; a = 8'hAA; b = 8'h55; #1; check;
        op = 3'b001; a = 8'hF0; b = 8'h0F; #1; check;

        // Test XOR
        op = 3'b010; a = 8'hFF; b = 8'hAA; #1; check;
        op = 3'b010; a = 8'h55; b = 8'h55; #1; check;

        // Test ADD
        op = 3'b011; a = 8'd10; b = 8'd20; #1; check; // Normal
        op = 3'b011; a = 8'hFF; b = 8'h01; #1; check; // Carry out
        op = 3'b011; a = 8'h7F; b = 8'h01; #1; check; // Overflow (pos+pos=neg)
        op = 3'b011; a = 8'h80; b = 8'h80; #1; check; // Overflow (neg+neg=pos)

        // Test SUB
        op = 3'b100; a = 8'd50; b = 8'd20; #1; check; // Normal
        op = 3'b100; a = 8'd10; b = 8'd20; #1; check; // Borrow (carry=0)
        op = 3'b100; a = 8'd20; b = 8'd10; #1; check; // No borrow (carry=1)
        op = 3'b100; a = 8'h7F; b = 8'h80; #1; check; // Overflow (pos-neg=neg)
        op = 3'b100; a = 8'h80; b = 8'h7F; #1; check; // Overflow (neg-pos=pos)

        // Test SRA
        op = 3'b101; a = 8'b1000_0001; b = 0; #1; check; // Arithmetic shift
        op = 3'b101; a = 8'b0100_0001; b = 0; #1; check; // Logical-like shift
        op = 3'b101; a = 8'b1111_1111; b = 0; #1; check; // All ones

        // Test ROL
        op = 3'b110; a = 8'b1000_0000; b = 0; #1; check; // Wrap bit 7 to 0
        op = 3'b110; a = 8'b0000_0001; b = 0; #1; check; // Wrap bit 0 to 1

        // Test SLT (Signed)
        op = 3'b111; a = 8'd5;  b = 8'd10; #1; check; // 5 < 10 -> 1
        op = 3'b111; a = 8'd10; b = 8'd5;  #1; check; // 10 < 5 -> 0
        op = 3'b111; a = -8'd5; b = 8'd5;  #1; check; // -5 < 5 -> 1
        op = 3'b111; a = 8'h80; b = 8'h7F; #1; check; // Min neg < Max pos -> 1
        op = 3'b111; a = 8'h7F; b = 8'h80; #1; check; // Max pos < Min neg -> 0

        // Test Zero flag
        op = 3'b010; a = 8'hFF; b = 8'hFF; #1; check; // XOR result 0
        op = 3'b011; a = 8'h00; b = 8'h00; #1; check; // ADD result 0

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
