1. For each failing check:
- Quoted sentence: "SLT 1 if a < b as signed two's complement numbers, otherwise 0"
- Required value for `a=0, b=8`: Since `a` (0) is treated as `0000` and `b` (8) is treated as `1000` in 4-bit two's complement, $0 < -8$ is false. Therefore, `y` should be `0`.
- My testbench expected value: `y=0`.
- The design actual value: `y=1`.

The failures show the design incorrectly identifies `a < b` for these cases (likely treating them as unsigned or having a sign extension error), but my testbench's expected values are correct according to the specification.

TESTBENCH OK