import dataclasses
import warnings

import pytest

from samples import ADDER, ADDER_NO_CARRY, TB, TB_FORGETS_CIN, reply
from vlsi_agent import learn
from vlsi_agent.agent import run_agent
from vlsi_agent.circuits import get_circuit, load_circuits
from vlsi_agent.config import PROJECT_ROOT, load_config
from vlsi_agent.dashboard import (COMPARE_EXAMPLE, DEMO_LIMITS, OWN_HEADER, check_own_design, compare_runs,
                                  developer_run, developer_run_file, developer_timing, export_evaluation, lab_setup,
                                  own_design_start, own_start_choices, spec_markdown, strategy_choices, stream_run,
                                  skeleton_testbench)
from vlsi_agent.llm import FakeLLM
from vlsi_agent.runview import RUNS_ROOT, list_runs, load_run, run_markdown

_base = load_config()
CONFIG = dataclasses.replace(_base, tools=dataclasses.replace(_base.tools, sim_timeout_s=2))
integration = pytest.mark.integration
# The recorded runs the labs open are in the repository's runs/ folder, which is not in the Docker image.
recorded = pytest.mark.skipif(not all((RUNS_ROOT / run).is_dir() for run in COMPARE_EXAMPLE),
                              reason="needs the recorded runs in runs/ (not in the Docker image)")


def test_strategy_choices_list_every_shipped_strategy():
    choices = strategy_choices()
    assert {"prompts/default", "prompts/examples/tb_timing", "prompts/examples/spec_first",
            "prompts/examples/spec_first_v1"} <= set(choices)


def test_spec_markdown_shows_description_and_header():
    text = spec_markdown("adder4")
    assert "carry-in and carry-out" in text and "```verilog\nmodule adder4(" in text


@pytest.mark.parametrize("circuit,strategy", [("mux2", "prompts/default"), ("adder4", "prompts/examples/spec_first")])
def test_demo_mode_explains_its_limits(tmp_path, circuit, strategy):
    updates = list(stream_run(CONFIG, circuit, strategy, 3, demo=True, runs_dir=tmp_path))
    assert updates == [("", DEMO_LIMITS, None)]
    assert not any(tmp_path.iterdir())


@pytest.mark.integration
def test_demo_run_streams_progress_and_a_summary(tmp_path):
    updates = list(stream_run(CONFIG, "adder4", "prompts/default", 3, demo=True, runs_dir=tmp_path))
    assert len(updates) > 5  # one update per event, not just a final one
    assert all(run_dir is None for _, _, run_dir in updates[:-1])
    log, status, run_dir = updates[-1]
    assert "attempt 1: development checks FAILED (compiled, testbench 256/512" in log
    assert "attempt 2: development checks PASSED" in log
    assert status.startswith("**Hidden reference test: PASS** (512/512 checks)")
    assert "one-shot FAIL → final PASS" in status and "2 attempt(s)" in status
    assert [run_dir] == list(tmp_path.iterdir()) and (run_dir / "history.json").is_file()


# --------------------------------------------------------------------------- Level 2: guided labs


def test_lab_setup_says_when_a_recorded_run_is_not_on_this_machine(tmp_path, monkeypatch):
    import vlsi_agent.dashboard as dashboard
    monkeypatch.setattr(dashboard, "RUNS_ROOT", tmp_path)
    monkeypatch.setattr(dashboard, "BENCH_ROOT", tmp_path / "bench")
    loop, _, _, benchmark = learn.LABS
    chosen = lab_setup(loop.title)
    assert (chosen["circuit"], chosen["demo"], chosen["run"], chosen["bench"]) == ("adder4", True, None, None)
    assert "`adder4` is selected in **1. Design and run**, with the default strategy" in chosen["status"]
    assert f"the recorded run `{loop.run}` is not on this machine" in chosen["status"]
    chosen = lab_setup(benchmark.title)
    assert chosen["circuit"] is None and chosen["bench"] is None and "is not on this machine" in chosen["status"]

    (tmp_path / loop.run).mkdir(parents=True)
    (tmp_path / loop.run / "history.json").write_text("{}")
    (tmp_path / "bench" / benchmark.bench).mkdir(parents=True)
    assert lab_setup(loop.title)["run"] == loop.run
    assert f"the recorded run `{loop.run}` is open in **2. Results**" in lab_setup(loop.title)["status"]
    assert lab_setup(benchmark.title)["bench"] == benchmark.bench
    assert lab_setup("no such lab")["circuit"] == "adder4"  # falls back to the first lab


@recorded
def test_every_lab_finds_its_recorded_run_and_the_facts_it_quotes():
    for lab in learn.LABS:
        chosen = lab_setup(lab.title)
        assert chosen["run"] == lab.run and chosen["bench"] == lab.bench, lab.key
    by_key = {lab.key: lab for lab in learn.LABS}
    false_alarm = load_run(RUNS_ROOT / by_key["false-alarm"].run)  # Lab 2: three correct designs, all rejected
    assert [(a.dev_passed, a.reference["outcome"]) for a in false_alarm.attempts] == [(False, "pass")] * 3
    assert false_alarm.history["tokens"]["total"] == 18560
    assert "o=1 n=1" in false_alarm.attempts[0].feedback.splitlines()[1]
    signed = load_run(RUNS_ROOT / by_key["waveform"].run)  # Lab 3: the signed comparison
    assert signed.history["reference"]["passed"] == 524288 - 32768
    assert "wire [8:0] sa = {a[7], a};" in signed.attempts[-1].design
    loop = load_run(RUNS_ROOT / by_key["loop"].run)  # Lab 1: the carry-out
    assert "assign cout = 1'b0;" in loop.attempts[0].design and loop.attempts[1].dev_passed


# --------------------------------------------------------------------------- Level 3: your own design


def test_own_design_starts_from_the_header_or_a_prepared_design():
    choices = own_start_choices("adder4")
    assert choices[0] == ("the module header only", OWN_HEADER)
    assert {value for _, value in choices[1:]} == set(get_circuit("adder4").fixtures)
    assert any("no_carry_out.v" in label and "fail" in label for label, _ in choices)
    blank = own_design_start("adder4", OWN_HEADER)
    assert blank.startswith("module adder4(\n") and blank.endswith("endmodule\n") and "Your design goes here" in blank
    assert own_design_start("adder4", None) == blank and own_design_start("adder4", "../spec.toml") == blank
    assert own_design_start("adder4", "no_carry_out.v") == get_circuit("adder4").fixture_path("no_carry_out.v").read_text()


def test_skeleton_testbench_fits_every_circuit():
    adder = skeleton_testbench("adder4")
    assert adder.startswith("module tb;\n  reg  [3:0] a;\n") and "  reg  cin;\n" in adder and "  wire cout;\n" in adder
    assert "  adder4 dut(.a(a), .b(b), .cin(cin), .sum(sum), .cout(cout));" in adder
    assert '$display("RESULT: %0d/%0d passed", passed, total);\n    $finish;' in adder
    assert "always #5" not in adder and "#1;  check(sum, ...);" in adder
    counter = skeleton_testbench("counter4")
    assert "  initial clk = 0;\n  always #5 clk = ~clk;" in counter and "@(posedge clk); #1;" in counter
    for circuit in load_circuits():
        text = skeleton_testbench(circuit.name)
        assert f"  {circuit.spec.top} dut(" in text and text.endswith("endmodule\n")
        assert all(f".{p.name}({p.name})" in text for p in circuit.spec.ports)


def test_own_design_needs_a_design_and_a_known_circuit():
    assert check_own_design(CONFIG, "adder4", "  ", "") == ("There is no design to test.", None, "", "")
    status, entry, report, hidden = check_own_design(CONFIG, "no_such_circuit", ADDER, "")
    assert status.startswith("**Not tested.**") and entry is None and (report, hidden) == ("", "")


@integration
def test_own_design_is_checked_like_an_attempt_and_judged_against_the_hidden_test(tmp_path, monkeypatch):
    import vlsi_agent.dashboard as dashboard
    monkeypatch.setattr(dashboard, "RUNS_ROOT", tmp_path)
    manual = tmp_path / "manual"

    status, entry, report, hidden = check_own_design(CONFIG, "adder4", ADDER, TB, runs_dir=manual)
    assert entry.startswith("manual/") and entry.endswith("-adder4-own") and entry in list_runs(tmp_path)
    assert "Own checks **PASS**" in status and "hidden test **PASS 512/512**" in status
    assert "**Correct design, accepted.**" in status and report.startswith("(nothing") and "No mismatches" in hidden
    run = load_run(tmp_path / entry)
    assert run.origin == {"own_design": True, "circuit": "adder4"} and run.history["tokens"]["total"] == 0
    assert "a design written in the page (Level 3)" in run_markdown(run)

    ignores_cin = ADDER.replace("a + b + cin", "a + b")  # with a testbench that expects the same wrong sum
    status, _, _, hidden = check_own_design(CONFIG, "adder4", ignores_cin, TB_FORGETS_CIN, runs_dir=manual)
    assert "**Wrong design, accepted (missed bug).**" in status and "MISMATCH" in hidden

    status, _, report, _ = check_own_design(CONFIG, "adder4", ADDER, TB_FORGETS_CIN, runs_dir=manual)
    assert "**Correct design, rejected (false alarm).**" in status and "256/512 checks passed" in report

    status, _, report, _ = check_own_design(CONFIG, "adder4", ADDER_NO_CARRY, TB, runs_dir=manual)
    assert "**Wrong design, rejected.**" in status and "hidden test **FAIL 256/512**" in status

    status, _, _, _ = check_own_design(CONFIG, "adder4", ADDER, "", runs_dir=manual)
    assert "testbench none" in status and "You gave no testbench" in status


@integration
@pytest.mark.parametrize("name", ["adder4", "counter4"])
def test_skeleton_testbench_compiles_and_reports_no_checks_yet(tmp_path, monkeypatch, name):
    import vlsi_agent.dashboard as dashboard
    monkeypatch.setattr(dashboard, "RUNS_ROOT", tmp_path)
    correct = next(f for f, outcome in get_circuit(name).fixtures.items() if outcome == "pass")
    design = own_design_start(name, correct)
    status, _, report, _ = check_own_design(CONFIG, name, design, skeleton_testbench(name), runs_dir=tmp_path / "manual")
    assert "compile ok, testbench 0/0" in status and "hidden test **PASS" in status, report


# --------------------------------------------------------------------------- Level 3: comparing two runs


def test_comparing_needs_two_runs():
    assert compare_runs(None, None) == ("Choose two runs, then press **Compare**.", None, "")
    assert compare_runs("../../src", "../../src")[1] is None
    assert export_evaluation(None, "../../src", "my answer") is None


@integration
def test_compare_two_runs_and_export_the_evaluation(tmp_path, monkeypatch):
    pytest.importorskip("plotly")
    import vlsi_agent.dashboard as dashboard
    monkeypatch.setattr(dashboard, "RUNS_ROOT", tmp_path)
    prompts = PROJECT_ROOT / "prompts" / "default"
    run_agent(CONFIG, get_circuit("adder4"), FakeLLM([reply(ADDER_NO_CARRY)]), tmp_path / "ui" / "a", max_attempts=1,
              prompts_dir=prompts, score_every_attempt=True)
    run_agent(CONFIG, get_circuit("adder4"), FakeLLM([reply(ADDER_NO_CARRY), reply(ADDER)]), tmp_path / "ui" / "b",
              max_attempts=3, prompts_dir=prompts, score_every_attempt=True)
    text, figure, diff = compare_runs("ui/a", "ui/b")
    assert "| Hidden test, final design | **FAIL** 256/512 | **PASS** 512/512 |" in text
    assert "Revising helped" in text and "Run B's final design passes the hidden test and run A's does not." in text
    assert sum(len(trace.x) for trace in figure.data) == 3
    assert "Final design: run A to run B" in diff and "diff-add" in diff
    assert compare_runs("ui/a", "ui/a")[0].startswith("**Run A and run B are the same run.**")
    report = open(export_evaluation("ui/a", "ui/b", "I let it revise."), encoding="utf-8").read()
    assert report.startswith("# Evaluation of two runs") and "I let it revise." in report and "`ui/b`" in report


@recorded
def test_the_example_pair_shows_the_signed_fix():
    pytest.importorskip("plotly")
    text, figure, diff = compare_runs(*COMPARE_EXAMPLE)
    assert "| Hidden test, final design | **FAIL** 491520/524288 | **PASS** 524288/524288 |" in text
    assert "Run B's final design passes the hidden test and run A's does not." in text
    assert "wire signed [8:0] sa" in diff and figure is not None


# --------------------------------------------------------------------------- developer view


def test_developer_view_needs_a_run():
    assert developer_run(None) == ("Choose a run.", [], "", [])
    assert developer_run("../../src") == ("Choose a run.", [], "", [])
    assert developer_timing(None) == ("", None) and developer_run_file("../../src", "history.json") == ("", None)


@integration
def test_developer_view_of_a_run(tmp_path, monkeypatch):
    pytest.importorskip("plotly")
    import vlsi_agent.dashboard as dashboard
    monkeypatch.setattr(dashboard, "RUNS_ROOT", tmp_path)
    run_agent(CONFIG, get_circuit("adder4"), FakeLLM([reply(ADDER_NO_CARRY), reply(ADDER)]), tmp_path / "ui" / "demo",
              max_attempts=3, prompts_dir=PROJECT_ROOT / "prompts" / "default", score_every_attempt=True)
    summary, rows, messages, files = developer_run("ui/demo")
    assert summary.startswith("**Hidden reference test: PASS**")
    assert [row[1] for row in rows][:3] == ["run_started", "model_called", "model_replied"]
    assert rows[-1][1] == "run_finished" and "finished: dev_passed after 2 attempt(s)" in rows[-1][2]
    assert "===== message 1: system =====" in messages and "256/512 checks passed" in messages
    assert "===== message 5: assistant, attempt 2" in messages
    assert files[:2] == ["history.json", "events.jsonl"] and "attempt_1/feedback.txt" in files
    text, language = developer_run_file("ui/demo", "history.json")
    assert '"circuit": "adder4"' in text and language == "json"
    assert developer_run_file("ui/demo", "attempt_1/sim.vvp") == ("", None)
    timing, figure = developer_timing("ui/demo")
    assert "| development checks |" in timing and figure is not None


@recorded
def test_developer_view_of_a_recorded_run_without_saved_templates():
    summary, rows, messages, files = developer_run(COMPARE_EXAMPLE[0])  # a benchmark run from before runs saved prompts/
    assert rows and "history.json" in files
    assert messages.startswith("(This run did not save its templates;") and "module alu8(" in messages
    assert developer_run(COMPARE_EXAMPLE[1])[2].startswith("No model was called")
    timing, _ = developer_timing(COMPARE_EXAMPLE[0]) if pytest.importorskip("plotly") else ("", None)
    assert "| model |" in timing


def test_app_builds_without_new_deprecation_warnings():
    pytest.importorskip("gradio")
    from vlsi_agent.dashboard import build_app
    with warnings.catch_warnings(record=True) as caught:
        warnings.simplefilter("always")
        app = build_app(CONFIG)
    assert app is not None
    # Gradio 5 still takes css only in Blocks (pyproject pins gradio<6); anything else is new and should be fixed.
    others = {str(w.message) for w in caught if issubclass(w.category, DeprecationWarning)
              and "'css' parameter" not in str(w.message)}
    assert others == set()
