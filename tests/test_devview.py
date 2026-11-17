import json
import shutil
from pathlib import Path

import pytest

from vlsi_agent import devview
from vlsi_agent.config import PROJECT_ROOT
from vlsi_agent.runview import AttemptView, RunView

EVENTS = [
    {"t": 0.0, "event": "run_started", "circuit": "adder4", "split": "dev", "model": "fake", "max_attempts": 3,
     "max_total_tokens": 50000, "prompts": "prompts/default", "workflow": "single"},
    {"t": 0.01, "event": "model_called", "attempt": 1, "role": "design", "messages": 2},
    {"t": 10.01, "event": "model_replied", "attempt": 1, "role": "design", "prompt_tokens": 100, "output_tokens": 200,
     "duration_s": 10.0, "truncated": False},
    {"t": 10.51, "event": "checks_done", "attempt": 1, "passed": False, "code_found": True, "has_top": True,
     "has_testbench": True, "compiled": True, "tb_passed": 256, "tb_total": 512, "sim_timed_out": False,
     "synth_ok": True, "cells": 17, "latches": 0},
    {"t": 10.52, "event": "feedback_sent", "attempt": 1, "chars": 162},
    {"t": 10.53, "event": "model_called", "attempt": 2, "role": "design", "messages": 4},
    {"t": 15.53, "event": "model_replied", "attempt": 2, "role": "design", "prompt_tokens": 400, "output_tokens": 150,
     "duration_s": 5.0, "truncated": False},
    {"t": 16.03, "event": "checks_done", "attempt": 2, "passed": True, "code_found": True, "has_top": True,
     "has_testbench": True, "compiled": True, "tb_passed": 512, "tb_total": 512, "sim_timed_out": False,
     "synth_ok": True, "cells": 23, "latches": 0},
    {"t": 16.23, "event": "reference_scored", "attempt": 1, "final": False, "outcome": "fail", "passed": 256, "total": 512},
    {"t": 16.43, "event": "reference_scored", "attempt": 2, "final": True, "outcome": "pass", "passed": 512, "total": 512},
    {"t": 16.5, "event": "run_finished", "status": "dev_passed", "attempts": 2, "total_tokens": 850, "duration_s": 16.5,
     "reference": "pass"},
]


@pytest.fixture
def run_folder(tmp_path):
    """A run folder written by hand: events, a history, one attempt's files, and the default templates."""
    folder = tmp_path / "run"
    (folder / "attempt_1").mkdir(parents=True)
    lines = [json.dumps(e) for e in EVENTS]
    (folder / "events.jsonl").write_text("\n".join(lines[:3] + ["not json", '{"no": "event"}'] + lines[3:]) + "\n")
    (folder / "history.json").write_text("{}\n")
    (folder / "attempt_1" / "design.v").write_text("module adder4; endmodule\n")
    (folder / "attempt_1" / "sim.vvp").write_bytes(b"\x00compiled")
    shutil.copytree(PROJECT_ROOT / "prompts" / "default", folder / "prompts")
    return folder


def run_view(folder: Path, origin=None, prompts="/elsewhere/prompts/default") -> RunView:
    replies = ["First reply: the design.", "Second reply: the fixed design."]
    attempts = [AttemptView(number=n, folder=folder / f"attempt_{n}", design="module adder4; endmodule\n",
                            testbench=None, reply=replies[n - 1], feedback="- carry is wrong" if n == 1 else "",
                            checks={"code_found": True}, dev_passed=n == 2, reference=None, reference_log="")
                for n in (1, 2)]
    history = {"circuit": "adder4", "settings": {"max_attempts": 3, "prompts": prompts, "workflow": "single"},
               "attempts": [{"number": 1, "prompt_tokens": 100, "output_tokens": 200, "duration_s": 10.0},
                            {"number": 2, "prompt_tokens": 400, "output_tokens": 150, "duration_s": 5.0}]}
    return RunView(folder, history, attempts, origin)


def test_source_list_holds_the_code_the_prompts_and_the_circuits():
    sources = devview.list_sources()
    for name in ("src/vlsi_agent/dashboard.py", "src/vlsi_agent/learn.py", "src/vlsi_agent/agent.py",
                 "prompts/default/system.txt", "prompts/examples/spec_first/strategy.toml", "config/default.toml",
                 "circuits/adder4/spec.toml", "circuits/adder4/reference_tb.v", "examples/scripted_adder4.json"):
        assert name in sources, name
    assert len(sources) == len(set(sources)) and all((PROJECT_ROOT / s).is_file() for s in sources)
    assert not any(".." in s or s.startswith("/") or s.startswith("runs/") for s in sources)


def test_read_source_reads_only_listed_files():
    note, text, language = devview.read_source("src/vlsi_agent/agent.py")
    assert note.startswith("`src/vlsi_agent/agent.py` · ") and "The agent loop: generate a design" in note
    assert text.startswith('"""The agent loop') and language == "python"
    note, text, language = devview.read_source("circuits/adder4/reference_tb.v")
    assert "Hidden reference test" in note and "RESULT __RESULT_TOKEN__" in text and language is None
    assert "Prompt template" in devview.read_source("prompts/default/task.txt")[0]
    assert "Circuit specification" in devview.read_source("circuits/adder4/spec.toml")[0]
    assert devview.read_source("examples/scripted_adder4.json")[2] == "json"
    for outside in (None, "", "README.md", "../README.md", "src/vlsi_agent/../../pyproject.toml", "C:/Windows/win.ini"):
        assert devview.read_source(outside) == ("Choose a file.", "", None)


def test_run_files_are_the_text_files_only(run_folder):
    files = devview.list_run_files(run_folder)
    assert files[:2] == ["history.json", "events.jsonl"]
    assert "attempt_1/design.v" in files and "prompts/task.txt" in files and "attempt_1/sim.vvp" not in files
    assert devview.read_run_file(run_folder, "attempt_1/design.v") == ("module adder4; endmodule\n", None)
    assert devview.read_run_file(run_folder, "history.json") == ("{}\n", "json")
    for outside in (None, "attempt_1/sim.vvp", "../run/history.json", "missing.txt"):
        assert devview.read_run_file(run_folder, outside) == ("", None)


def test_events_and_where_the_time_went(run_folder):
    events = devview.load_events(run_folder)
    assert [e["event"] for e in events] == [e["event"] for e in EVENTS]  # the two unreadable lines are left out
    assert devview.load_events(run_folder / "attempt_1") == []
    rows = devview.event_rows(events)
    assert len(rows) == len(EVENTS) and all(len(row) == len(devview.EVENT_HEADERS) for row in rows)
    assert rows[3][:3] == [10.51, "checks_done", "attempt 1: development checks FAILED (compiled, testbench 256/512, 17 cells)"]
    assert json.loads(rows[2][3])["output_tokens"] == 200

    spans = devview.phases(events)
    assert [(round(end - start, 2), phase) for start, end, phase, _ in spans] == [
        (10.0, "model"), (0.5, "development checks"), (5.0, "model"), (0.5, "development checks"),
        (0.2, "hidden test"), (0.2, "hidden test")]
    assert devview.timing_breakdown(events) == {"model": 15.0, "development checks": 1.0, "hidden test": 0.4,
                                                "other": 0.1}
    text = devview.timing_markdown(events)
    assert "| model | waiting for the language model | 15.00 | 91% |" in text and "Total 16.50 s" in text
    assert devview.timing_markdown([]) == "This run has no timed events."
    assert devview.timing_breakdown([]) == dict.fromkeys(devview.PHASES, 0.0)


def test_user_folders_are_not_shown(run_folder):
    assert devview.hide_home("/mnt/c/Users/someone/Documents/My project/prompts/default") == \
        "~/Documents/My project/prompts/default"
    assert devview.hide_home("/home/someone/project and /Users/other/project") == "~/project and ~/project"
    assert devview.hide_home(json.dumps({"prompts": "C:\\Users\\someone\\project"})) == '{"prompts": "~\\\\project"}'
    assert devview.hide_home("/app/prompts/default, /usr/local/bin/yosys") == "/app/prompts/default, /usr/local/bin/yosys"
    started = {"t": 0.0, "event": "run_started", "prompts": "/mnt/c/Users/someone/project/prompts/default"}
    assert "someone" not in str(devview.event_rows([started])) and "~/project/prompts/default" in devview.event_rows([started])[0][3]
    (run_folder / "history.json").write_text('{"settings": {"prompts": "/home/someone/project/prompts/default"}}')
    assert devview.read_run_file(run_folder, "history.json")[0] == '{"settings": {"prompts": "~/project/prompts/default"}}'


def test_events_from_another_version_are_still_shown():
    rows = devview.event_rows([{"t": 1.0, "event": "model_replied", "attempt": 1}, {"event": "something_new", "x": 1}])
    assert rows[0][2] == "attempt=1" and rows[1] == ["", "something_new", "x=1", '{"x": 1}']
    assert devview.phases([{"t": "soon", "event": "model_replied"}]) == []


def test_timing_figure_has_one_bar_per_phase_stretch(run_folder):
    pytest.importorskip("plotly")
    fig = devview.timing_figure(devview.load_events(run_folder))
    assert len(fig.data) == 6 and [trace.name for trace in fig.data][:2] == ["model", "development checks"]
    assert sum(1 for trace in fig.data if trace.showlegend) == 3  # one legend entry per phase


def test_conversation_is_rebuilt_from_the_saved_templates(run_folder):
    text = devview.conversation_text(run_view(run_folder))
    assert text.startswith("===== message 1: system =====\nYou are a careful digital design engineer.")
    assert "===== message 2: user (the task) =====\nDesign the following circuit." in text and "module adder4(" in text
    assert "===== message 3: assistant, attempt 1 (100 prompt tokens in, 200 tokens out, 10.0 s) =====\nFirst reply" in text
    assert ("===== message 4: user (feedback from the development checks) =====\n"
            "Attempt 1 of 3 did not pass the development checks:\n\n- carry is wrong") in text
    assert "===== message 5: assistant, attempt 2" in text and "message 6" not in text


def test_conversation_without_saved_templates_or_without_a_model(run_folder):
    shutil.rmtree(run_folder / "prompts")
    text = devview.conversation_text(run_view(run_folder))
    assert text.startswith("(This run did not save its templates;") and "===== message 1: system =====" in text
    assert "cannot be rebuilt" in devview.conversation_text(run_view(run_folder, prompts="/elsewhere/prompts/gone"))
    assert devview.conversation_text(run_view(run_folder, origin={"own_design": True})).startswith("No model was called")
    spec_first = run_view(run_folder, prompts="/elsewhere/prompts/examples/spec_first")
    assert "spec_first workflow" in devview.conversation_text(spec_first)


def test_every_listed_callback_exists():
    for where, control, name, what in devview.CALLBACKS:
        assert callable(devview.resolve_callback(name)), name
        assert where and control and what
    table = devview.callbacks_markdown()
    assert table.count("\n") == len(devview.CALLBACKS) + 1 and "`dashboard.stream_run`" in table
    assert "`agent.py`" in devview.DATA_FLOW and "`evaluate.py`" in devview.DATA_FLOW
