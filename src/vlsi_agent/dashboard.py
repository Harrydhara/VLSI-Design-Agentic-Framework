"""Browser dashboard (Gradio): a learning path around the agent, its results and its code.

    vlsi-agent ui        # then open http://localhost:7860

The page has five tabs, read from left to right (the levels follow Bloom's taxonomy, see learn.py):

    Start here               what the field is, why it matters, who it is for, what to know first
    Level 1 · Beginner       remember and understand: lessons, explorers, a quiz
    Level 2 · Intermediate   apply and analyze: guided labs on the preconfigured tool
                             (1. Design and run, 2. Results, 3. Benchmarks)
    Level 3 · Advanced       evaluate and create: your own design, testbench or prompt strategy,
                             and a comparison of two runs
    Developer view           the source code, and the events, timing, files and messages of a run

Needs the optional extras: pip install -e ".[ui]". The run logic (stream_run), the results
data (runview.py), the lessons (learn.py), the comparison (compare.py) and the developer view
(devview.py) are plain Python and do not need Gradio, so they are tested without a browser.
"""

from __future__ import annotations

import json
import queue
import re
import shutil
import tempfile
import threading
import time
from pathlib import Path
from typing import Iterator

from vlsi_agent import devview, learn
from vlsi_agent.agent import DESIGN_FILE, RunResult, run_agent
from vlsi_agent.benchview import BENCH_ROOT, CHARTS, bench_markdown, export_benchmark, list_benchmarks, load_benchmark
from vlsi_agent.circuits import Circuit, CircuitError, get_circuit, load_circuits
from vlsi_agent.compare import (REASONING_PROMPTS, VERDICT_TEXT, attempt_verdict, comparison_markdown,
                                evaluation_report, final_design, verdict_figure)
from vlsi_agent.config import PROJECT_ROOT, Config, ToolsConfig, load_config
from vlsi_agent.eda import EDAToolError
from vlsi_agent.llm import BACKEND_NAMES, Completion, FakeLLM, make_llm
from vlsi_agent.progress import describe_event
from vlsi_agent.prompts import TEMPLATES, PromptError, find_strategies, workflow_of
from vlsi_agent.runview import (CHECK_HEADERS, ORIGIN_FILE, RUNS_ROOT, attempt_diffs, check_columns, check_table,
                                diff_html, export_run_zip, list_runs, load_run, mismatch_lines, run_markdown)
from vlsi_agent.strategy_editor import (CUSTOM_ROOT, FILE_HELP, WORKFLOW_TEXT, Draft, check_draft, check_markdown,
                                        draft_from_slots, load_draft, preview, save_draft, suggest_name)
from vlsi_agent.waveform import (MAX_WINDOW_NS, default_window, display_rows, is_clocked, mismatch_times,
                                 reference_log_now, reference_waveform, waveform_figure)

RUNS_DIR = RUNS_ROOT / "ui"
DEMO_SCRIPT = PROJECT_ROOT / "examples" / "scripted_adder4.json"
DEMO_MODEL = "Scripted demo (no GPU)"
DEMO_LIMITS = ("The scripted demo only covers adder4 with a single-reply strategy (default, tb_timing or a "
               "custom copy of them, not spec_first). Choose those, or switch to the real model.")

CSS = """
.diff { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: 13px; line-height: 1.45;
        padding: 8px 0; border-radius: 6px; overflow-x: auto; background: var(--block-background-fill);
        border: 1px solid var(--border-color-primary); }
.diff > div { white-space: pre; padding: 0 12px; }
.diff-add { background: rgba(46, 160, 67, 0.20); }
.diff-del { background: rgba(248, 81, 73, 0.20); }
.diff-meta { color: var(--body-text-color-subdued); }
.diff-note { color: var(--body-text-color-subdued); }
""" + learn.CSS


def strategy_choices() -> list[str]:
    return [p.relative_to(PROJECT_ROOT).as_posix() for p in find_strategies(PROJECT_ROOT / "prompts")]


def spec_markdown(circuit_name: str) -> str:
    spec = get_circuit(circuit_name).spec
    return (f"**{spec.family}** · {spec.split} circuit\n\n{spec.description}\n\n"
            f"Module header:\n\n```verilog\n{spec.interface()}\n```")


def summary_markdown(result: RunResult, run_dir: Path) -> str:
    final, first = result.reference, result.attempts[0].reference if result.attempts else None
    if final is None:
        verdict = "**No design was produced.**"
    else:
        checks = f" ({final.passed}/{final.total} checks)" if final.total else ""
        verdict = f"**Hidden reference test: {final.outcome.upper()}**{checks}"
    parts = [verdict]
    if first is not None and len(result.attempts) > 1:
        parts.append(f"one-shot {first.outcome.upper()} → final {final.outcome.upper()}")
    parts += [f"{len(result.attempts)} attempt(s)", f"{result.total_tokens:,} tokens", f"{result.duration_s:.1f} s",
              f"stopped because: {result.status.replace('_', ' ')}"]
    return " · ".join(parts) + "\n\nDetails are in **2. Results** below."  # same tab (Level 2), next section


def _new_run_dir(runs_dir: Path, circuit: str, strategy: str) -> Path:
    base = runs_dir / f"{time.strftime('%Y%m%d-%H%M%S')}-{circuit}-{Path(strategy).name}"
    run_dir, n = base, 1
    while run_dir.exists():
        n += 1
        run_dir = base.with_name(f"{base.name}-{n}")
    return run_dir


def stream_run(config: Config, circuit_name: str, strategy: str, max_attempts: int, demo: bool,
               runs_dir: Path = RUNS_DIR) -> Iterator[tuple[str, str, Path | None]]:
    """Run the agent in a background thread and yield (log, status, run folder) after every
    event. The run folder is None until the run has finished."""
    folder = PROJECT_ROOT / strategy
    if demo:
        if circuit_name != "adder4" or workflow_of(folder) != "single":
            yield "", DEMO_LIMITS, None
            return
        llm = FakeLLM(json.loads(DEMO_SCRIPT.read_text()))
    else:
        llm = make_llm(config.llm)
    circuit = get_circuit(circuit_name)
    run_dir = _new_run_dir(runs_dir, circuit_name, strategy)

    events: queue.Queue = queue.Queue()
    outcome: dict = {}

    def work() -> None:
        try:
            outcome["result"] = run_agent(config, circuit, llm, run_dir, max_attempts=max_attempts, prompts_dir=folder,
                                          score_every_attempt=True, on_event=events.put)
        except Exception as e:  # shown in the page instead of a stack trace in the server log
            outcome["error"] = f"{type(e).__name__}: {e}"
        finally:
            events.put(None)

    threading.Thread(target=work, daemon=True).start()
    lines: list[str] = []
    yield "", f"Running {circuit_name} with `{strategy}`...", None
    while (event := events.get()) is not None:
        line = describe_event(event)
        if line:
            lines.append(line)
            yield "\n".join(lines), f"Running · {line}", None
    if "error" in outcome:
        yield "\n".join(lines), f"**Stopped with an error:** {outcome['error']}", None
        return
    yield "\n".join(lines), summary_markdown(outcome["result"], run_dir), run_dir


# --------------------------------------------------------------------------- results view


def _run_folder(relative: str | None) -> Path | None:
    """A run folder chosen in the page, only if it is really inside runs/."""
    if not relative:
        return None
    folder = (RUNS_ROOT / relative).resolve()
    if not folder.is_relative_to(RUNS_ROOT.resolve()) or not (folder / "history.json").is_file():
        return None
    return folder


def results_for_run(relative: str | None) -> tuple[str, list[list], list[str], str | None]:
    """(run summary, check table rows, attempt choices, selected attempt) for a run folder."""
    folder = _run_folder(relative)
    if folder is None:
        return "Choose a run to see its attempts.", [], [], None
    run = load_run(folder)
    choices = [str(a.number) for a in run.attempts]
    return run_markdown(run), check_table(run), choices, (choices[-1] if choices else None)


def results_for_attempt(relative: str | None, number: str | None) -> tuple[str, str, str, str, str, str]:
    """(design, testbench, diffs html, hidden-test markdown, feedback, model reply) for one attempt."""
    folder = _run_folder(relative)
    if folder is None or not number:
        return "", "", "", "", "", ""
    run = load_run(folder)
    a = run.attempt(int(number))
    return (a.design or "(no Verilog in this reply)", a.testbench or "(no testbench)", attempt_diffs(run, a.number),
            mismatch_lines(a), a.feedback or "(nothing: this attempt passed the development checks)", a.reply)


WAVE_HINT = "Press **Draw waveform** to run this attempt's design through the hidden test again, recording this window."


def waveform_defaults(tools: ToolsConfig, relative: str | None, number: str | None) -> tuple[int, int]:
    """(start, length) in ns for an attempt's waveform: just before its first hidden-test mismatch."""
    folder = _run_folder(relative)
    if folder is None or not number:
        return 0, 64
    run = load_run(folder)
    a = run.attempt(int(number))
    circuit = get_circuit(run.history["circuit"])
    log = a.reference_log
    if "MISMATCH" in log and not mismatch_times(log) and a.design:  # saved before the tests printed the time
        log = reference_log_now(tools, circuit, a.folder / DESIGN_FILE)
    return default_window(circuit.spec, log)


def waveform_for_attempt(tools: ToolsConfig, relative: str | None, number: str | None, start, length):
    """(note, Plotly figure or None) for one attempt over [start, start + length] ns."""
    folder = _run_folder(relative)
    if folder is None or not number:
        return "Choose a run and an attempt.", None
    run = load_run(folder)
    a = run.attempt(int(number))
    if not a.design:
        return "This attempt has no design to simulate.", None
    circuit = get_circuit(run.history["circuit"])
    start = max(0, int(start or 0))
    length = max(1, min(int(length or 1), MAX_WINDOW_NS))
    w = reference_waveform(tools, circuit, a.folder / DESIGN_FILE, start, length)
    if w.wave is None:
        return f"No waveform: the hidden test ended with **{w.outcome.upper()}** ({w.detail}).", None
    times = mismatch_times(w.log)
    shown = [t for t in times if start <= t <= start + length]
    parts = [f"Attempt {a.number} · {start} to {start + length} ns · hidden test **{w.outcome.upper()}** ({w.detail})"]
    if times:
        listed = ", ".join(f"{t}" for t in times) + " ns" + (" (the test lists the first 5)" if len(times) == 5 else "")
        parts.append(f"Mismatches reported at {listed}; "
                     + ("dashed lines mark those in this window." if shown else "none is in this window."))
    if not is_clocked(circuit.spec):
        parts.append("Each input vector is held for 1 ns. The test computes the expected value when it checks, "
                     "at the end of that 1 ns, so the expected rows trail the outputs by 1 ns.")
    parts.append("Red marks unknown (x) values. Hover a bus to see its value in binary.")
    figure = waveform_figure(display_rows(w.wave, circuit.spec), start, start + length, times)
    return "\n\n".join(parts), figure


def _bench_folder(name: str | None) -> Path | None:
    """A benchmark chosen in the page, only if it is really a folder directly under runs/bench/."""
    folder = (BENCH_ROOT / name).resolve() if name else None
    if folder is None or folder.parent != BENCH_ROOT.resolve() or not folder.is_dir():
        return None
    return folder


def benchmark_charts(name: str | None) -> tuple:
    """(summary markdown, then one Plotly figure per chart in CHARTS) for a benchmark folder."""
    folder = _bench_folder(name)
    if folder is None:
        return ("Choose a benchmark. Run one with `vlsi-agent bench`; results go to `runs/bench/`.",
                *([None] * len(CHARTS)))
    view = load_benchmark(folder)
    if not view.rows:
        return (f"`{name}` has no finished runs yet.", *([None] * len(CHARTS)))
    return (bench_markdown(view), *(chart(view) for chart in CHARTS))


MANUAL_DIR = RUNS_ROOT / "manual"
EDIT_HINT = ("Edit this attempt's design or testbench, then **Check & test** runs exactly what the agent's attempts "
             "get: compile, your testbench, synthesis and the hidden test. The result is saved as a new run in "
             "`runs/manual/` (the original run is not changed) and opens below.")


class _ManualEdit(FakeLLM):
    """Hands the agent the edited code as its only reply, so it is checked exactly like a model's."""

    name = "manual edit"


def edit_defaults(relative: str | None, number: str | None) -> tuple[str, str]:
    """(design, testbench) of an attempt, to start editing from."""
    folder = _run_folder(relative)
    if folder is None or not number:
        return "", ""
    a = load_run(folder).attempt(int(number))
    return a.design or "", a.testbench or ""


def tools_missing(error: Exception) -> str:
    """What the page says when Icarus Verilog or Yosys cannot be started on this machine."""
    return ("**Not tested: the Verilog tools are not installed on this machine.** Compiling, simulating and "
            "synthesizing need Icarus Verilog and Yosys, which come with the project's Docker image "
            "(`docker compose up -d`) or a WSL/Linux setup; see the README. Everything that reads recorded runs "
            f"works without them.\n\nDetail: `{error}`")


def _checked_by_hand(config: Config, circuit: Circuit, design_text: str, testbench_text: str, note: str,
                     origin: dict, runs_dir: Path, label: str) -> Path:
    """Run code typed into the page through exactly what an agent attempt gets (compile, its
    testbench, synthesis, then the hidden test), as a one-attempt run of its own. Returns the run folder."""
    blocks = [design_text.strip()] + ([testbench_text.strip()] if (testbench_text or "").strip() else [])
    reply = f"{note}\n\n" + "\n\n".join(f"```verilog\n{block}\n```" for block in blocks) + "\n"
    run_dir = _new_run_dir(runs_dir, circuit.name, label)
    llm = _ManualEdit([Completion(reply, _ManualEdit.name, 0, 0, 0.0, False)])
    try:
        run_agent(config, circuit, llm, run_dir, max_attempts=1, prompts_dir=PROJECT_ROOT / "prompts" / "default",
                  score_every_attempt=True)
    except EDAToolError:
        shutil.rmtree(run_dir, ignore_errors=True)  # a half-written folder is not a run
        raise
    (run_dir / ORIGIN_FILE).write_text(json.dumps(origin, indent=2) + "\n", encoding="utf-8")
    return run_dir


def retest_edit(config: Config, relative: str | None, number: str | None, design_text: str, testbench_text: str,
                runs_dir: Path = MANUAL_DIR) -> tuple[str, str | None]:
    """Check edited code like one agent attempt; returns (status markdown, the new run's list entry or None)."""
    folder = _run_folder(relative)
    if folder is None or not number:
        return "Choose a run and an attempt first.", None
    if not (design_text or "").strip():
        return "There is no design to test.", None
    circuit = get_circuit(load_run(folder).history["circuit"])
    try:
        run_dir = _checked_by_hand(config, circuit, design_text, testbench_text,
                                   f"Manual edit of `{relative}`, attempt {number}.",
                                   {"edited_from": relative, "attempt": int(number)}, runs_dir, "edit")
    except EDAToolError as e:
        return tools_missing(e), None
    own, compile_, testbench, synthesis, hidden = check_columns(load_run(run_dir).attempts[0])
    entry = _relative(run_dir)
    return (f"**Saved as `{entry}`** and opened below. Own checks **{own}** (compile {compile_}, testbench "
            f"{testbench}, synthesis {synthesis}) · hidden test **{hidden}**."), entry


# --------------------------------------------------------------------------- guided labs (Level 2)


def lab_setup(title: str | None) -> dict:
    """What "Set up this lab" preselects: {"status", "circuit", "demo", "run", "bench"}.
    A recorded run or benchmark that is not on this machine is left out, and the status says so."""
    lab = learn.get_lab(title)
    run = lab.run if lab.run and _run_folder(lab.run) is not None else None
    bench = lab.bench if lab.bench and _bench_folder(lab.bench) is not None else None
    notes = []
    if lab.circuit:
        notes.append(f"`{lab.circuit}` is selected in **1. Design and run**"
                     + (", with the default strategy, 3 attempts and the scripted model" if lab.demo else ""))
    if run:
        notes.append(f"the recorded run `{run}` is open in **2. Results**")
    elif lab.run:
        notes.append(f"the recorded run `{lab.run}` is not on this machine (it is in the repository's `runs/` folder)")
    if bench:
        notes.append(f"the benchmark `{bench}` is open in **3. Benchmarks**")
    elif lab.bench:
        notes.append(f"the benchmark `{lab.bench}` is not on this machine (it is in the repository's `runs/bench/` "
                     "folder)")
    return {"status": "**Ready:** " + "; ".join(notes) + ". Now follow the steps above.",
            "circuit": lab.circuit, "demo": lab.demo, "run": run, "bench": bench}


# --------------------------------------------------------------------------- your own design (Level 3)

OWN_HEADER = "header"  # the "start from" choice that is not a prepared design
OWN_HINT = ("Write a design for the chosen circuit, with exactly the module header shown, or load one of the "
            "circuit's prepared designs (known-correct and deliberately faulty ones) and change it. Optionally "
            "write your own testbench. **Check & test** runs what every agent attempt gets: compile, your "
            "testbench, synthesis, and the hidden test. The result is saved as a new run in `runs/manual/`.\n\n"
            "Ideas: load a faulty design and repair it; load a correct design, plant a bug, and write a "
            "testbench that catches it; write a testbench first and see whether it agrees with the hidden test.")
OWN_NOTES = {
    "correct_accepted": "Your own checks and the hidden test agree: the design is correct.",
    "correct_rejected": ("The hidden test passes this design, but its own checks reject it. Look at which check "
                         "failed: a failing testbench means a wrong expected value or a check at the wrong time "
                         "(Lessons 3 and 4); a latch means a missing case in combinational code (Lesson 5)."),
    "wrong_accepted": ("Your testbench passes a design that the hidden test fails: it missed a bug. The hidden "
                       "test's mismatches below show inputs your testbench should have tried."),
    "wrong_rejected": "Both agree that something is wrong. Read the report below, change one thing, and test again.",
    "unscored": "No Verilog module was found, so nothing could be tested.",
}
NO_TESTBENCH_NOTE = ("You gave no testbench, so the own checks cannot pass and only the hidden test judges this "
                     "design. Add a testbench to find out whether yours would have agreed with it.")


def own_start_choices(circuit_name: str) -> list[tuple[str, str]]:
    """(label, value) choices for where an own design starts: the bare header, or a prepared design."""
    fixtures = get_circuit(circuit_name).fixtures
    return [("the module header only", OWN_HEADER)] + [
        (f"{name} (prepared design; the hidden test gives: {outcome.replace('_', ' ')})", name)
        for name, outcome in sorted(fixtures.items())]


def own_design_start(circuit_name: str, start: str | None) -> str:
    """The text an own design starts from: a prepared design, or the module header around an empty body."""
    circuit = get_circuit(circuit_name)
    if start in circuit.fixtures:
        return circuit.fixture_path(start).read_text(encoding="utf-8")
    return f"{circuit.spec.interface()}\n\n  // Your design goes here.\n\nendmodule\n"


def skeleton_testbench(circuit_name: str) -> str:
    """A testbench for the circuit with everything except the checks: the declarations, the
    design, a clock if it has one, a check task and the RESULT line."""
    spec = get_circuit(circuit_name).spec
    inputs = [p for p in spec.ports if p.direction == "input"]
    outputs = [p for p in spec.ports if p.direction == "output"]

    def declare(kind: str, port) -> str:
        return f"  {kind} {port.range} {port.name};" if port.range else f"  {kind} {port.name};"

    connections = ", ".join(f".{p.name}({p.name})" for p in spec.ports)
    lines = ["module tb;"] + [declare("reg ", p) for p in inputs] + [declare("wire", p) for p in outputs]
    lines += ["  integer passed = 0, total = 0;", "", f"  {spec.top} dut({connections});", ""]
    clock = next((p.name for p in inputs if p.name in ("clk", "clock")), None)
    if clock:
        lines += [f"  initial {clock} = 0;", f"  always #5 {clock} = ~{clock};  // a rising edge every 10 ns", ""]
    lines += [
        "  // One check: compare what the design gives with what the specification requires.",
        "  task check(input [31:0] got, input [31:0] expected);",
        "    begin",
        "      total = total + 1;",
        "      if (got === expected) passed = passed + 1;",
        '      else $display("FAIL at %0t: got %0d, expected %0d", $time, got, expected);',
        "    end",
        "  endtask",
        "",
        "  initial begin",
    ]
    example = outputs[0].name if outputs else "..."
    if clock:
        lines += ["    // Set the inputs, wait for a rising edge, wait a little longer, then check (Lesson 4):",
                  f"    //   ...;  @(posedge {clock}); #1;  check({example}, ...);"]
    else:
        lines += ["    // Set the inputs, wait, then check:", f"    //   ...;  #1;  check({example}, ...);"]
    lines += ["", '    $display("RESULT: %0d/%0d passed", passed, total);', "    $finish;", "  end", "endmodule", ""]
    return "\n".join(lines)


def check_own_design(config: Config, circuit_name: str | None, design_text: str, testbench_text: str,
                     runs_dir: Path = MANUAL_DIR) -> tuple[str, str | None, str, str]:
    """Check a design written in the page like one agent attempt. Returns (status markdown, the
    new run's list entry or None, the development checks' report, the hidden test's verdict)."""
    if not (design_text or "").strip():
        return "There is no design to test.", None, "", ""
    try:
        circuit = get_circuit(circuit_name or "")
    except CircuitError as e:
        return f"**Not tested.** {e}", None, "", ""
    try:
        run_dir = _checked_by_hand(config, circuit, design_text, testbench_text, f"Own design for `{circuit.name}`.",
                                   {"own_design": True, "circuit": circuit.name}, runs_dir, "own")
    except EDAToolError as e:
        return tools_missing(e), None, "", ""
    a = load_run(run_dir).attempts[0]
    own, compile_, testbench, synthesis, hidden = check_columns(a)
    entry = _relative(run_dir)
    verdict = attempt_verdict(a)
    note = OWN_NOTES[verdict]
    if verdict != "unscored" and not (testbench_text or "").strip():
        note = NO_TESTBENCH_NOTE
    status = (f"**Saved as `{entry}`.** Own checks **{own}** (compile {compile_}, testbench {testbench}, synthesis "
              f"{synthesis}) · hidden test **{hidden}**.\n\n**{VERDICT_TEXT[verdict].capitalize()}.** {note}\n\n"
              "The run is now selected in Level 2 (**2. Results**, for the waveform) and as run B in section C below.")
    return status, entry, a.feedback or "(nothing: the development checks passed)", mismatch_lines(a)


# --------------------------------------------------------------------------- comparing two runs (Level 3)

COMPARE_EXAMPLE = ("bench/heldout-seeds1-5/runs/alu8/default/seed4", "manual/20261020-141335-alu8-edit")
COMPARE_HINT = ("Choose a baseline (run A) and your variation (run B): for example a run with the default strategy "
                "and a run with your own, on the same circuit; or the design you started from and your repaired "
                "one. **Compare** shows what happened in each and what the difference supports. Then answer the "
                "questions in your own words and download the result.")


def compare_runs(relative_a: str | None, relative_b: str | None) -> tuple[str, object, str]:
    """(comparison markdown, Plotly figure or None, the diff of the two final designs as HTML)."""
    folder_a, folder_b = _run_folder(relative_a), _run_folder(relative_b)
    if folder_a is None or folder_b is None:
        return "Choose two runs, then press **Compare**.", None, ""
    a, b = load_run(folder_a), load_run(folder_b)
    text = comparison_markdown(a, b)
    if folder_a == folder_b:
        text = "**Run A and run B are the same run.** Choose a different run B to see a difference.\n\n" + text
    diff = "<h4>Final design: run A to run B</h4>" + diff_html(final_design(a), final_design(b), "run A", "run B")
    return text, verdict_figure([("A", a), ("B", b)]), diff


def export_evaluation(relative_a: str | None, relative_b: str | None, *answers: str) -> str | None:
    """The comparison of two runs and the user's answers as evaluation.md, or None if no two runs are chosen."""
    folder_a, folder_b = _run_folder(relative_a), _run_folder(relative_b)
    if folder_a is None or folder_b is None:
        return None
    path = _export_dir() / "evaluation.md"
    path.write_text(evaluation_report(load_run(folder_a), load_run(folder_b), relative_a, relative_b, list(answers)),
                    encoding="utf-8")
    return str(path)


# --------------------------------------------------------------------------- developer view

DEVELOPER_INTRO = ("Everything the other tabs show is computed by the code and read from the files listed here. "
                   "Nothing on this tab changes anything: it only reads.")


def developer_run(relative: str | None) -> tuple[str, list[list], str, list[str]]:
    """(summary, event rows, the messages to and from the model, the run's text files) for a run folder."""
    folder = _run_folder(relative)
    if folder is None:
        return "Choose a run.", [], "", []
    run = load_run(folder)
    return (run_markdown(run), devview.event_rows(devview.load_events(folder)), devview.conversation_text(run),
            devview.list_run_files(folder))


def developer_timing(relative: str | None) -> tuple[str, object]:
    """(where the run's time went as markdown, the same as a Plotly figure or None)."""
    folder = _run_folder(relative)
    if folder is None:
        return "", None
    events = devview.load_events(folder)
    return devview.timing_markdown(events), (devview.timing_figure(events) if events else None)


def developer_run_file(relative: str | None, name: str | None) -> tuple[str, str | None]:
    """(text, highlighting) of one text file of a run folder."""
    folder = _run_folder(relative)
    if folder is None:
        return "", None
    return devview.read_run_file(folder, name)


EDITOR_SLOTS = max(len(files) for files in TEMPLATES.values())  # text boxes for one workflow's templates


def editor_draft(source: str | None) -> tuple[Draft, str] | None:
    """A strategy from the list as an editable draft, and a name to save it under."""
    if source not in strategy_choices():
        return None
    folder = PROJECT_ROOT / source
    return load_draft(folder), suggest_name(folder)


def editor_save(loaded_from: str | None, workflow: str, name: str, slot_values, notes: str,
                root: Path = CUSTOM_ROOT) -> tuple[str, str | None]:
    """(status markdown, the saved strategy as a strategy-list entry or None). Replaces an
    existing custom strategy only if it is the one that was loaded into the editor."""
    draft = draft_from_slots(workflow, slot_values, notes)
    name = (name or "").strip()
    target = (Path(root) / name).resolve()
    may_replace = bool(name) and loaded_from is not None and (PROJECT_ROOT / loaded_from).resolve() == target
    try:
        folder, replaced = save_draft(draft, name, root, may_replace=may_replace)
    except PromptError as e:
        return f"**Not saved.** {e}", None
    try:
        entry = folder.resolve().relative_to(PROJECT_ROOT.resolve()).as_posix()
    except ValueError:
        entry = str(folder)
    warnings = check_draft(draft)[1]
    status = (f"**Saved `{entry}`**" + (" (replaced the earlier version)" if replaced else "")
              + ". Choose it under **1. Design and run** (Level 2) to run it.")
    if warnings:
        status += "\n\n" + "\n".join(f"- ⚠️ {w}" for w in warnings)
    return status, entry


def _export_dir() -> Path:
    return Path(tempfile.mkdtemp(prefix="vlsi-export-"))  # Gradio serves (and copies) files from the temp dir


def export_run(relative: str | None) -> str | None:
    """A zip of the chosen run folder with a summary.md, or None if no run is chosen."""
    folder = _run_folder(relative)
    if folder is None:
        return None
    name = re.sub(r"[^A-Za-z0-9_.-]+", "-", relative.replace("/runs/", "/")).strip("-")  # bench/dev-seeds1-5/alu4/...
    return str(export_run_zip(load_run(folder), _export_dir(), name))


def export_benchmark_files(name: str | None) -> list[str] | None:
    """The chosen benchmark's charts (standalone HTML) and rows (CSV), or None."""
    folder = _bench_folder(name)
    if folder is None:
        return None
    view = load_benchmark(folder)
    return [str(p) for p in export_benchmark(view, _export_dir())] if view.rows else None


def _relative(run_dir: Path) -> str:
    return run_dir.relative_to(RUNS_ROOT).as_posix()


# --------------------------------------------------------------------------- page


def build_app(config: Config | None = None):
    import gradio as gr

    config = config or load_config()
    real_model = f"{config.llm.model} via {BACKEND_NAMES[config.llm.backend]}"
    circuit_names = [c.name for c in load_circuits()]
    beginner, intermediate, advanced = learn.LEVELS
    first_lab = learn.LABS[0]
    default_source = f"{devview.PACKAGE_DIR.relative_to(PROJECT_ROOT).as_posix()}/dashboard.py"
    source_note, source_text, source_language = devview.read_source(default_source)
    # Gradio 5 takes css here; Gradio 6 moves it to launch() (pyproject pins gradio<6).
    with gr.Blocks(title="VLSI Design Agent", css=CSS) as app:
        gr.Markdown("# VLSI Design Agent\nA language model writes Verilog from a specification, two VLSI tools "
                    "(Icarus Verilog and Yosys) check that code, the model revises from their feedback, and a "
                    "hidden reference test scores the result. This site teaches what that means, lets you try "
                    "it, and shows the code behind it. **New here? Read the tabs from left to right.**")
        with gr.Tabs(selected="start") as levels:

            # ------------------------------------------------------------------- Start here
            with gr.Tab("Start here", id="start"):
                gr.Markdown(learn.START_HERE)
                to_level1 = gr.Button(f"Begin with {beginner.name}", variant="primary")

            # ------------------------------------------------------------------- Level 1: remember, understand
            with gr.Tab(beginner.name, id=beginner.key):
                gr.HTML(learn.badge(beginner), padding=False)
                gr.Markdown("Go through the lessons from left to right. Lessons 2, 3, 4 and 6 have an explorer: "
                            "change its inputs and read what changes. Nothing here needs a model or a tool.")
                with gr.Tabs():
                    with gr.Tab("Words"):
                        gr.Markdown("These words are used everywhere on the site. Come back here when one is unclear."
                                    "\n" + learn.GLOSSARY)
                    with gr.Tab("1 · Verilog"):
                        gr.Markdown(learn.LESSON_VERILOG)
                    with gr.Tab("2 · Signed numbers"):
                        gr.Markdown(learn.LESSON_SIGNED)
                        with gr.Row():
                            signed_a = gr.Slider(0, 255, value=0, step=1, label="a (the 8 bits as a number from 0 to 255)")
                            signed_b = gr.Slider(0, 255, value=128, step=1, label="b")
                        signed_out = gr.Markdown(learn.signed_explorer(0, 128))
                    with gr.Tab("3 · Testbenches"):
                        gr.Markdown(learn.LESSON_TESTBENCH)
                        with gr.Row():
                            adder_a = gr.Slider(0, 15, value=3, step=1, label="a")
                            adder_b = gr.Slider(0, 15, value=4, step=1, label="b")
                            adder_cin = gr.Slider(0, 1, value=0, step=1, label="cin")
                        adder_out = gr.Markdown(learn.adder_explorer(3, 4, 0))
                    with gr.Tab("4 · Timing") as timing_lesson:
                        gr.Markdown(learn.LESSON_TIMING)
                        sampling_offset = gr.Slider(*learn.SAMPLING_OFFSETS, value=3, step=1,
                                                    label="When the testbench looks, in ns after the rising clock "
                                                          "edge (0: at the edge; negative: before it)")
                        sampling_out = gr.Markdown(learn.sampling_explorer(3))
                        sampling_plot = gr.Plot(show_label=False)
                    with gr.Tab("5 · Synthesis"):
                        gr.Markdown(learn.LESSON_SYNTHESIS)
                    with gr.Tab("6 · The agent loop"):
                        gr.Markdown(learn.LESSON_AGENT)
                        gr.HTML(learn.PIPELINE_HTML, padding=False)
                        with gr.Row():
                            verdict_own = gr.Radio(["PASS", "FAIL"], value="FAIL", label="The agent's own checks say")
                            verdict_hidden = gr.Radio(["PASS", "FAIL"], value="PASS", label="The hidden test says")
                        verdict_out = gr.Markdown(learn.verdict_explorer("FAIL", "PASS"))
                    with gr.Tab("Quiz"):
                        gr.Markdown(f"Eight questions on Lessons 1 to 6: four ask you to remember, four to "
                                    f"understand. With {learn.QUIZ_PASS_MARK} or more correct you are ready for "
                                    "Level 2. You can try as often as you like.")
                        quiz_answers = [gr.Radio(list(q.choices), value=None, label=f"{number}. {q.prompt}")
                                        for number, q in enumerate(learn.QUIZ, start=1)]
                        quiz_button = gr.Button("Check my answers", variant="primary")
                        quiz_result = gr.Markdown()
                        to_level2 = gr.Button(f"Continue to {intermediate.name}")

            # ------------------------------------------------------------------- Level 2: apply, analyze
            with gr.Tab(intermediate.name, id=intermediate.key):
                gr.HTML(learn.badge(intermediate), padding=False)
                gr.Markdown("Here the tool is set up for you. Choose a lab, press **Set up this lab**, and follow "
                            "its steps in the three numbered sections below. The sections also work on their own, "
                            "for any circuit and any saved run.")
                with gr.Accordion("Guided labs", open=True):
                    lab_picker = gr.Radio(learn.lab_titles(), value=first_lab.title, label="Lab")
                    lab_text = gr.Markdown(learn.lab_markdown(first_lab))
                    lab_button = gr.Button("Set up this lab", variant="primary")
                    lab_status = gr.Markdown()
                    gr.Markdown("**Check your understanding** once you have done the steps:")
                    lab_answers = []
                    for slot in range(learn.LAB_QUESTION_SLOTS):
                        question = first_lab.questions[slot] if slot < len(first_lab.questions) else None
                        lab_answers.append(gr.Radio(list(question.choices) if question else [], value=None,
                                                    label=question.prompt if question else "Question",
                                                    visible=question is not None))
                    lab_check = gr.Button("Check my answers")
                    lab_result = gr.Markdown()

                with gr.Accordion("1. Design and run", open=True) as run_section:
                    with gr.Row(equal_height=False):
                        with gr.Column(scale=1, min_width=320):
                            circuit = gr.Dropdown(circuit_names, value="adder4", label="Circuit")
                            spec = gr.Markdown(spec_markdown("adder4"))
                            strategy = gr.Dropdown(strategy_choices(), value="prompts/default",
                                                   label="Strategy (prompts folder)")
                            mode = gr.Radio(["Iterative", "One-shot"], value="Iterative", label="Mode")
                            attempts = gr.Slider(1, 5, value=config.agent.max_attempts, step=1,
                                                 label="Maximum attempts (iterative mode)")
                            model = gr.Radio([real_model, DEMO_MODEL], value=real_model, label="Model")
                            run_button = gr.Button("Generate & test", variant="primary")
                        with gr.Column(scale=2, min_width=420):
                            status = gr.Markdown("Pick a circuit and a strategy, then press **Generate & test**.")
                            log = gr.Textbox(label="Agent and tool log", lines=14, max_lines=30, interactive=False,
                                             autoscroll=True)

                with gr.Accordion("2. Results", open=False) as results_section:
                    with gr.Row():
                        run_picker = gr.Dropdown(list_runs(), value=None, label="Run (newest first)", filterable=True,
                                                 scale=5)
                        refresh = gr.Button("Refresh list", scale=1)
                    run_info = gr.Markdown()
                    with gr.Row(equal_height=True):
                        export_run_button = gr.Button("Export run (.zip)", scale=1)
                        run_export = gr.File(label="Run folder and summary.md", interactive=False, height=60, scale=3)
                    checks = gr.Dataframe(headers=CHECK_HEADERS, value=[], interactive=False, wrap=True, row_count=1,
                                          label="Each attempt: the agent's own checks and the hidden test")
                    attempt = gr.Radio([], label="Attempt")
                    with gr.Tabs():
                        with gr.Tab("Design"):
                            design = gr.Code(label="design.v", interactive=False)
                        with gr.Tab("Testbench"):
                            testbench = gr.Code(label="tb.v", interactive=False)
                        with gr.Tab("Edit & re-test"):
                            gr.Markdown(EDIT_HINT)
                            edit_design = gr.Code(label="design.v (editable)", interactive=True)
                            edit_testbench = gr.Code(label="tb.v (editable; leave empty to test without one)",
                                                     interactive=True)
                            with gr.Row():
                                retest_button = gr.Button("Check & test", variant="primary")
                                reset_button = gr.Button("Reset to this attempt")
                            retest_status = gr.Markdown()
                        with gr.Tab("Changes from the previous attempt"):
                            diffs = gr.HTML(padding=False)
                        with gr.Tab("Hidden test"):
                            hidden = gr.Markdown()
                        with gr.Tab("Waveform"):
                            with gr.Row(equal_height=True):
                                wave_start = gr.Number(0, label="Start (ns)", precision=0, minimum=0)
                                wave_length = gr.Number(64, label="Length (ns)", precision=0, minimum=1,
                                                        maximum=MAX_WINDOW_NS)
                                draw = gr.Button("Draw waveform")
                            wave_note = gr.Markdown(WAVE_HINT)
                            wave_plot = gr.Plot(show_label=False)
                        with gr.Tab("Feedback sent to the model"):
                            feedback = gr.Textbox(lines=12, interactive=False, show_label=False)
                        with gr.Tab("Model reply"):
                            reply = gr.Markdown()

                with gr.Accordion("3. Benchmarks", open=False) as bench_section:
                    with gr.Row():
                        bench_picker = gr.Dropdown(list_benchmarks(), value=None, label="Benchmark (runs/bench/)",
                                                   scale=5)
                        bench_refresh = gr.Button("Refresh list", scale=1)
                    bench_info = gr.Markdown()
                    with gr.Row(equal_height=True):
                        export_bench_button = gr.Button("Export charts and rows", scale=1)
                        bench_export = gr.File(label="Charts (standalone HTML) and rows (CSV)", file_count="multiple",
                                               interactive=False, height=90, scale=3)
                    with gr.Row(equal_height=False):  # side by side when there is room, stacked otherwise
                        pass_plot = gr.Plot(show_label=False, min_width=460)
                        heatmap_plot = gr.Plot(show_label=False, min_width=460)
                    with gr.Row(equal_height=False):
                        checks_plot = gr.Plot(show_label=False, min_width=460)
                        fixed_plot = gr.Plot(show_label=False, min_width=460)
                    tokens_plot = gr.Plot(show_label=False)
                    bench_outputs = [bench_info, pass_plot, heatmap_plot, checks_plot, fixed_plot, tokens_plot]

                to_level3 = gr.Button(f"Continue to {advanced.name}")

            # ------------------------------------------------------------------- Level 3: evaluate, create
            with gr.Tab(advanced.name, id=advanced.key):
                gr.HTML(learn.badge(advanced), padding=False)
                gr.Markdown(learn.ADVANCED_INTRO)

                with gr.Accordion("A. Create: a design and a testbench of your own", open=True):
                    gr.Markdown(OWN_HINT)
                    with gr.Row(equal_height=True):
                        own_circuit = gr.Dropdown(circuit_names, value="adder4", label="Circuit", scale=2)
                        own_start = gr.Dropdown(own_start_choices("adder4"), value=OWN_HEADER,
                                                label="Start the design from", scale=4)
                        own_load = gr.Button("Load", scale=1)
                    own_spec = gr.Markdown(spec_markdown("adder4"))
                    own_design = gr.Code(own_design_start("adder4", OWN_HEADER), label="design.v (yours)",
                                         interactive=True)
                    own_testbench = gr.Code(label="tb.v (yours, optional): a module named tb that prints the "
                                                  "RESULT line", interactive=True)
                    with gr.Row():
                        own_button = gr.Button("Check & test", variant="primary")
                        own_skeleton = gr.Button("Put a testbench skeleton into tb.v")
                    own_status = gr.Markdown()
                    own_feedback = gr.Textbox(label="Report of the development checks (what a model would be sent "
                                                    "as feedback)", lines=6, max_lines=20, interactive=False)
                    own_hidden = gr.Markdown()

                with gr.Accordion("B. Create: a prompt strategy of your own (strategy editor)", open=False):
                    gr.Markdown("Copy a strategy, change its prompts, check them and save the copy under "
                                "`prompts/custom/`; it then appears in the **Strategy** list of **1. Design and run** "
                                "in Level 2. The shipped strategies are never changed, and every run keeps a copy of "
                                "the prompts it used. Running a strategy needs the model (a GPU).")
                    start_draft, start_name = editor_draft("prompts/default")
                    start_files = list(TEMPLATES[start_draft.workflow])
                    with gr.Row():
                        editor_source = gr.Dropdown(strategy_choices(), value="prompts/default", label="Start from",
                                                    scale=5)
                        editor_load = gr.Button("Load", scale=1)
                    editor_workflow = gr.State(start_draft.workflow)
                    editor_loaded = gr.State("prompts/default")  # the strategy whose files are in the editor
                    workflow_md = gr.Markdown("Workflow: " + WORKFLOW_TEXT[start_draft.workflow])
                    slots = []
                    for i in range(EDITOR_SLOTS):
                        shown = i < len(start_files)
                        slots.append(gr.Textbox(start_draft.texts[start_files[i]] if shown else "", lines=6,
                                                max_lines=30, label=f"{start_files[i]}.txt" if shown else "template",
                                                info=FILE_HELP[start_files[i]] if shown else None, visible=shown))
                    editor_notes = gr.Textbox(start_draft.notes, lines=4, label="README.md: notes on this strategy",
                                              info="What you changed and why. Never sent to the model.")
                    with gr.Row(equal_height=True):
                        editor_name = gr.Textbox(start_name, label="Save as prompts/custom/<name>", scale=4)
                        editor_check = gr.Button("Check", scale=1)
                        editor_save_button = gr.Button("Save", variant="primary", scale=1)
                    editor_status = gr.Markdown()
                    with gr.Accordion("Preview: the prompts as the model receives them", open=False):
                        with gr.Row(equal_height=True):
                            preview_circuit = gr.Dropdown(circuit_names, value="adder4", label="Circuit", scale=4)
                            preview_button = gr.Button("Preview", scale=1)
                        preview_text = gr.Textbox(lines=24, max_lines=60, interactive=False, show_label=False)
                    to_run = gr.Button("Go to Level 2 to run the strategy")

                with gr.Accordion("C. Evaluate: compare two runs and reason about the difference", open=True):
                    gr.Markdown(COMPARE_HINT)
                    with gr.Row():
                        compare_a = gr.Dropdown(list_runs(), value=None, label="Run A (the baseline)",
                                                filterable=True)
                        compare_b = gr.Dropdown(list_runs(), value=None, label="Run B (your variation)",
                                                filterable=True)
                    with gr.Row():
                        compare_button = gr.Button("Compare", variant="primary")
                        compare_example = gr.Button("Choose an example pair")
                        compare_refresh = gr.Button("Refresh lists")
                    compare_text = gr.Markdown()
                    compare_plot = gr.Plot(show_label=False)
                    compare_diff = gr.HTML(padding=False)
                    gr.Markdown("#### Your reasoning\nAnswer from the evidence above. There is no automatic grade "
                                "here: the comparison gives the facts, the conclusion is yours.")
                    reasoning = [gr.Textbox(label=prompt, lines=2) for prompt in REASONING_PROMPTS]
                    with gr.Row(equal_height=True):
                        evaluation_button = gr.Button("Download my evaluation (.md)", scale=1)
                        evaluation_file = gr.File(label="The comparison and your reasoning", interactive=False,
                                                  height=60, scale=3)

            # ------------------------------------------------------------------- Developer view
            with gr.Tab("Developer view", id="developer"):
                gr.Markdown(DEVELOPER_INTRO)
                with gr.Accordion("How the page is built: from a click to a chart", open=True):
                    gr.Markdown(devview.DATA_FLOW)
                    gr.Markdown("#### Which function each control calls\n\n" + devview.callbacks_markdown())
                with gr.Accordion("Source code", open=False):
                    source_picker = gr.Dropdown(devview.list_sources(), value=default_source, label="File",
                                                filterable=True)
                    source_info = gr.Markdown(source_note)
                    source_code = gr.Code(source_text, language=source_language, label="Source (read-only)",
                                          interactive=False)
                with gr.Accordion("Inside one run: events, timing, messages, files", open=False):
                    with gr.Row():
                        dev_run = gr.Dropdown(list_runs(), value=None, label="Run (newest first)", filterable=True,
                                              scale=4)
                        dev_same = gr.Button("Use the run open in Level 2", scale=1)
                        dev_refresh = gr.Button("Refresh list", scale=1)
                    dev_info = gr.Markdown("Choose a run.")
                    with gr.Tabs():
                        with gr.Tab("Events"):
                            gr.Markdown("One row per line of the run's `events.jsonl`, written while it ran.")
                            dev_events = gr.Dataframe(headers=devview.EVENT_HEADERS, value=[], interactive=False,
                                                      wrap=True, row_count=1)
                        with gr.Tab("Where the time went") as dev_timing_tab:
                            dev_timing = gr.Markdown()
                            dev_timing_plot = gr.Plot(show_label=False)
                        with gr.Tab("Messages to and from the model"):
                            dev_messages = gr.Textbox(lines=24, max_lines=60, interactive=False, show_label=False)
                        with gr.Tab("Files"):
                            dev_file = gr.Dropdown([], value=None, label="Text file in the run folder")
                            dev_file_text = gr.Code(label="File (read-only)", interactive=False)

        # ----------------------------------------------------------------------- moving between the levels

        def go_to(key):
            return lambda: gr.Tabs(selected=key)

        to_level1.click(go_to(beginner.key), None, levels)
        to_level2.click(go_to(intermediate.key), None, levels)
        to_level3.click(go_to(advanced.key), None, levels)
        to_run.click(go_to(intermediate.key), None, levels)

        # ----------------------------------------------------------------------- Level 1

        for slider in (signed_a, signed_b):
            slider.change(learn.signed_explorer, [signed_a, signed_b], signed_out, show_progress="hidden")
        for slider in (adder_a, adder_b, adder_cin):
            slider.change(learn.adder_explorer, [adder_a, adder_b, adder_cin], adder_out, show_progress="hidden")

        def on_sampling(offset):
            return learn.sampling_explorer(offset), learn.sampling_figure(offset)

        # The plot is drawn when its lesson is opened, so it is sized for a visible tab.
        for shown in (sampling_offset.change, timing_lesson.select):
            shown(on_sampling, sampling_offset, [sampling_out, sampling_plot], show_progress="hidden")
        for choice in (verdict_own, verdict_hidden):
            choice.change(learn.verdict_explorer, [verdict_own, verdict_hidden], verdict_out, show_progress="hidden")
        quiz_button.click(lambda *answers: learn.quiz_markdown(answers), quiz_answers, quiz_result)

        # ----------------------------------------------------------------------- Level 2: guided labs

        def on_lab_picked(title):
            lab = learn.get_lab(title)
            radios = [gr.update(choices=list(lab.questions[i].choices), label=lab.questions[i].prompt, value=None,
                                visible=True) if i < len(lab.questions)
                      else gr.update(choices=[], value=None, visible=False)
                      for i in range(learn.LAB_QUESTION_SLOTS)]
            return (learn.lab_markdown(lab), "", "", *radios)

        def on_lab_setup(title):
            chosen = lab_setup(title)
            keep = gr.update()
            demo = chosen["demo"]
            return (chosen["status"],
                    gr.update(value=chosen["circuit"]) if chosen["circuit"] else keep,
                    gr.update(value="prompts/default") if demo else keep,
                    gr.update(value="Iterative") if demo else keep,
                    gr.update(value=3) if demo else keep,
                    gr.update(value=DEMO_MODEL) if demo else keep,
                    gr.update(choices=list_runs(), value=chosen["run"]) if chosen["run"] else keep,
                    gr.update(choices=list_benchmarks(), value=chosen["bench"]) if chosen["bench"] else keep,
                    gr.update(open=bool(chosen["circuit"])),
                    gr.update(open=bool(chosen["run"])),
                    gr.update(open=bool(chosen["bench"])))

        lab_picker.change(on_lab_picked, lab_picker, [lab_text, lab_status, lab_result, *lab_answers])
        lab_button.click(on_lab_setup, lab_picker,
                         [lab_status, circuit, strategy, mode, attempts, model, run_picker, bench_picker,
                          run_section, results_section, bench_section])
        lab_check.click(lambda title, *answers: learn.lab_feedback(learn.get_lab(title), answers),
                        [lab_picker, *lab_answers], lab_result)

        # ----------------------------------------------------------------------- Level 2: run, results, benchmarks

        circuit.change(spec_markdown, circuit, spec)

        def on_run(circuit_name, strategy_path, mode_name, max_attempts, model_name):
            busy = gr.update(interactive=False, value="Running...")  # one run at a time, and it shows
            keep = gr.update()
            try:
                for log_text, status_text, run_dir in stream_run(
                        config, circuit_name, strategy_path, 1 if mode_name == "One-shot" else int(max_attempts),
                        model_name == DEMO_MODEL):
                    if run_dir is None:
                        yield log_text, status_text, keep, busy, keep
                    else:  # finished: select the new run and open its results
                        yield (log_text, status_text, gr.update(choices=list_runs(), value=_relative(run_dir)), busy,
                               gr.update(open=True))
            except Exception as e:  # e.g. a broken strategy: say so, and never leave the button disabled
                yield keep, f"**Could not start the run:** {type(e).__name__}: {e}", keep, busy, keep
            yield keep, keep, keep, gr.update(interactive=True, value="Generate & test"), keep

        def on_run_picked(relative):
            summary, table, choices, selected = results_for_run(relative)
            return summary, table, gr.update(choices=choices, value=selected), None

        def on_attempt_wave(relative, number):
            try:
                start, length = waveform_defaults(config.tools, relative, number)
            except EDAToolError:  # an old log without mismatch times, and no tools to run the test again
                start, length = 0, 64
            return start, length, WAVE_HINT, None

        def on_draw(relative, number, start, length):
            try:
                return waveform_for_attempt(config.tools, relative, number, start, length)
            except EDAToolError as e:
                return tools_missing(e), None

        attempt_files = [design, testbench, diffs, hidden, feedback, reply]
        wave_reset = [wave_start, wave_length, wave_note, wave_plot]
        run_button.click(on_run, [circuit, strategy, mode, attempts, model],
                         [log, status, run_picker, run_button, results_section])
        refresh.click(lambda: gr.update(choices=list_runs()), None, run_picker)
        export_run_button.click(export_run, run_picker, run_export)
        # Picking a run often leaves the attempt number as it was (say 3 → 3), which fires no
        # attempt change, so the attempt views are refreshed here; attempt.input covers clicks.
        editors = [edit_design, edit_testbench]
        for picked in (run_picker.change, app.load):
            (picked(on_run_picked, run_picker, [run_info, checks, attempt, run_export])
             .then(results_for_attempt, [run_picker, attempt], attempt_files)
             .then(edit_defaults, [run_picker, attempt], editors)
             .then(on_attempt_wave, [run_picker, attempt], wave_reset))
        (attempt.input(results_for_attempt, [run_picker, attempt], attempt_files)
         .then(edit_defaults, [run_picker, attempt], editors)
         .then(on_attempt_wave, [run_picker, attempt], wave_reset))
        reset_button.click(edit_defaults, [run_picker, attempt], editors).then(lambda: "", None, retest_status)

        def on_retest(relative, number, design_text, testbench_text):
            status_text, entry = retest_edit(config, relative, number, design_text, testbench_text)
            picker = gr.update(choices=list_runs(), value=entry) if entry else gr.update()
            return status_text, picker

        retest_button.click(on_retest, [run_picker, attempt, edit_design, edit_testbench], [retest_status, run_picker])
        for trigger in (draw.click, wave_start.submit, wave_length.submit):
            trigger(on_draw, [run_picker, attempt, wave_start, wave_length], [wave_note, wave_plot])
        for shown in (bench_picker.change, app.load):
            shown(benchmark_charts, bench_picker, bench_outputs)
        bench_picker.change(lambda: None, None, bench_export)
        export_bench_button.click(export_benchmark_files, bench_picker, bench_export)
        bench_refresh.click(lambda: gr.update(choices=list_benchmarks()), None, bench_picker)

        # ----------------------------------------------------------------------- Level 3: your own design

        def on_own_circuit(name):
            return (spec_markdown(name), gr.update(choices=own_start_choices(name), value=OWN_HEADER),
                    own_design_start(name, OWN_HEADER), "")

        def on_own_test(name, design_text, testbench_text):
            status_text, entry, report, hidden_text = check_own_design(config, name, design_text, testbench_text)
            if entry is None:
                return status_text, report, hidden_text, gr.update(), gr.update(), gr.update()
            runs = list_runs()
            return (status_text, report, hidden_text, gr.update(choices=runs, value=entry),
                    gr.update(choices=runs), gr.update(choices=runs, value=entry))

        own_circuit.change(on_own_circuit, own_circuit, [own_spec, own_start, own_design, own_testbench])
        own_load.click(own_design_start, [own_circuit, own_start], own_design)
        own_skeleton.click(skeleton_testbench, own_circuit, own_testbench)
        own_button.click(on_own_test, [own_circuit, own_design, own_testbench],
                         [own_status, own_feedback, own_hidden, run_picker, compare_a, compare_b])

        # ----------------------------------------------------------------------- Level 3: strategy editor

        def on_editor_load(source, workflow, loaded):
            found = editor_draft(source)
            if found is None:
                return (workflow, loaded, gr.update(), gr.update(), gr.update(), "Choose a strategy to load.",
                        *[gr.update()] * EDITOR_SLOTS)
            draft, name = found
            files = list(TEMPLATES[draft.workflow])
            boxes = [gr.update(value=draft.texts[files[i]], label=f"{files[i]}.txt", info=FILE_HELP[files[i]],
                               visible=True) if i < len(files) else gr.update(value="", visible=False)
                     for i in range(EDITOR_SLOTS)]
            return (draft.workflow, source, "Workflow: " + WORKFLOW_TEXT[draft.workflow], name, draft.notes,
                    f"Loaded `{source}`.", *boxes)

        def on_editor_check(workflow, notes, *texts):
            return check_markdown(draft_from_slots(workflow, texts, notes))

        def on_editor_save(loaded, workflow, name, notes, *texts):
            status_text, entry = editor_save(loaded, workflow, name, texts, notes)
            if entry is None:
                return status_text, loaded, gr.update(), gr.update()
            choices = strategy_choices()
            return status_text, entry, gr.update(choices=choices), gr.update(choices=choices, value=entry)

        def on_editor_preview(workflow, circuit_name, *texts):
            return preview(draft_from_slots(workflow, texts), get_circuit(circuit_name).spec)

        editor_load.click(on_editor_load, [editor_source, editor_workflow, editor_loaded],
                          [editor_workflow, editor_loaded, workflow_md, editor_name, editor_notes, editor_status,
                           *slots])
        editor_check.click(on_editor_check, [editor_workflow, editor_notes, *slots], editor_status)
        editor_save_button.click(on_editor_save, [editor_loaded, editor_workflow, editor_name, editor_notes, *slots],
                                 [editor_status, editor_loaded, strategy, editor_source])
        preview_button.click(on_editor_preview, [editor_workflow, preview_circuit, *slots], preview_text)

        # ----------------------------------------------------------------------- Level 3: comparing two runs

        def on_compare_example():
            first, second = COMPARE_EXAMPLE
            if _run_folder(first) is None or _run_folder(second) is None:
                return (gr.update(), gr.update(), "The example runs are not on this machine (they are in the "
                        "repository's `runs/` folder). Choose two runs of your own.")
            runs = list_runs()
            return (gr.update(choices=runs, value=first), gr.update(choices=runs, value=second),
                    "Run A is the 8-bit ALU from Lab 3, as the model left it. Run B is the same design with "
                    "`signed` added on two lines. Press **Compare**.")

        def on_compare_refresh():
            runs = list_runs()
            return gr.update(choices=runs), gr.update(choices=runs)

        compare_button.click(compare_runs, [compare_a, compare_b], [compare_text, compare_plot, compare_diff])
        compare_example.click(on_compare_example, None, [compare_a, compare_b, compare_text])
        compare_refresh.click(on_compare_refresh, None, [compare_a, compare_b])
        evaluation_button.click(export_evaluation, [compare_a, compare_b, *reasoning], evaluation_file)

        # ----------------------------------------------------------------------- Developer view

        def on_source(relative):
            note, text, language = devview.read_source(relative)
            return note, gr.update(value=text, language=language)

        def on_dev_run(relative):
            summary, rows, messages, files = developer_run(relative)
            timing_text, figure = developer_timing(relative)
            return (summary, rows, timing_text, figure, messages,
                    gr.update(choices=files, value=files[0] if files else None))

        def on_dev_file(relative, name):
            text, language = developer_run_file(relative, name)
            return gr.update(value=text, language=language)

        source_picker.change(on_source, source_picker, [source_info, source_code])
        (dev_run.change(on_dev_run, dev_run, [dev_info, dev_events, dev_timing, dev_timing_plot, dev_messages, dev_file])
         .then(on_dev_file, [dev_run, dev_file], dev_file_text))
        dev_file.input(on_dev_file, [dev_run, dev_file], dev_file_text)
        # Drawn again when its tab is opened, so the plot is sized for a visible tab.
        dev_timing_tab.select(developer_timing, dev_run, [dev_timing, dev_timing_plot])
        dev_same.click(lambda relative: gr.update(choices=list_runs(), value=relative), run_picker, dev_run)
        dev_refresh.click(lambda: gr.update(choices=list_runs()), None, dev_run)
    app.queue(default_concurrency_limit=1)  # one run at a time: the GPU serves one model call at a time anyway
    return app


def launch(config: Config, host: str, port: int) -> None:
    build_app(config).launch(server_name=host, server_port=port, show_api=False)
