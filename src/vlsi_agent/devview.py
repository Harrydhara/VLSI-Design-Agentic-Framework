"""Developer view: the code and the data behind what the dashboard shows.

Three things, all read-only:

- the project's own source (Python modules, prompt templates, circuit specifications,
  reference tests, settings), chosen from a fixed list;
- for one run folder: its events in order, where its time went, any of its text files,
  and the messages the model received, rebuilt from the templates the run saved;
- which Python function each control of the page calls.

Plain Python; only the timing figure needs Plotly (the optional ui extra).
"""

from __future__ import annotations

import ast
import html
import importlib
import json
import re
from pathlib import Path

from vlsi_agent.circuits import CircuitError, get_circuit
from vlsi_agent.config import PROJECT_ROOT
from vlsi_agent.progress import describe_event
from vlsi_agent.prompts import PromptError, find_strategies, load_strategy
from vlsi_agent.runview import RunView
from vlsi_agent.strategy_editor import load_draft, preview

PACKAGE_DIR = Path(__file__).resolve().parent

# --------------------------------------------------------------------------- the project's source

SOURCE_PATTERNS = (f"{PACKAGE_DIR.relative_to(PROJECT_ROOT).as_posix()}/*.py", "prompts/**/*.txt",
                   "prompts/**/strategy.toml", "config/*.toml", "examples/*.json", "circuits/*/spec.toml",
                   "circuits/*/reference_tb.v", "pyproject.toml", "Dockerfile", "compose.yaml")
MAX_SHOWN_CHARS = 200_000

_KINDS = (
    ("reference_tb.v", "Hidden reference test: scores a design after the loop. Never shown to the model."),
    ("spec.toml", "Circuit specification: the description and ports the model is given."),
    ("strategy.toml", "Selects the workflow of a prompt strategy."),
    ("prompts/", "Prompt template: text sent to the model, with its {{placeholders}} filled in per circuit."),
    ("config/", "Settings: the model, the attempt and token limits, tool paths and timeouts."),
    ("examples/", "Scripted model replies for the demo that needs no GPU."),
    ("Dockerfile", "How the container image with the tools and the dashboard is built."),
    ("compose.yaml", "The container stack: the dashboard, the model server and the model download."),
    ("pyproject.toml", "The Python package: name, version and optional dependencies."),
)


def list_sources(root: Path = PROJECT_ROOT) -> list[str]:
    """The project files that can be shown, relative to the project folder."""
    root = Path(root)
    found: list[Path] = []
    for pattern in SOURCE_PATTERNS:
        found += sorted(p for p in root.glob(pattern) if p.is_file())
    return list(dict.fromkeys(p.relative_to(root).as_posix() for p in found))


def language_of(name: str) -> str | None:
    """The highlighting for a file, or None for plain text."""
    return {".py": "python", ".json": "json", ".md": "markdown"}.get(Path(name).suffix)


_HOME = re.compile(r"(?:/mnt/[a-z]/Users|/Users|/home|[A-Za-z]:[\\/]+Users)[\\/]+[^\\/\"'\s]+")


def hide_home(text: str) -> str:
    """Text with every user's home folder shortened to ~. Run files record absolute paths (for
    example of the prompts folder), and a user name has no place on a shared or recorded screen."""
    return _HOME.sub("~", text)


def _cut(text: str) -> str:
    if len(text) <= MAX_SHOWN_CHARS:
        return text
    return text[:MAX_SHOWN_CHARS] + f"\n... (cut after {MAX_SHOWN_CHARS:,} characters)\n"


def source_description(relative: str, text: str) -> str:
    """One line on what a project file is for: a module's docstring, or the kind of file."""
    if relative.endswith(".py"):
        try:
            doc = ast.get_docstring(ast.parse(text))
        except SyntaxError:
            doc = None
        return doc.strip().splitlines()[0] if doc and doc.strip() else "Python module."
    return next((text_ for key, text_ in _KINDS if key in relative), "")


def read_source(relative: str | None, root: Path = PROJECT_ROOT) -> tuple[str, str, str | None]:
    """(what the file is, its text, highlighting) for a file from list_sources; nothing else is readable."""
    if not relative or relative not in list_sources(root):
        return "Choose a file.", "", None
    text = (Path(root) / relative).read_text(encoding="utf-8", errors="replace")
    lines = text.count("\n") + (1 if text and not text.endswith("\n") else 0)
    return f"`{relative}` · {lines} lines · {source_description(relative, text)}", _cut(text), language_of(relative)


# --------------------------------------------------------------------------- one run's files

RUN_TEXT_SUFFIXES = {".json", ".jsonl", ".md", ".txt", ".v", ".log", ".ys", ".toml"}
_RUN_FIRST = ("history.json", "events.jsonl", "origin.json")


def list_run_files(folder: Path) -> list[str]:
    """The text files of a run folder, history.json and events.jsonl first."""
    folder = Path(folder)
    files = sorted(p.relative_to(folder).as_posix() for p in folder.rglob("*")
                   if p.is_file() and p.suffix in RUN_TEXT_SUFFIXES)
    first = [name for name in _RUN_FIRST if name in files]
    return first + [name for name in files if name not in first]


def read_run_file(folder: Path, relative: str | None) -> tuple[str, str | None]:
    """(text, highlighting) of one of a run's text files, with home folders shortened to ~;
    ("", None) for anything else."""
    if not relative or relative not in list_run_files(folder):
        return "", None
    text = (Path(folder) / relative).read_text(encoding="utf-8", errors="replace")
    return _cut(hide_home(text)), language_of(relative)


# --------------------------------------------------------------------------- one run's events and timing

EVENT_HEADERS = ["Time (s)", "Event", "What happened", "Fields"]
PHASES = ("model", "development checks", "hidden test", "other")
PHASE_COLORS = {"model": "#4a90d9", "development checks": "#e0b25a", "hidden test": "#3fa66b", "other": "#8a94a0"}
PHASE_TEXT = {"model": "waiting for the language model", "development checks": "compile, testbench and synthesis",
              "hidden test": "scoring with the reference test", "other": "reading and writing files, bookkeeping"}
# An event marks the end of a piece of work: the time since the previous event belongs to that work.
_PHASE_OF = {"model_replied": "model", "model_error": "model", "checks_done": "development checks",
             "testbench_checked": "development checks", "testbench_revised": "development checks",
             "testbench_revision_rejected": "development checks", "reference_scored": "hidden test"}


def load_events(folder: Path) -> list[dict]:
    """A run's events.jsonl as a list of events (unreadable lines are left out)."""
    path = Path(folder) / "events.jsonl"
    if not path.is_file():
        return []
    events = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if isinstance(event, dict) and "event" in event:
            events.append(event)
    return events


def _fields(event: dict) -> dict:
    return {k: v for k, v in event.items() if k not in ("t", "event")}


def _describe(event: dict) -> str:
    try:
        text = describe_event(event)
    except (KeyError, TypeError):  # an event written by another version of the tool
        text = None
    return text or ", ".join(f"{k}={v}" for k, v in _fields(event).items())


def event_rows(events: list[dict]) -> list[list]:
    return [[e.get("t", ""), e["event"], hide_home(_describe(e)), hide_home(json.dumps(_fields(e)))] for e in events]


def _time(event: dict, default: float) -> float:
    try:
        return float(event.get("t", default))
    except (TypeError, ValueError):
        return default


def phases(events: list[dict]) -> list[tuple[float, float, str, str]]:
    """(start, end, phase, what ended it) for each stretch of model, check or scoring time."""
    out, previous = [], 0.0
    for e in events:
        t = _time(e, previous)
        phase = _PHASE_OF.get(e["event"])
        if phase and t > previous:
            out.append((previous, t, phase, _describe(e)))
        previous = max(previous, t)
    return out


def timing_breakdown(events: list[dict]) -> dict[str, float]:
    """Seconds per phase; "other" is whatever of the run's total the three phases do not cover."""
    total = max((_time(e, 0.0) for e in events), default=0.0)
    sums = dict.fromkeys(PHASES, 0.0)
    for start, end, phase, _ in phases(events):
        sums[phase] += end - start
    sums["other"] = max(0.0, total - sum(sums[p] for p in PHASES if p != "other"))
    return {phase: round(seconds, 3) for phase, seconds in sums.items()}


def timing_markdown(events: list[dict]) -> str:
    parts = timing_breakdown(events)
    total = sum(parts.values())
    if not events or total <= 0:
        return "This run has no timed events."
    rows = ["| Phase | What it is | Seconds | Share |", "|---|---|---|---|"]
    rows += [f"| {phase} | {PHASE_TEXT[phase]} | {seconds:.2f} | {100 * seconds / total:.0f}% |"
             for phase, seconds in parts.items()]
    return ("\n".join(rows) + f"\n\nTotal {total:.2f} s, from the timestamps in this run's `events.jsonl`. "
            "The model runs on the GPU; the checks and the hidden test run Icarus Verilog and Yosys on the CPU. "
            "Drawing the page is not included.")


def timing_figure(events: list[dict]):
    """The run as one horizontal bar, coloured by phase, in time order."""
    import plotly.graph_objects as go

    fig = go.Figure()
    in_legend: set[str] = set()
    for start, end, phase, text in phases(events):
        fig.add_bar(x=[end - start], y=["run"], base=[start], orientation="h", name=phase, legendgroup=phase,
                    showlegend=phase not in in_legend, marker_color=PHASE_COLORS[phase],
                    hovertext=[f"{phase}: {end - start:.2f} s<br>{html.escape(text)}"], hoverinfo="text")
        in_legend.add(phase)
    fig.update_layout(
        barmode="overlay", height=170, margin={"l": 20, "r": 20, "t": 10, "b": 40},
        paper_bgcolor="rgba(0,0,0,0)", plot_bgcolor="rgba(0,0,0,0)", font={"color": "#8a94a0"},
        legend={"orientation": "h", "y": -0.45, "yanchor": "top", "x": 0},
        modebar={"bgcolor": "rgba(0,0,0,0)", "color": "#8a94a0"},
    )
    fig.update_xaxes(title="seconds since the run started", rangemode="tozero",
                     gridcolor="rgba(128,128,128,0.2)", zeroline=False)
    fig.update_yaxes(showticklabels=False, showgrid=False)
    return fig


# --------------------------------------------------------------------------- what the model was sent


def _strategy_folder(run: RunView) -> Path | None:
    """The templates a run used: its own saved copy, else the shipped strategy of the same name."""
    saved = run.folder / "prompts"
    if saved.is_dir():
        return saved
    name = Path(str(run.history["settings"].get("prompts", "")).replace("\\", "/")).name
    matches = [p for p in find_strategies(PROJECT_ROOT / "prompts") if p.name == name]
    return matches[0] if len(matches) == 1 else None


def _message(number: int, who: str, text: str) -> str:
    return f"===== message {number}: {who} =====\n{text.strip()}"


def conversation_text(run: RunView) -> str:
    """The messages of a run in order: what the model was sent and what it replied.
    The run stores its templates, replies and feedback; the sent messages are rebuilt from those."""
    h = run.history
    if run.origin:
        return "No model was called in this run: the design was written or edited by hand and checked like one attempt."
    folder = _strategy_folder(run)
    if folder is None:
        return ("This run did not save its prompt templates, and no strategy with the same name is in prompts/, "
                "so its messages cannot be rebuilt. Its replies are in attempt_<n>/response.md.")
    try:
        strategy = load_strategy(folder)
        spec = get_circuit(h["circuit"]).spec
    except (PromptError, CircuitError, OSError) as e:
        return f"The messages cannot be rebuilt: {e}"
    note = "" if folder == run.folder / "prompts" else (
        "(This run did not save its templates; these are today's templates of the same strategy.)\n\n")
    if strategy.workflow != "single":
        return (note + "This run used the spec_first workflow: one conversation wrote the testbench, another the "
                "design. Its templates, filled in for this circuit and with sample feedback:\n\n"
                + preview(load_draft(folder), spec))
    max_attempts = h["settings"]["max_attempts"]
    parts = [_message(1, "system", strategy.system), _message(2, "user (the task)", strategy.task_message(spec))]
    for index, a in enumerate(run.attempts):
        entry = h["attempts"][index]
        parts.append(_message(len(parts) + 1, f"assistant, attempt {a.number} ({entry.get('prompt_tokens', 0)} prompt "
                              f"tokens in, {entry.get('output_tokens', 0)} tokens out, "
                              f"{entry.get('duration_s', 0):.1f} s)", a.reply))
        if index + 1 < len(run.attempts):
            parts.append(_message(len(parts) + 1, "user (feedback from the development checks)",
                                  strategy.feedback_message(a.number, max_attempts, a.feedback)))
    return note + "\n\n".join(parts)


# --------------------------------------------------------------------------- which code runs when

# (where in the page, the control, the function it calls as "module.function", what that function does)
CALLBACKS = (
    ("Level 1", "Signed or unsigned? sliders", "learn.signed_explorer", "Reads two bit patterns both ways and compares them"),
    ("Level 1", "Adder sliders", "learn.adder_explorer", "Computes the correct adder and two faulty ones on the chosen inputs"),
    ("Level 1", "Sampling slider", "learn.sampling_figure", "Builds the waveform of a testbench that looks early or late"),
    ("Level 1", "Own checks / hidden test choice", "learn.verdict_explorer", "Explains one of the four cases"),
    ("Level 1", "Check my answers", "learn.quiz_markdown", "Grades the quiz"),
    ("Level 2", "Set up this lab", "dashboard.lab_setup", "Preselects the circuit, run or benchmark of a lab"),
    ("Level 2", "Generate & test", "dashboard.stream_run", "Runs agent.run_agent in a thread and streams its events"),
    ("Level 2", "Run and Attempt pickers", "dashboard.results_for_attempt", "Reads a saved attempt with runview.load_run"),
    ("Level 2", "Draw waveform", "dashboard.waveform_for_attempt", "Re-runs the hidden test with a VCD window and plots it"),
    ("Level 2", "Check & test (edit)", "dashboard.retest_edit", "Checks edited code like one attempt and saves a new run"),
    ("Level 2", "Benchmark picker", "dashboard.benchmark_charts", "Rebuilds the charts from each run's history.json"),
    ("Level 3", "Check & test (own design)", "dashboard.check_own_design", "Checks your design like one attempt and saves a new run"),
    ("Level 3", "Save (strategy editor)", "dashboard.editor_save", "Validates the templates and writes prompts/custom/<name>/"),
    ("Level 3", "Compare", "dashboard.compare_runs", "Derives the facts and statements of compare.py for two runs"),
    ("Level 3", "Download my evaluation", "dashboard.export_evaluation", "Writes the comparison and your notes as markdown"),
    ("Developer view", "Source file picker", "devview.read_source", "Reads one project file from a fixed list"),
    ("Developer view", "Run picker", "dashboard.developer_run", "Loads a run's events, timing, files and messages"),
)

DATA_FLOW = """
| Step | What happens | Code | Runs on |
|---|---|---|---|
| 1. Input | You choose a circuit, a strategy, a mode and a limit, or edit code | `dashboard.py` (Gradio controls and callbacks) | browser, Python |
| 2. Prompt | The templates are filled in with the circuit's description and header | `prompts.py`, `circuits.py` | Python |
| 3. Inference | The messages go to the model; text comes back with token counts | `llm.py` (Ollama or MLX over HTTP) | GPU |
| 4. Parsing | The Verilog is taken out of the reply and split into design and testbench | `llm.extract_verilog`, `devcheck.separate` | Python |
| 5. Development checks | Compile, run the testbench, synthesize, look for latches, with timeouts | `devcheck.py`, `eda.py` (Icarus Verilog, Yosys) | CPU |
| 6. Loop | Failed checks become feedback for the next model call | `agent.py` | Python |
| 7. Scoring | After the loop, the hidden reference test scores each design | `evaluate.py` | CPU |
| 8. Record | Every event and file is saved in the run folder | `agent.py` (`events.jsonl`, `history.json`) | disk |
| 9. Display | Tables, diffs, waveforms and charts are built from the run folder | `runview.py`, `waveform.py`, `benchview.py`, `compare.py` (Plotly) | Python, browser |

Nothing on the page is drawn from memory: every table, waveform and chart is rebuilt from the files of a run
folder, which is why a run can be inspected long after it was made, and without the model.
"""


def resolve_callback(name: str):
    """The function a CALLBACKS entry names."""
    module, _, attribute = name.partition(".")
    return getattr(importlib.import_module(f"vlsi_agent.{module}"), attribute)


def callbacks_markdown() -> str:
    rows = ["| Where | Control | Function | What it does |", "|---|---|---|---|"]
    rows += [f"| {where} | {control} | `{function}` | {what} |" for where, control, function, what in CALLBACKS]
    return "\n".join(rows)
