module tb;
    reg [3:0] d0, d1, d2, d3;
    reg [1:0] sel;
    wire [3:0] y;

    integer passed = 0;
    integer total = 0;
    reg [3:0] expected_y;

    mux4 uut (
        .d0(d0),
        .d1(d1),
        .d2(d2),
        .d3(d3),
        .sel(sel),
        .y(y)
    );

    task check;
        begin
            total = total + 1;
            if (y === expected_y) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: time=%0d sel=%b d0=%h d1=%h d2=%h d3=%h expected=%h actual=%h", 
                         $time, sel, d0, d1, d2, d3, expected_y, y);
            end
        end
    endtask

    // Helper to update inputs and the reference model
    task set_inputs(input [3:0] v0, input [3:0] v1, input [3:0] v2, input [3:0] v3, input [1:0] s);
        begin
            d0 = v0; d1 = v1; d2 = v2; d3 = v3; sel = s;
            case(s)
                2'b00: expected_y = v0;
                2'b01: expected_y = v1;
                2'b10: expected_y = v2;
                2'b11: expected_y = v3;
                default: expected_y = 4'hF; // Should not happen with 2-bit sel
            endcase
        end
    endtask

    initial begin
        // Initialize
        d0 = 0; d1 = 0; d2 = 0; d3 = 0; sel = 0; expected_y = 0;
        #1;

        // Test Case 1: All zeros
        set_inputs(4'h0, 4'h0, 4'h0, 4'h0, 2'b00); #1; check();
        set_inputs(4'h0, 4'h0, 4'h0, 4'h0, 2'b01); #1; check();
        set_inputs(4'h0, 4'h0, 4'h0, 4'h0, 2'b10); #1; check();
        set_inputs(4'h0, 4'h0, 4'h0, 4'h0, 2'b11); #1; check();

        // Test Case 2: Distinct values
        set_inputs(4'hA, 4'hB, 4'hC, 4'hD, 2'b00); #1; check();
        set_inputs(4'hA, 4'hB, 4'hC, 4'hD, 2'b01); #1; check();
        set_inputs(4'hA, 4'hB, 4'hC, 4'hD, 2'b10); #1; check();
        set_inputs(4'hA, 4'hB, 4'hC, 4'hD, 2'b11); #1; check();

        // Test Case 3: Corner cases (all Fs and all 0s)
        set_inputs(4'hF, 4'h0, 4'hF, 4'h0, 2'b00); #1; check();
        set_inputs(4'hF, 4'h0, 4'hF, 4'h0, 2'b01); #1; check();
        set_inputs(4'hF, 4'h0, 4'hF, 4'h0, 2'b10); #1; check();
        set_inputs(4'hF, 4'h0, 4'hF, 4'h0, 2'b11); #1; check();

        // Test Case 4: Rapid switching (ensuring model updates with inputs)
        set_inputs(4'h1, 4'h2, 4'h3, 4'h4, 2'b00); #1; check();
        set_inputs(4'h1, 4'h2, 4'h3, 4'h4, 2'b01); #1; check();
        set_inputs(4'h1, 4'h2, 4'h3, 4'h4, 2'b10); #1; check();
        set_inputs(4'h1, 4'h2, 4'h3, 4'h4, 2'b11); #1; check();

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
