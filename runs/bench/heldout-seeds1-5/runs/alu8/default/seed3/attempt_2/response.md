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

    // Internal wires for arithmetic to handle carry/overflow easily
    wire [8:0] sum_add = a + b;
    wire [8:0] diff_sub = a - b;
    
    // Signed comparison for SLT
    // We use $signed to ensure the < operator treats inputs as 2's complement
    wire slt_val = ($signed({1'b0, a}) < $signed({1'b0, b})) ? 8'h1 : 8'h0;

    always @(*) begin
        // Default values to prevent latches
        y_reg = 8'h0;
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
                y_reg = sum_add[7:0];
                carry_reg = sum_add[8];
                // Overflow: same sign inputs, different sign result
                overflow_reg = (a[7] == b[7]) && (sum_add[7] != a[7]);
            end
            3'b100: begin // SUB
                y_reg = diff_sub[7:0];
                // Carry: 1 if a >= b as unsigned, else 0
                carry_reg = (a >= b) ? 1'b1 : 1'b0;
                // Overflow: different sign inputs, result sign differs from 'a'
                overflow_reg = (a[7] != b[7]) && (diff_sub[7] != a[7]);
            end
            3'b101: begin // SRA
                y_reg = {a[7], a[7:1]};
                carry_reg = a[0];
            end
            3'b110: begin // ROL
                y_reg = {a[6:0], a[7]};
                carry_reg = a[7];
            end
            3'b111: begin // SLT
                // Re-evaluating slt logic for 8-bit signed comparison
                if ($signed(a) < $signed(b))
                    y_reg = 8'h01;
                else
                    y_reg = 8'h00;
            end
            default: begin
                y_reg = 8'h0;
            end
        endcase
    end

    assign y = y_reg;
    assign carry = carry_reg;
    assign overflow = overflow_reg;
    assign zero = (y == 8'h0);
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
                $display("FAIL: a=%d b=%d op=%b | Exp: y=%h z=%b c=%b ov=%b n=%b | Got: y=%h z=%b c=%b ov=%b n=%b", 
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
        op = 3'b000; a = 8'hFF; b = 8'h0F; check_result(8'h0F, 0, 0, 0, 0);

        // Test OR
        op = 3'b001; a = 8'hAA; b = 8'h55; check_result(8'hFF, 0, 0, 0, 0);
        op = 3'b001; a = 8'h00; b = 8'h00; check_result(8'h00, 1, 0, 0, 0);

        // Test XOR
        op = 3'b010; a = 8'hFF; b = 8'hAA; check_result(8'h55, 0, 0, 0, 0);
        op = 3'b010; a = 8'hAA; b = 8'hAA; check_result(8'h00, 1, 0, 0, 0);

        // Test ADD
        op = 3'b011; a = 8'd10; b = 8'd20; check_result(8'd30, 0, 0, 0, 0);
        op = 3'b011; a = 8'hFF; b = 8'h01; check_result(8'h00, 1, 1, 0, 0); 
        op = 3'b011; a = 8'h7F; b = 8'h01; check_result(8'h80, 0, 0, 1, 1); 
        op = 3'b011; a = 8'h80; b = 8'h80; check_result(8'h00, 1, 1, 1, 0);

        // Test SUB
        op = 3'b100; a = 8'd20; b = 8'd10; check_result(8'd10, 0, 1, 0, 0); 
        op = 3'b100; a = 8'd10; b = 8'd20; check_result(8'hF6, 0, 0, 0, 1); 
        op = 3'b100; a = 8'h7F; b = 8'h80; check_result(8'hFF, 0, 0, 0, 1); // pos-neg=neg (no overflow)
        // Wait: SUB Overflow rule is "a and b have different sign bits and y's sign bit differs from a's"
        // a=7F (0), b=80 (1). diff = -1 (FF, 1). Sign of y(1) != sign of a(0). So overflow should be 1.
        op = 3'b100; a = 8'h7F; b = 8'h80; check_result(8'hFF, 0, 0, 1, 1);
        op = 3'b100; a = 8'h80; b = 8'h7F; check_result(8'h01, 0, 1, 1, 0); // neg-pos=pos. sign y(0) != sign a(1). Overflow=1

        // Test SRA
        op = 3'b101; a = 8'b1000_0011; b = 0; check_result(8'b1100_0001, 0, 1, 0, 1); 
        op = 3'b101; a = 8'b0100_0000; b = 0; check_result(8'b0010_0000, 0, 0, 0, 0);

        // Test ROL
        op = 3'b110; a = 8'b1000_0011; b = 0; check_result(8'b0000_0111, 0, 1, 0, 0); 
        op = 3'b110; a = 8'b0100_0001; b = 0; check_result(8'b1000_0010, 0, 0, 0, 1);

        // Test SLT
        op = 3'b111; a = 8'd5; b = 8'd10; check_result(8'd1, 0, 0, 0, 0);
        op = 3'b111; a = 8'd10; b = 8'd5; check_result(8'd0, 1, 0, 0, 0);
        op = 3'b111; a = 8'hFF; b = 8'h01; check_result(8'h01, 0, 0, 0, 0); // -1 < 1
        op = 3'b111; a = 8'h01; b = 8'hFF; check_result(8'h00, 1, 0, 0, 0); // 1 < -1 is false

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```