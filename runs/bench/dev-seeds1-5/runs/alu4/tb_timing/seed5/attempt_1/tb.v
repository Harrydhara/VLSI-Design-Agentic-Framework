module tb;
    reg [3:0] a, b;
    reg [2:0] op;
    wire [3:0] y;
    wire zero, carry, overflow, negative;

    // Reference model variables
    reg [3:0] m_y;
    reg       m_zero, m_carry, m_overflow, m_negative;

    integer passed, total;

    alu4 dut (
        .a(a), .b(b), .op(op),
        .y(y), .zero(zero), .carry(carry), .overflow(overflow), .negative(negative)
    );

    task check;
        begin
            total = total + 1;
            if (y === m_y && zero === m_zero && carry === m_carry && 
                overflow === m_overflow && negative === m_negative) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: a=%d b=%d op=%b | expected y=%d z=%b c=%b ov=%b n=%b | actual y=%d z=%b c=%b ov=%b n=%b",
                         a, b, op, m_y, m_zero, m_carry, m_overflow, m_negative,
                         y, zero, carry, overflow, negative);
            end
        end
    endtask

    // Reference model logic
    always @(*) begin
        m_y = 4'b0;
        m_carry = 1'b0;
        m_overflow = 1'b0;
        case (op)
            3'b000: begin // ADD
                {m_carry, m_y} = a + b;
                if (a[3] == b[3] && m_y[3] != a[3]) m_overflow = 1'b1;
            end
            3'b001: begin // SUB
                m_carry = (a >= b);
                m_y = a - b;
                if (a[3] != b[3] && m_y[3] != a[3]) m_overflow = 1'b1;
            end
            3'b010: m_y = a & b;
            3'b011: m_y = a | b;
            3'b100: m_y = a ^ b;
            3'b101: begin 
                m_y = {a[2:0], 1'b0}; 
                m_carry = a[3];
            end
            3'b110: begin 
                m_y = {1'b0, a[3:1]}; 
                m_carry = a[0];
            end
            3'b111: m_y = (($signed({a[3], a}) < $signed({b[3], b})) ? 4'd1 : 4'd0);
        endcase
        m_zero = (m_y == 4'b0);
        m_negative = m_y[3];
    end

    initial begin
        passed = 0;
        total = 0;

        // Test ADD
        op = 3'b000; a = 4'd5; b = 4'd2; #1; check; // 7, c=0, ov=0
        op = 3'b000; a = 4'd7; b = 4'd1; #1; check; // 8 (1000), c=0, ov=1 (7+1=8, sign change)
        op = 3'b000; a = 4'd15; b = 4'd1; #1; check; // 0, c=1, ov=0
        op = 3'b000; a = 4'd8; b = 4'd8; #1; check; // 0, c=1, ov=0 (8+8=16 -> 0)

        // Test SUB
        op = 3'b001; a = 4'd5; b = 4'd2; #1; check; // 3, c=1, ov=0
        op = 3'b001; a = 4'd2; b = 4'd5; #1; check; // 13 (1101), c=0, ov=0
        op = 3'b001; a = 4'd8; b = 4'd1; #1; check; // 7, c=1, ov=1 (signed: -8 - 1 = -9 -> overflow)
        op = 3'b001; a = 4'd0; b = 4'd0; #1; check; // 0, c=1, ov=0

        // Test AND/OR/XOR
        op = 3'b010; a = 4'b1010; b = 4'b1100; #1; check; // 1000 (8)
        op = 3'b011; a = 4'b1010; b = 4'b1100; #1; check; // 1110 (14)
        op = 3'b100; a = 4'b1010; b = 4'b1100; #1; check; // 0110 (6)

        // Test SHL/SHR
        op = 3'b101; a = 4'b1011; b = 4'd0; #1; check; // y=0110, c=1
        op = 3'b101; a = 4'b0111; b = 4'd0; #1; check; // y=1110, c=0
        op = 3'b110; a = 4'b1011; b = 4'd0; #1; check; // y=0101, c=1
        op = 3'b110; a = 4'b0111; b = 4'd0; #1; check; // y=0011, c=1

        // Test SLT (Signed)
        op = 3'b111; a = 4'd2; b = 4'd5; #1; check;  // 0
        op = 3'b111; a = 4'd5; b = 4'd2; #1; check;  // 0
        op = 3'b111; a = 4'b1111; b = 4'b0001; #1; check; // -1 < 1 -> 1
        op = 3'b111; a = 4'b0111; b = 4'b1000; #1; check; // 7 < -8 is false -> 0

        // Test Zero/Negative edge cases
        op = 3'b000; a = 4'd0; b = 4'd0; #1; check; // y=0, z=1, n=0
        op = 3'b000; a = 4'd8; b = 4'd0; #1; check; // y=8 (1000), z=0, n=1

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
