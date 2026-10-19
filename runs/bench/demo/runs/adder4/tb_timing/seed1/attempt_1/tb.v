module tb;
  reg [3:0] a, b; reg cin; wire [3:0] sum; wire cout;
  integer i, passed = 0, total = 0;
  adder4 dut(.a(a), .b(b), .cin(cin), .sum(sum), .cout(cout));
  initial begin
    for (i = 0; i < 512; i = i + 1) begin
      {cin, a, b} = i[8:0]; #1;
      total = total + 1;
      if ({cout, sum} === a + b + cin) passed = passed + 1;
      else if (total - passed <= 3) $display("FAIL: a=%0d b=%0d cin=%0d got %0d", a, b, cin, {cout, sum});
    end
    $display("RESULT: %0d/%0d passed", passed, total);
    $finish;
  end
endmodule
