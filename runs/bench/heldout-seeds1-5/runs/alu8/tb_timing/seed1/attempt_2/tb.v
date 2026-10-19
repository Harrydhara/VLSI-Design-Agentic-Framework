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
    reg m_zero, m_carry, m_overflow, m_neg;

    task check;
        begin
            total = total + 1;
            if (y !== m_y || zero !== m_zero || carry !== m_carry || overflow !== m_overflow || negative !== m_neg) begin
                $display("FAIL: a=%d b=%d op=%b | exp: y=%h z=%b c=%b v=%b n=%b | act: y=%h z=%b c=%b v=%b n=%b", 
                         a, b, op, m_y, m_zero, m_carry, m_overflow, m_neg, y, zero, carry, overflow, negative);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    // Reference Model
    always @(*) begin
        m_y = 8'b0;
        m_zero = 1'b0;
        m_carry = 1'b0;
        m_overflow = 1'b0;
        m_neg = 1'b0;

        case (op)
            3'b000: m_y = a & b;
            3'b001: m_y = a | b;
            3'b010: m_y = a ^ b;
            3'b011: begin 
                m_y = a + b; 
                m_carry = (a + b > 255);
                if (a[7] == b[7] && (a+b)[7] != a[7]) m_overflow = 1'b1;
            end
            3'b100: begin 
                m_y = a - b; 
                m_carry = (a >= b);
                if (a[7] != b[7] && (a-b)[7] != a[7]) m_overflow = 1'b1;
            end
            3'b101: begin 
                m_y = {a[7], a[7:1]}; 
                m_carry = a[0];
            end
            3'b110: begin 
                m_y = {a[6:0], a[7]}; 
                m_carry = a[7];
            end
            3'b111: begin 
                if ($signed(a) < $signed(b)) m_y = 8'h01; else m_y = 8'h00;
            end
        endcase
        m_zero = (m_y == 8'b0);
        m_neg = m_y[7];
    end

    initial begin
        passed = 0; total = 0;
        a = 0; b = 0; op = 0;
        #1; 

        // Test AND
        op = 3'b000; a = 8'hAA; b = 8'h55; #1; check; 
        op = 3'b000; a = 8'hFF; b = 8'h0F; #1; check; 

        // Test OR
        op = 3'b001; a = 8'hAA; b = 8'h55; #1; check; 
        op = 3'b001; a = 8'h00; b = 8'h00; #1; check; 

        // Test XOR
        op = 3'b010; a = 8'hFF; b = 8'hAA; #1; check; 
        op = 3'b010; a = 8'hFF; b = 8'hFF; #1; check; 

        // Test ADD
        op = 3'b011; a = 8'h05; b = 8'h02; #1; check; 
        op = 3'b011; a = 8'hFF; b = 8'h01; #1; check; 
        op = 3'b011; a = 8'h7F; b = 8'h01; #1; check; 
        op = 3'b011; a = 8'h80; b = 8'h80; #1; check; 

        // Test SUB
        op = 3'b100; a = 8'h0A; b = 8'h05; #1; check; 
        op = 3'b100; a = 8'h05; b = 8'h0A; #1; check; 
        op = 3'b100; a = 8'h7F; b = 8'h80; #1; check; 
        op = 3'b100; a = 8'h80; b = 8'h7F; #1; check; 

        // Test SRA
        op = 3'b101; a = 8'h80; b = 0; #1; check; 
        op = 3'b101; a = 8'h01; b = 0; #1; check; 
        op = 3'b101; a = 8'hAA; b = 0; #1; check; 

        // Test ROL
        op = 3'b110; a = 8'h81; b = 0; #1; check; 
        op = 3'b110; a = 8'h01; b = 0; #1; check; 
        op = 3'b110; a = 8'h7F; b = 0; #1; check; 

        // Test SLT (Signed)
        op = 3'b111; a = 8'h05; b = 8'h0A; #1; check; 
        op = 3'b111; a = 8'h0A; b = 8'h05; #1; check; 
        op = 3'b111; a = 8'hFF; b = 8'h01; #1; check; 
        op = 3'b111; a = 8'h7F; b = 8'h80; #1; check; 

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
