module tb;
    reg [7:0] a, b;
    reg [2:0] op;
    wire [7:0] y;
    wire zero, carry, overflow, negative;

    integer i, j;
    integer passed, total;

    alu8 dut (
        .a(a),
        .b(b),
        .op(op),
        .y(y),
        .zero(zero),
        .carry(carry),
        .overflow(overflow),
        .negative(negative)
    );

    task check(input [7:0] exp_y, input exp_z, input exp_c, input exp_v, input exp_n);
        begin
            total = total + 1;
            if (y !== exp_y || zero !== exp_z || carry !== exp_c || overflow !== exp_v || negative !== exp_n) begin
                $display("FAIL: a=%d b=%d op=%b | Expected: y=%d z=%b c=%b v=%b n=%b | Actual: y=%d z=%b c=%b v=%b n=%b",
                         a, b, op, exp_y, exp_z, exp_c, exp_v, exp_n, y, zero, carry, overflow, negative);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        passed = 0;
        total = 0;

        // Test AND
        op = 3'b000; a = 8'hAA; b = 8'h55; check(8'h00, 1, 0, 0, 0);
        op = 3'b000; a = 8'hFF; b = 8'h0F; check(8'h0F, 0, 0, 0, 0);

        // Test OR
        op = 3'b001; a = 8'hAA; b = 8'h55; check(8'hFF, 0, 0, 0, 1);
        op = 3'b001; a = 8'h00; b = 8'h00; check(8'h00, 1, 0, 0, 0);

        // Test XOR
        op = 3'b010; a = 8'hAA; b = 8'h55; check(8'hFF, 0, 0, 0, 1);
        op = 3'b010; a = 8'hAA; b = 8'hAA; check(8'h00, 1, 0, 0, 0);

        // Test ADD
        op = 3'b011; a = 8'd10; b = 8'd20; check(8'd30, 0, 0, 0, 0);
        op = 3'b011; a = 8'hFF; b = 8'h01; check(8'h00, 1, 1, 0, 0); // Carry out
        op = 3'b011; a = 8'h7F; b = 8'h01; check(8'h80, 0, 0, 1, 1); // Signed Overflow (pos+pos=neg)
        op = 3'b011; a = 8'h80; b = 8'h80; check(8'h00, 1, 1, 0, 0); // Carry out, no overflow (neg+neg=pos is impossible here)
        // Wait, neg + neg: 1000_0000 + 1000_0000 = 0000_0000 with carry. 
        // a[7]=1, b[7]=1, y[7]=0. Overflow should be 1.
        a = 8'h80; b = 8'h80; op = 3'b011; // Re-run check for neg+neg
        check(8'h00, 1, 1, 1, 0);

        // Test SUB
        op = 3'b100; a = 8'd20; b = 8'd10; check(8'd10, 0, 1, 0, 0);
        op = 3'b100; a = 8'd10; b = 8'd20; check(8'd246, 0, 0, 0, 1); // Unsigned wrap: 10-20 = -10 (246)
        op = 3'b100; a = 8'hFF; b = 8'h00; check(8'hFF, 0, 1, 0, 1); // Carry: a>=b is true
        op = 3'b100; a = 8'h7F; b = 8'h80; check(8'hFF, 0, 0, 1, 1); // Signed Overflow (pos-neg=neg)

        // Test SRA
        op = 3'b101; a = 8'b1000_0011; b = 8'h00; check(8'b1100_0001, 0, 1, 0, 1); // Arithmetic shift
        op = 3'b101; a = 8'b0000_0011; b = 8'h00; check(8'b0000_0001, 0, 1, 0, 0); // Logical-like shift

        // Test ROL
        op = 3'b110; a = 8'b1000_0001; b = 8'h00; check(8'b0000_0011, 0, 1, 0, 0); // bit 7 to bit 0
        op = 3'b110; a = 8'b0100_0000; b = 8'h00; check(8'b1000_0000, 0, 0, 0, 1);

        // Test SLT
        op = 3'b111; a = 8'd5; b = 8'd10; check(8'd1, 0, 0, 0, 0); // 5 < 10
        op = 3'b111; a = 8'd10; b = 8'd5; check(8'd0, 1, 0, 0, 0); // 10 < 5 is false
        op = 3'b111; a = -8'd5; b = 8'd5; check(8'd1, 0, 0, 0, 0); // -5 < 5 (signed)
        op = 3'b111; a = 8'd5; b = -8'd5; check(8'd0, 1, 0, 0, 0); // 5 < -5 is false

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
