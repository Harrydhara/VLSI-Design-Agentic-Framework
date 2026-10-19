# Benchmark results

2026-10-15 19:14 · model `gemma4:26b` (temperature 0.2, think False) · up to 3 attempts · budget 50000 tokens · seeds [1, 2, 3, 4, 5]

Strategies: `default` = prompts/default, `tb_timing` = prompts/examples/tb_timing, `spec_first_v1` = prompts/examples/spec_first_v1, `spec_first` = prompts/examples/spec_first

**One-shot** is the hidden reference result for attempt 1; **iterative** is the result for the final design. Both come from the same runs (paired). **fixed** = one-shot failed but the final design passed; **broken** = one-shot passed but a revision made it fail. **Own checks passed** = the agent's own development checks accepted its design. Counts are shown as passed/runs.

## By strategy

| strategy | runs | one-shot pass | iterative pass | fixed | broken | pass after 1 | pass after 2 | pass after 3 | own checks passed | mean attempts | mean tokens | mean s |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| default | 25 | 22/25 | 24/25 | 2 | 0 | 22/25 | 24/25 | 24/25 | 11/25 | 2.5 | 10500.6 | 23.7 |
| tb_timing | 25 | 25/25 | 25/25 | 0 | 0 | 25/25 | 25/25 | 25/25 | 19/25 | 1.6 | 6779.5 | 18.3 |
| spec_first_v1 | 25 | 20/25 | 21/25 | 2 | 1 | 20/25 | 21/25 | 21/25 | 15/25 | 1.9 | 12526.2 | 26.1 |
| spec_first | 25 | 20/25 | 23/25 | 3 | 0 | 20/25 | 23/25 | 23/25 | 16/25 | 1.8 | 12817 | 25.9 |

## By split

| strategy / split | runs | one-shot pass | iterative pass | fixed | broken | pass after 1 | pass after 2 | pass after 3 | own checks passed | mean attempts | mean tokens | mean s |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| default / heldout | 25 | 22/25 | 24/25 | 2 | 0 | 22/25 | 24/25 | 24/25 | 11/25 | 2.5 | 10500.6 | 23.7 |
| tb_timing / heldout | 25 | 25/25 | 25/25 | 0 | 0 | 25/25 | 25/25 | 25/25 | 19/25 | 1.6 | 6779.5 | 18.3 |
| spec_first_v1 / heldout | 25 | 20/25 | 21/25 | 2 | 1 | 20/25 | 21/25 | 21/25 | 15/25 | 1.9 | 12526.2 | 26.1 |
| spec_first / heldout | 25 | 20/25 | 23/25 | 3 | 0 | 20/25 | 23/25 | 23/25 | 16/25 | 1.8 | 12817 | 25.9 |

## By circuit

| circuit / strategy | runs | one-shot pass | iterative pass | fixed | broken | pass after 1 | pass after 2 | pass after 3 | own checks passed | mean attempts | mean tokens | mean s |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| adder8 / default | 5 | 5/5 | 5/5 | 0 | 0 | 5/5 | 5/5 | 5/5 | 5/5 | 1.8 | 4388.4 | 11.7 |
| adder8 / tb_timing | 5 | 5/5 | 5/5 | 0 | 0 | 5/5 | 5/5 | 5/5 | 5/5 | 1 | 1853 | 6.3 |
| adder8 / spec_first_v1 | 5 | 5/5 | 5/5 | 0 | 0 | 5/5 | 5/5 | 5/5 | 5/5 | 1 | 1687.2 | 6.9 |
| adder8 / spec_first | 5 | 5/5 | 5/5 | 0 | 0 | 5/5 | 5/5 | 5/5 | 5/5 | 1 | 1773.4 | 7.1 |
| alu8 / default | 5 | 4/5 | 4/5 | 0 | 0 | 4/5 | 4/5 | 4/5 | 0/5 | 3 | 21963.2 | 45.1 |
| alu8 / tb_timing | 5 | 5/5 | 5/5 | 0 | 0 | 5/5 | 5/5 | 5/5 | 3/5 | 1.8 | 11093.2 | 29.2 |
| alu8 / spec_first_v1 | 5 | 4/5 | 4/5 | 0 | 0 | 4/5 | 4/5 | 4/5 | 2/5 | 2.2 | 18796.8 | 34.0 |
| alu8 / spec_first | 5 | 4/5 | 4/5 | 0 | 0 | 4/5 | 4/5 | 4/5 | 2/5 | 2.2 | 22130.2 | 40.7 |
| mux4 / default | 5 | 3/5 | 5/5 | 2 | 0 | 3/5 | 5/5 | 5/5 | 5/5 | 2.2 | 6345.4 | 15.7 |
| mux4 / tb_timing | 5 | 5/5 | 5/5 | 0 | 0 | 5/5 | 5/5 | 5/5 | 3/5 | 2 | 5899 | 13.9 |
| mux4 / spec_first_v1 | 5 | 5/5 | 5/5 | 0 | 0 | 5/5 | 5/5 | 5/5 | 5/5 | 1 | 2194.8 | 10.2 |
| mux4 / spec_first | 5 | 5/5 | 5/5 | 0 | 0 | 5/5 | 5/5 | 5/5 | 5/5 | 1 | 2194.8 | 8.1 |
| seqdet_mealy / default | 5 | 5/5 | 5/5 | 0 | 0 | 5/5 | 5/5 | 5/5 | 1/5 | 2.6 | 11255.4 | 27.0 |
| seqdet_mealy / tb_timing | 5 | 5/5 | 5/5 | 0 | 0 | 5/5 | 5/5 | 5/5 | 5/5 | 1.4 | 6373.6 | 21.1 |
| seqdet_mealy / spec_first_v1 | 5 | 1/5 | 3/5 | 2 | 0 | 1/5 | 2/5 | 3/5 | 3/5 | 2.4 | 21648.4 | 43.9 |
| seqdet_mealy / spec_first | 5 | 1/5 | 4/5 | 3 | 0 | 1/5 | 4/5 | 4/5 | 2/5 | 2.6 | 22738.6 | 43.5 |
| updown8 / default | 5 | 5/5 | 5/5 | 0 | 0 | 5/5 | 5/5 | 5/5 | 0/5 | 3 | 8550.8 | 18.8 |
| updown8 / tb_timing | 5 | 5/5 | 5/5 | 0 | 0 | 5/5 | 5/5 | 5/5 | 3/5 | 2 | 8678.6 | 20.8 |
| updown8 / spec_first_v1 | 5 | 5/5 | 4/5 | 0 | 1 | 5/5 | 5/5 | 4/5 | 0/5 | 3 | 18303.8 | 35.4 |
| updown8 / spec_first | 5 | 5/5 | 5/5 | 0 | 0 | 5/5 | 5/5 | 5/5 | 2/5 | 2.2 | 15248 | 29.8 |

## Compile, synthesis and area

Cell counts are compared only for designs that pass the reference test, all synthesized with the same Yosys `synth` flow. They are a rough area proxy, not real power, area or timing.

| circuit / strategy | compiled (one-shot -> final) | synthesized (one-shot -> final) | median cells (passing final designs) |
|---|---|---|---|
| adder8 / default | 5/5 -> 5/5 | 5/5 -> 5/5 | 52 |
| adder8 / tb_timing | 5/5 -> 5/5 | 5/5 -> 5/5 | 52 |
| adder8 / spec_first_v1 | 5/5 -> 5/5 | 5/5 -> 5/5 | 52 |
| adder8 / spec_first | 5/5 -> 5/5 | 5/5 -> 5/5 | 52 |
| alu8 / default | 5/5 -> 5/5 | 5/5 -> 5/5 | 256.5 |
| alu8 / tb_timing | 5/5 -> 5/5 | 5/5 -> 5/5 | 256 |
| alu8 / spec_first_v1 | 5/5 -> 4/5 | 5/5 -> 4/5 | 256 |
| alu8 / spec_first | 5/5 -> 4/5 | 5/5 -> 4/5 | 256 |
| mux4 / default | 3/5 -> 5/5 | 3/5 -> 5/5 | 20 |
| mux4 / tb_timing | 5/5 -> 5/5 | 5/5 -> 5/5 | 15 |
| mux4 / spec_first_v1 | 5/5 -> 5/5 | 5/5 -> 5/5 | 15 |
| mux4 / spec_first | 5/5 -> 5/5 | 5/5 -> 5/5 | 15 |
| seqdet_mealy / default | 5/5 -> 5/5 | 5/5 -> 5/5 | 9 |
| seqdet_mealy / tb_timing | 5/5 -> 5/5 | 5/5 -> 5/5 | 9 |
| seqdet_mealy / spec_first_v1 | 2/5 -> 5/5 | 2/5 -> 5/5 | 9 |
| seqdet_mealy / spec_first | 1/5 -> 5/5 | 1/5 -> 5/5 | 9 |
| updown8 / default | 5/5 -> 5/5 | 5/5 -> 5/5 | 47 |
| updown8 / tb_timing | 5/5 -> 5/5 | 5/5 -> 5/5 | 47 |
| updown8 / spec_first_v1 | 5/5 -> 4/5 | 5/5 -> 4/5 | 47 |
| updown8 / spec_first | 5/5 -> 5/5 | 5/5 -> 5/5 | 47 |
