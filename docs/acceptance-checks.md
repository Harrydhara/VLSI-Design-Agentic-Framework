# Acceptance checks

Each team member's **completion check** from the division of work, run on 2026-10-20
against commit `b448efe` (the code on GitHub `main` and in the published image). Every
run named below is kept under `runs/`, so each result can be opened in the dashboard.

Setup: WSL Ubuntu 24.04, RTX 4090, Ollama 0.31.2 with `gemma4:26b`, Icarus Verilog 12,
Yosys 0.57+260; the Docker check used the published image
`ghcr.io/harrydhara/vlsi-design-agentic-framework:latest` (revision `b448efe`).

| Owner | Completion check | Result |
|---|---|---|
| Agent and integration | Generate RTL from the command line, capture a failed development check, revise using that feedback, stop within the limit, export the history; test the limit with a deterministic fake model and run a real model | **Pass** |
| EDA and evaluation | Known-correct fixtures pass; wrong carry/reset/mux behavior fails; a hung simulation times out; the benchmark reports compilation, functional and synthesis outcomes separately | **Pass** |
| Dashboard and delivery | A teammate uses a clean checkout and the prepared image to open the UI, run an example, edit a strategy/prompt, rerun it, and retain exported files after container recreation | **Pass** |

## 1. Agent and integration

**Revise from feedback (deterministic fake model).**
`vlsi-agent run adder4 --fake examples/scripted_adder4.json --score-every-attempt`
→ `runs/agent/20261020-143413-adder4-iter3`

```
attempt 1: development checks FAILED (compiled, testbench 256/512, 17 cells)
attempt 1: sent the check results back to the model (162 chars)
attempt 2: development checks PASSED (compiled, testbench 512/512, 23 cells)
hidden reference test on attempt 1: FAIL 256/512 (earlier attempt, for comparison)
hidden reference test on attempt 2: PASS 512/512
finished: dev_passed after 2 attempt(s), 1597 tokens, 1.2 s
```

The exported `history.json` holds the settings, both model calls (role, attempt, tokens),
both attempts with their checks and hidden-test scores, and the status; next to it are
`events.jsonl`, the attempt folders, the hidden-test logs and the prompts used.

**Limits (fake model scripted with three wrong replies).**

| Command | Stopped | Status |
|---|---|---|
| `vlsi-agent run adder4 --fake always_wrong.json --attempts 2` | after 2 of the 3 scripted replies | `attempts_exhausted` (`runs/agent/20261020-143415-adder4-iter2`) |
| `vlsi-agent run adder4 --fake always_wrong.json --budget 500` | before a second call: 654/500 tokens used | `token_budget_exhausted` (`runs/agent/20261020-143417-adder4-iter3`) |

**Real model.** `vlsi-agent run alu4 --score-every-attempt` with gemma4:26b →
`runs/agent/20261020-143429-alu4-iter3`

```
attempt 1: development checks FAILED (compiled, testbench 13/15, 135 cells)
attempt 1: sent the check results back to the model (251 chars)
attempt 2: development checks FAILED (compiled, testbench 13/15, 135 cells)
attempt 3: development checks FAILED (compiled, testbench 13/15, 135 cells)
hidden reference test on attempts 1, 2, 3: PASS 2048/2048
finished: attempts_exhausted after 3 attempt(s), 18560 tokens, 52.6 s
```

The loop revised twice and stopped at the 3-attempt limit. Every design was correct: the
model's own testbench rejected them, the pattern the benchmark measured (54-81% of correct
held-out designs, depending on the strategy, were rejected by the agent's own checks).

Also delivered: the one-shot baseline (`--one-shot`), attempt and token limits in the
config and on the command line, `events.jsonl` event logs, and documented student
strategies in `prompts/examples/` (each with a README of its results).

## 2. EDA and evaluation

**Fixtures.** `vlsi-agent check-fixtures`: all 58 fixtures across the 10 circuits behave as
expected (20 known-correct designs pass).

| Faulty behavior | Fixtures (circuit) | Hidden test |
|---|---|---|
| Carry | `no_carry_out`, `ignores_cin` (adder4); `nibble_carry_dropped`, `cout_from_bit7` (adder8) | fail, e.g. 256/512 |
| Reset | `async_reset`, `active_low_reset` (counter4); `sync_reset`, `reset_active_high` (updown8); `sync_reset` (seqdet_mealy); `reset_keeps_history` (seqdet_moore) | fail, e.g. 24/249 |
| Mux | `swapped_select`, `low_nibble_only` (mux2); `sel_bits_swapped`, `missing_case_latch`, `incomplete_sensitivity` (mux4) | fail, e.g. 1/524 |
| Hung simulation | `loop_without_increment` (mux2) | **timeout**: "simulation still running after 10 s" |
| Does not compile | `wrong_port_name` (adder4), `missing_event_control` (mux2) | compile_error |

ALU and sequence-detector fixtures (SLT, shifts, rotate, overflow, overlap, Moore/Mealy
timing) fail likewise.

**Development and final evaluation stay apart.** The tests that check that the hidden test
never reaches the model and runs only after the loop pass (`tests/test_agent.py`,
`tests/test_circuits.py`).

**Separate outcomes in the benchmark.** `runs/bench/heldout-seeds1-5/summary.md` has the
functional result (one-shot and iterative hidden-test passes per strategy, split and
circuit) and, separately, "Compile, synthesis and area" (compiled and synthesized,
one-shot → final, and median cells of passing designs only). `rows.csv` stores
`oneshot/final_compiled`, `oneshot/final_synth_ok`, `oneshot/final_outcome` and the cell
counts as separate columns.

**Waveform artifacts.**
`vlsi-agent evaluate counter4 circuits/counter4/fixtures/ignores_enable.v --waveform`
writes `reference.vcd` (26.7 KB) next to the log with the mismatch lines
(`runs/evaluate/counter4-20261020-143629`); the dashboard's Waveform tab plots any
attempt's hidden-test run.

## 3. Dashboard and delivery

All steps in a fresh `git clone https://github.com/Harrydhara/VLSI-Design-Agentic-Framework`
(commit `b448efe`), using the published image, not a local build:

```
docker compose -f compose.yaml -f compose.host-ollama.yaml pull app    # the prepared image
VLSI_AGENT_PORT=7863 docker compose -f compose.yaml -f compose.host-ollama.yaml up -d app
```

| Step | Observed |
|---|---|
| Image | `ghcr.io/harrydhara/vlsi-design-agentic-framework:latest`, revision `b448efe`; container healthy |
| Open the UI | http://localhost:7863 |
| Run an example | adder4, default strategy, gemma4:26b: hidden test PASS 512/512 after 2 attempts (`runs/acceptance/20261020-143904-adder4-default`) |
| Edit a strategy/prompt | Strategy editor: loaded `prompts/default`, added a sentence to `task.txt`, saved as `prompts/custom/acceptance_demo` (copy in `runs/acceptance/acceptance_demo-strategy`) |
| Rerun it | adder4 with `prompts/custom/acceptance_demo`: PASS 512/512; the run's `prompts/task.txt` contains the added sentence (`runs/acceptance/20261020-144012-adder4-acceptance_demo`) |
| Export | "Export run (.zip)" offered `ui-20261020-144012-adder4-acceptance_demo.zip` (27.2 KB: the run folder and `summary.md`) for download |
| Recreate the container | `docker compose down`, then `up -d`: container `5b49c85c9939` → `00901b97c756` |
| Files retained | Both runs and the custom strategy are still on the host (`runs/`, `prompts/custom/` are mounted) and in the new container; its dashboard lists both runs and the strategy |

Downloaded exports live wherever the browser saved them, outside the container.

Also delivered: the run-and-log dashboard with per-attempt results, diffs, waveforms,
benchmark charts, strategy editor, RTL editing with re-test, and exports; the Dockerfile
and Compose files; the image published by `.github/workflows/docker-image.yml` after its
tests pass; the README quick start; and `vlsi-agent doctor` as the installation
checklist (tools, versions, Ollama and the model).

## Notes for the report

- The GPU Ollama container itself was checked separately on 2026-10-20 (step 9c: Docker
  Desktop, full stack from a clean checkout, real run, 168 tokens/s). The check above used
  the machine's own Ollama, because this WSL Docker engine has no GPU passthrough.
- In the strategy check gemma4 did not follow the added instruction (no comment at the top
  of the design), although the run's prompt snapshot shows it received it. The check is
  about editing and rerunning a strategy; whether a model obeys a prompt is a separate
  question.
