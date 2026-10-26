# Live demo script (about 5 minutes)

The demo follows the slides and shows the talk's main finding live: the agent's own testbench rejects
a correct design, and a one-word edit fixes a design that the agent could not. It uses only the
dashboard, in four parts: a live run, its results, the signed-comparison bug, and the benchmark charts.

The slides are the Slides deck "VLSI Design Agent: Final Presentation"; slide 16 hands over to this demo.

## Before the talk (15 minutes ahead)

1. Start the dashboard on the presenting machine, one of:
   - Docker: `docker compose up -d` in the repository, then wait until `docker compose logs pull-model`
     shows the model is downloaded.
   - WSL, without Docker: `~/.venvs/vlsi-agent/bin/vlsi-agent ui`, with Ollama running.
2. Open http://localhost:7860 in a browser and zoom to 125–150% so the room can read it.
3. **Warm up the model.** The first call after a start takes about 1.5 minutes while gemma4 loads onto
   the GPU. In **1. Design inputs** pick adder4, *One-shot*, model `gemma4:26b`, press
   **Generate & test**, and wait for it to finish.
4. In **3. Results**, check that the run list contains
   `bench/heldout-seeds1-5/runs/alu8/default/seed4` (type `alu8/default/seed4` into the list to filter it).
5. Close other programs that use the GPU. Keep the slides open in another window.

## The demo

### 1. A live run (0:00–1:30)

In **1. Design inputs** choose:

| Setting | Value |
|---|---|
| Circuit | `alu4` |
| Strategy | `prompts/default` |
| Mode | Iterative |
| Maximum attempts | 3 |
| Model | `gemma4:26b` |

Press **Generate & test**. The run takes about 55 seconds; talk while the log streams in **2. Run**:

> "The model gets the ALU's specification and its exact module header, and writes a design and a
> testbench. The framework compiles both with Icarus, runs the testbench, and synthesizes with Yosys.
> Watch the testbench line on each attempt."

**Expected:** the same seed and prompts gave this result before (run `runs/ui/20261020-151728-alu4-default`):
three attempts, each failing the model's own testbench at 13/15 checks, then the hidden reference test
passing all three designs (2048/2048), stopped because the attempts ran out, 18,560 tokens. If the
numbers differ, describe what the log shows instead.

> "The hidden test says every one of these designs was correct. The agent's own testbench rejected all
> three, so it spent two revisions on a design that was already right. That is the pattern behind the
> 54–81% on slide 11."

### 2. The results view (1:30–2:15)

In **3. Results** the new run is selected (the list is newest first).

- Point at the table **Each attempt: the agent's own checks and the hidden test**: own checks FAIL,
  hidden test PASS, three times.
- Open the **Feedback sent to the model** tab: this short message is all the model got back.
- Open the **Testbench** tab if there is time: the bug is in the testbench, not the design.

### 3. The signed-comparison bug (2:15–4:15)

In the **Run (newest first)** list type `alu8/default/seed4` and pick
`bench/heldout-seeds1-5/runs/alu8/default/seed4`. Choose **Attempt** 3.

1. **Waveform** tab: press **Draw waveform** (the window already opens just before the first mismatch).
   > "Operation 7 is SLT, signed set-less-than. When b goes negative the expected value drops to 0, and
   > the design keeps saying 1."
2. **Edit & re-test** tab: in `design.v (editable)`, lines 21–22 read

   ```verilog
   wire [8:0] sa = {a[7], a};
   wire [8:0] sb = {b[7], b};
   ```

   Type `signed` after `wire` on both lines:

   ```verilog
   wire signed [8:0] sa = {a[7], a};
   wire signed [8:0] sb = {b[7], b};
   ```

   Press **Check & test** (a few seconds).

**Expected:** hidden reference test PASS 524288/524288; the model's own testbench still 0/22; synthesis
256 cells. The result is saved as a new run under `runs/manual/` and selected in the list; the benchmark
run is not changed.

> "One word fixes it. The model never found this, because its own testbench failed for other reasons
> and could not point at the bug."

### 4. The benchmark charts (4:15–5:00)

In **4. Benchmarks** choose `heldout-seeds1-5`.

- **Hidden-test passes if stopped after k attempts:** the bars barely change after attempt 1.
- **Passes per circuit, one-shot → iterative:** the few changes are mux4 (compile errors) and
  seqdet_mealy; alu8 stays at 4/5.

> "That is the whole story in two charts. Thank you; happy to take questions."

## If something goes wrong

| Problem | What to do |
|---|---|
| The live run is slow or hangs (model not loaded, GPU busy) | Do not wait more than a minute. In **3. Results** open `ui/20261020-151728-alu4-default`, the same run recorded earlier, and continue with part 2. |
| No GPU or Ollama at all | Set **Model** to *Scripted demo (no GPU)* and **Circuit** to adder4: it replays a recorded run with real Icarus and Yosys checks. Then open the recorded alu4 run as above. |
| The edit gives a compile error | Press **Reset to this attempt** and add `signed` again, or open the saved edit `manual/20261020-141335-alu8-edit`. |
| The dashboard does not start | Present slides 6 and 13, which show the live log and the waveform, and the figures in `docs/final-report/figures/`. |

## After the demo

The demo adds runs under `runs/ui/` and `runs/manual/`. They are ordinary runs; delete the folders if
you do not want them committed.
