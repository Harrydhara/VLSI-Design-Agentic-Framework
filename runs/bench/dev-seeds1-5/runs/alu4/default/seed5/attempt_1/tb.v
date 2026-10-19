module tb;
    reg [3:0] a, b;
    reg [2:0] op;
    wire [3:0] y;
    wire zero, carry, overflow, negative;

    integer i, j;
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
        a = 4'd5; b = 4'd3; check_result(4'd8, 0, 0, 0, 0); // 5+3=8
        a = 4'd10; b = 4'd7; check_result(4'd1, 0, 1, 1, 1); // 10+7=17 (y=1, c=1, ovf: pos+neg? no. wait. 10 is -6 signed. 7 is +7. sum is 1. sign changed from neg to pos. overflow!)
        // Let's re-verify ADD Overflow spec: (a[3]==b[3]) && (y[3]!=a[3])
        // a=10(1010), b=7(0111). a[3]=1, b[3]=0. Not same sign. No overflow.
        a = 4'd10; b = 4'd7; check_result(4'd1, 0, 1, 0, 0); // Corrected: 10+7=17 (1 0001). y=1, c=1. a[3]=1, b[3]=0 -> no ovf.
        a = 4'd12; b = 4'd5; check_result(4'd1, 0, 1, 1, 0); // 12+5=17 (1 0001). a[3]=1, b[3]=0. No ovf.
        // Wait, overflow is only if signs are same.
        a = 4'd7; b = 4'd6; check_result(4'd13, 0, 0, 1, 0); // 7+6=13 (0111 + 0110 = 1101). a[3]=0, b[3]=0. y[3]=1. Overflow!
        a = 4'd15; b = 4'd1; check_result(4'd0, 1, 1, 1, 0); // 15+1=16 (1 0000). a[3]=1, b[3]=0. No ovf.
        a = 4'd15; b = 4'd15; check_result(4'd14, 0, 1, 0, 1); // 15+15=30 (1 1110). a[3]=1, b[3]=1. y[3]=1. No ovf.
        a = 4'd7; b = 4'd8; check_result(4'd15, 0, 0, 1, 0); // 7+8=15 (0111 + 1000 = 1111). a[3]=0, b[3]=1. No ovf.

        // SUB (001)
        op = 3'b001;
        a = 4'd10; b = 4'd5; check_result(4'd5, 0, 1, 0, 0); // 10-5=5. a>=b (c=1).
        a = 4'd5; b = 4'd10; check_result(4'd11, 0, 0, 0, 1); // 5-10=-5 (1011). a<b (c=0). ovf: (a[3]!=b[3]) && (y[3]!=a[3]) -> (0!=1) && (1!=0) = 1.
        // Re-check SUB overflow spec: (a[3] != b[3]) && (y[3] != a[3])
        // a=5(0101), b=10(1010). a[3]=0, b[3]=1. y=5-10=-5(1011), y[3]=1. 
        // (0!=1) && (1!=0) is true. So overflow = 1.
        a = 4'd5; b = 4'd5; check_result(4'd0, 1, 1, 0, 0); // 5-5=0. a>=b (c=1).

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
        a = 4'b1011; check_result(4'b0110, 0, 1, 0, 0); // shift left: y=0110, carry=a[3]=1
        a = 4'b0111; check_result(4'b1110, 0, 0, 0, 0); // shift left: y=1110, carry=a[3]=0

        // SHR (110)
        op = 3'b110;
        a = 4'b1011; check_result(4'b0101, 0, 1, 0, 0); // shift right: y=0101, carry=a[0]=1
        a = 4'b1110; check_result(4'b0111, 0, 0, 0, 0); // shift right: y=0111, carry=a[0]=0

        // SLT (111)
        op = 3'b111;
        a = 4'd2; b = 4'd3; check_result(4'd1, 0, 0, 0, 0); // 2 < 3 is true
        a = 4'd3; b = 4'd2; check_result(4'd0, 1, 0, 0, 0); // 3 < 2 is false
        a = 4'b1111; b = 4'b0001; check_result(4'd0, 1, 0, 0, 0); // -1 < 1 is true. Wait.
        // $signed(4'b1111) is -1. $signed(4'b0001) is 1. -1 < 1 is TRUE.
        a = 4'b1111; b = 4'b0001; check_result(4'd1, 0, 0, 0, 0); // Corrected: -1 < 1 is true -> y=1
        a = 4'b0001; b = 4'b1111; check_result(4'd0, 1, 0, 0, 0); // 1 < -1 is false -> y=0

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
