1. For each failing check:
- FAIL: Async reset during operation failed. Expected: 0, Actual: 4
  Quoted sentence: "Whenever rst_n is 0, count becomes 0 immediately, without waiting for a clock edge, and stays 0 while rst_n is 0."
  Value required: 0. My testbench's expected value was 0, which matches the specification.

TESTBENCH OK