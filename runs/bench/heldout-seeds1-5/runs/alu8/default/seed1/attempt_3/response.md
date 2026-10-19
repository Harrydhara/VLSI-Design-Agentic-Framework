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

    reg [7:0] y_out;
    reg       carry_out;
    reg       overflow_out;

    wire [8:0] sum = a + b;
    wire [7:0] diff = a - b;

    always @(*) begin
        // Default values to prevent latches
        y_out = 8'h00;
        carry_out = 1'b0;
        overflow_out = 1'b0;

        case (op)
            3'b000: begin // AND
                y_out = a & b;
            end
            3'b001: begin // OR
                y_out = a | b;
            end
            3'b010: begin // XOR
                y_out = a ^ b;
            end
            3'b011: begin // ADD
                y_out = sum[7:0];
                carry_out = sum[8];
                if (a[7] == b[7] && y_out[7] != a[7])
                    overflow_out = 1'b1;
            end
            3'b100: begin // SUB
                y_out = diff;
                carry_out = (a >= b) ? 1'b1 : 1'b0;
                if (a[7] != b[7] && y_out[7] != a[7])
                    overflow_out = 1'b1;
            end
            3'b101: begin // SRA
                y_out = {a[7], a[7:1]};
                carry_out = a[0];
            end
            3'b110: begin // ROL
                y_out = {a[6:0], a[7]};
                carry_out = a[7];
            end
            3'b111: begin // SLT
                if ($signed(a) < $signed(b))
                    y_out = 8'h01;
                else
                    y_out = 8'h00;
            end
            default: ;
        endcase
    end

    assign y = y_out;
    assign zero = (y == 8'h00);
    assign carry = carry_out;
    assign overflow = overflow_out;
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

    task check_result;
        input [7:0] exp_y;
        input exp_z;
        input exp_c;
        input exp_ov;
        input exp_n;
        begin
            total = total + 1;
            if (y !== exp_y || zero !== exp_z || carry !== exp_c || overflow !== exp_ov || negative !== exp_n) begin
                $display("FAIL: op=%b a=%d b=%d | exp: y=%d z=%b c=%b ov=%b n=%b | act: y=%d z=%b c=%b ov=%b n=%b", 
                         op, a, b, exp_y, exp_z, exp_c, exp_ov, exp_n, y, zero, carry, overflow, negative);
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
        op = 3'b001; a = 8'hAA; b = 8'h55; check_result(8'hFF, 0, 0, 0, 1);
        op = 3'b001; a = 8'h00; b = 8'h00; check_result(8'h00, 1, 0, 0, 0);

        // Test XOR
        op = 3'b010; a = 8'hAA; b = 8'h55; check_result(8'hFF, 0, 0, 0, 1);
        op = 3'b010; a = 8'hAA; b = 8'hAA; check_result(8'h00, 1, 0, 0, 0);

        // Test ADD
        op = 3'b011; a = 8'h05; b = 8'h02; check_result(8'h07, 0, 0, 0, 0);
        op = 3'b011; a = 8'hFF; b = 8'h01; check_result(8'h00, 1, 1, 0, 0);
        op = 3'b011; a = 8'h7F; b = 8'h01; check_result(8'h80, 0, 0, 1, 1);
        op = 3'b011; a = 8'h80; b = 8'h80; check_result(8'h00, 1, 1, 1, 0);

        // Test SUB
        op = 3'b100; a = 8'h0A; b = 8'h02; check_result(8'h08, 0, 1, 0, 0);
        op = 3'b100; a = 8'h02; b = 8'h0A; check_result(8'hF8, 0, 0, 0, 1);
        op = 3'b100; a = 8'h7F; b = 8'h80; check_result(8'hFF, 0, 0, 1, 1);

        // Test SRA
        op = 3'b101; a = 8'h82; b = 8'h00; check_result(8'h41, 0, 0, 0, 0);
        op = 3'b101; a = 8'h81; b = 8'h00; check_result(8'h40, 0, 1, 0, 0);

        // Test ROL
        op = 3'b110; a = 8'h81; b = 8'h00; check_result(8'h03, 0, 1, 0, 0);
        op = 3'b110; a = 8'h41; b = 8'h00; check_result(8'h82, 0, 0, 0, 1);

        // Test SLT
        op = 3'b111; a = 8'h05; b = 8'h0A; check_result(8'h01, 0, 0, 0, 0);
        op = 3'b111; a = 8'h0A; b = 8'h05; check_result(8'h00, 1, 0, 0, 0);
        op = 3'b111; a = 8'hFF; b = 8'h01; check_result(8'h01, 0, 0, 0, 0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
```