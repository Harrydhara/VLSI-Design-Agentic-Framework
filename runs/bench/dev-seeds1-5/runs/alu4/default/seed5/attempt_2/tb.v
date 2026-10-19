module tb;
    reg [3:0] a, b;
    reg [2:0] op;
    wire [3:0] y;
    wire zero, carry, overflow, negative;

    integer passed, total;

    alu4 uut (
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
        input [3:0] exp_y;
        input       exp_z;
        input       exp_c;
        input       exp_o;
        input       exp_n;
        begin
            total = total + 1;
            if (y !== exp_y || zero !== exp_z || carry !== exp_c || overflow !== exp_o || negative !== exp_n) begin
                $display("FAIL: a=%d b=%d op=%b | Expected: y=%d z=%b c=%b o=%b n=%b | Actual: y=%d z=%b c=%b o=%b n=%b", 
                         a, b, op, exp_y, exp_z, exp_c, exp_o, exp_n, y, zero, carry, overflow, negative);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        passed = 0;
        total = 0;

        // ADD (000)
        op = 3'b000;
        a = 4'd5; b = 4'd3; check_result(4'd8, 0, 0, 0, 0);
        a = 4'd10; b = 4'd7; check_result(4'd1, 0, 1, 0, 0); 
        a = 4'd7; b = 4'd6; check_result(4'd13, 0, 0, 1, 0); 
        a = 4'd15; b = 4'd1; check_result(4'd0, 1, 1, 0, 0); // 15+1=16 (1 0000). a[3]=1, b[3]=0. No ovf.
        a = 4'd15; b = 4'd15; check_result(4'd14, 0, 1, 0, 1); // 15+15=30 (1 1110). a[3]=1, b[3]=1. y[3]=1. No ovf.
        a = 4'd7; b = 4'd8; check_result(4'd15, 0, 0, 0, 0); // 7+8=15 (0111 + 1000 = 1111). a[3]=0, b[3]=1. No ovf.

        // SUB (001)
        op = 3'b001;
        a = 4'd10; b = 4'd5; check_result(4'd5, 0, 1, 0, 0);
        a = 4'd5; b = 4'd10; check_result(4'd11, 0, 0, 1, 1); // a=5(0101), b=10(1010). y=5-10=-5(1011). (a[3]!=b[3]) && (y[3]!=a[3]) -> (0!=1)&&(1!=0) = 1.
        a = 4'd5; b = 4'd5; check_result(4'd0, 1, 1, 0, 0);

        // AND (010)
        op = 3'b010;
        a = 4'hF; b = 4'h5; check_result(4'h5, 0, 0, 0, 0);
        a = 4'h0; b = 4'hF; check_result(4'h0, 1, 0, 0, 0);

        // OR (011)
        op = 3'b011;
        a = 4'hA; b = 4'h5; check_result(4'hF, 0, 0, 0, 0);
        a = 4'h0; b = 4'h0; check_result(4'h0, 1, 0, 0, 0);

        // XOR (100)
        op = 3'b100;
        a = 4'hF; b = 4'h5; check_result(4'hA, 0, 0, 0, 0);
        a = 4'hF; b = 4'hF; check_result(4'h0, 1, 0, 0, 0);

        // SHL (101)
        op = 3'b101;
        a = 4'b1011; check_result(4'b0110, 0, 1, 0, 0);
        a = 4'b0111; check_result(4'b1110, 0, 0, 0, 1); // y=1110 is negative

        // SHR (110)
        op = 3'b110;
        a = 4'b1011; check_result(4'b0101, 0, 1, 0, 0);
        a = 4'b1110; check_result(4'b0111, 0, 0, 0, 0);

        // SLT (111)
        op = 3'b111;
        a = 4'd2; b = 4'd3; check_result(4'd1, 0, 0, 0, 0);
        a = 4'd3; b = 4'd2; check_result(4'd0, 1, 0, 0, 0);
        a = 4'b1111; b = 4'b0001; check_result(4'd1, 0, 0, 0, 0); // -1 < 1 is true
        a = 4'b0001; b = 4'b1111; check_result(4'd0, 1, 0, 0, 0); // 1 < -1 is false

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
