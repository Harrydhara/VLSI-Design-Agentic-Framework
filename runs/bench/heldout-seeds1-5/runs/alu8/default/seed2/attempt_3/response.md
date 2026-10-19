```verilog
module alu8(
    input  [7:0] a,
    input  [7:0] b,
    input  [2:0] op,
    output [7:0] y,
    output       zero,
    output       carry,
    output       overflow,
    output       negative
);

    reg [7:0] y_reg;
    reg       carry_reg;
    reg       overflow_reg;

    // Internal signals for arithmetic
    wire [8:0] sum;
    wire [8:0] diff;
    wire [7:0] sra_val;
    wire [7:0] rol_val;
    wire [7:0] slt_val;

    assign sum = a + b;
    // For subtraction, we use 9-bit to correctly identify borrow/carry.
    // In unsigned math, a - b is equivalent to a + (~b) + 1.
    // The spec says carry for SUB is 1 when a >= b (no borrow).
    assign diff = a - b;
    
    // SRA: Arithmetic shift right by 1. Bit 7 is replicated.
    assign sra_val = {a[7], a[7:1]};
    
    // ROL: Rotate left by 1. bit 7 moves to bit 0.
    assign rol_val = {a[6:0], a[7]};

    // SLT: Set Less Than (signed)
    assign slt_val = ($signed(a) < $signed(b)) ? 8'h01 : 8'h00;

    always @(*) begin
        y_reg = 8'h00;
        carry_reg = 1'b0;
        overflow_reg = 1'b0;

        case (op)
            3'b000: begin // AND
                y_reg = a & b;
            end
            3'b001: begin // OR
                y_reg = a | b;
            end
            3'b010: begin // XOR
                y_reg = a ^ b;
            end
            3'b011: begin // ADD
                y_reg = sum[7:0];
                carry_reg = sum[8];
                overflow_reg = (a[7] == b[7]) && (sum[7] != a[7]);
            end
            3'b100: begin // SUB
                y_reg = diff[7:0];
                carry_reg = (a >= b);
                overflow_reg = (a[7] != b[7]) && (diff[7] != a[7]);
            end
            3'b101: begin // SRA
                y_reg = sra_val;
                carry_reg = a[0];
            end
            3'b110: begin // ROL
                y_reg = rol_val;
                carry_reg = a[7];
            end
            3'b111: begin // SLT
                y_reg = slt_val;
            end
            default: ;
        endcase
    end

    assign y = y_reg;
    assign zero = (y == 8'h00);
    assign carry = carry_reg;
    assign overflow = overflow_reg;
    assign negative = y[7];

endmodule
```

```verilog
module tb;
    reg [7:0] a, b;
    reg [2:0] op;
    wire [7:0] y;
    wire zero, carry, overflow, negative;

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

    task check_result;
        input [7:0] exp_y;
        input exp_z;
        input exp_c;
        input exp_ov;
        input exp_n;
        begin
            total = total + 1;
            if (y !== exp_y || zero !== exp_z || carry !== exp_c || overflow !== exp_ov || negative !== exp_n) begin
                $display("FAIL: a=%h b=%h op=%b | Exp: y=%h z=%b c=%b ov=%b n=%b | Got: y=%h z=%b c=%b ov=%b n=%b", 
                         a, b, op, exp_y, exp_z, exp_c, exp_ov, exp_n, y, zero, carry, overflow, negative);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        passed = 0;
        total = 0;

        // Test AND
        op = 3'b000; a = 8'hAA; b = 8'h55; check_result(8'h00, 1, 0, 0, 0);
        op = 3'b000; a = 8'hFF; b = 8'hF0; check_result(8'hF0, 0, 0, 0, 1);

        // Test OR
        op = 3'b001; a = 8'hAA; b = 8'h55; check_result(8'hFF, 0, 0, 0, 1);
        op = 3'b001; a = 8'h00; b = 8'h00; check_result(8'h00, 1, 0, 0, 0);

        // Test XOR
        op = 3'b010; a = 8'hFF; b = 8'hFF; check_result(8'h00, 1, 0, 0, 0);
        op = 3'b010; a = 8'hAA; b = 8'h55; check_result(8'hFF, 0, 0, 0, 1);

        // Test ADD
        op = 3'b011; a = 8'h01; b = 8'h02; check_result(8'h03, 0, 0, 0, 0);
        op = 3'b011; a = 8'hFF; b = 8'h01; check_result(8'h00, 1, 1, 0, 0);
        op = 3'b011; a = 8'h7F; b = 8'h01; check_result(8'h80, 0, 0, 1, 1);
        op = 3'b011; a = 8'h80; b = 8'h80; check_result(8'h00, 1, 1, 1, 0);

        // Test SUB
        op = 3'b100; a = 8'h05; b = 8'h02; check_result(8'h03, 0, 1, 0, 0);
        op = 3'b100; a = 8'h02; b = 8'h05; check_result(8'hFD, 0, 0, 0, 1);
        op = 3'b100; a = 8'h80; b = 8'h01; check_result(8'h7F, 0, 0, 1, 0);
        op = 3'b100; a = 8'h01; b = 8'h80; check_result(8'h81, 0, 0, 1, 1);
        op = 3'b100; a = 8'hFF; b = 8'hFF; check_result(8'h00, 1, 1, 0, 0);

        // Test SRA
        op = 3'b101; a = 8'h82; b = 8'h00; check_result(8'h41, 0, 0, 0, 0);
        op = 3'b101; a = 8'h81; b = 8'h00; check_result(8'hC0, 0, 1, 0, 1);
        op = 3'b101; a = 8'h01; b = 8'h00; check_result(8'h00, 1, 1, 0, 0);

        // Test ROL
        op = 3'b110; a = 8'h81; b = 8'h00; check_result(8'h03, 0, 1, 0, 0);
        op = 3'b110; a = 8'h01; b = 8'h00; check_result(8'h02, 0, 0, 0, 0);

        // Test SLT
        op = 3'b111; a = 8'h05; b = 8'h0A; check_result(8'h01, 0, 0, 0, 0);
        op = 3'b111; a = 8'h0A; b = 8'h05; check_result(8'h00, 1, 0, 0, 0);
        op = 3'b111; a = 8'hFF; b = 8'h01; check_result(8'h00, 1, 0, 0, 0);
        op = 3'b111; a = 8'h01; b = 8'hFF; check_result(8'h01, 0, 0, 0, 0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
```