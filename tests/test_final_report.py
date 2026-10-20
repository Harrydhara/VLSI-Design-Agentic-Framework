import importlib.util
import re

import pytest

from vlsi_agent.benchview import load_benchmark
from vlsi_agent.config import PROJECT_ROOT

REPORT = PROJECT_ROOT / "docs" / "final-report"
BENCH = PROJECT_ROOT / "runs" / "bench"
pytestmark = pytest.mark.skipif(
    not (REPORT / "generate.py").is_file() or not (BENCH / "heldout-seeds1-5").is_dir()
    or not (BENCH / "dev-seeds1-5").is_dir(),
    reason="needs docs/final-report and the benchmark runs (not in the Docker image)")


@pytest.fixture(scope="module")
def generated(tmp_path_factory):
    spec = importlib.util.spec_from_file_location("final_report_generate", REPORT / "generate.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    out = tmp_path_factory.mktemp("generated")
    G = module.groups()
    files = {
        "facts.tex": module.facts_tex(module.facts(G)),
        "table-strategy.tex": module.table_strategy(G),
        **module.chart_data(G),
    }
    for name, text in files.items():
        (out / name).write_text(text, encoding="utf-8")
    return module, G, out


def facts_in(text: str) -> dict[str, str]:
    return dict(re.findall(r"\\csname fact@(.+?)\\endcsname\{(.*)\}", text))


def test_every_fact_the_report_quotes_is_generated(generated):
    _, _, out = generated
    defined = facts_in((out / "facts.tex").read_text())
    source = re.sub(r"(?<!\\)%.*", "", (REPORT / "report.tex").read_text(encoding="utf-8"))  # drop comments
    used = set(re.findall(r"\\fact\{([^}]+)\}", source))
    assert used and used <= set(defined), sorted(used - set(defined))


def test_every_generated_file_the_report_reads_is_committed():
    text = (REPORT / "report.tex").read_text(encoding="utf-8")
    names = set(re.findall(r"generated/([\w.-]+?\.(?:tex|csv|txt))", text))
    names |= {f"pass-after-{split}.csv" for split in ("heldout", "dev")}  # named through \foreach
    missing = sorted(n for n in names if not (REPORT / "generated" / n).is_file())
    assert not missing, f"run docs/final-report/generate.py: {missing}"


def test_numbers_agree_with_the_dashboards_benchmark_view(generated):
    module, G, _ = generated
    for split, folder in (("heldout", "heldout-seeds1-5"), ("dev", "dev-seeds1-5")):
        view = load_benchmark(BENCH / folder)
        for strategy in module.B.STRATEGIES:
            other = view.group(strategy=strategy)
            mine = G[split, strategy]
            assert (mine["oneshot_pass"], mine["final_pass"], mine["fixed"], mine["broken"]) == (
                other["oneshot_pass"], other["final_pass"], other["fixed"], other["broken"]), (split, strategy)
            rows = view.pick(strategy=strategy)
            assert mine["rejected"] == sum(r["correct_rejected"] for r in rows)
            assert mine["correct"] == sum(r["correct"] for r in rows)


def test_headline_facts(generated):
    _, _, out = generated
    f = facts_in((out / "facts.tex").read_text())
    assert f["runs"] == "200" and f["circuits"] == "10"
    assert int(f["fixed"]) + int(f["broken"]) > 0
    assert re.fullmatch(r"\d+--\d+\\%", f["heldout-rejected-range"])
    rows = [l for l in (out / "table-strategy.tex").read_text().splitlines() if l.rstrip().endswith(r"\\")]
    assert len(rows) == 1 + 2 + 2 * 4  # header, two split labels, one row per strategy and split
    assert all(line.count("/25") == 2 for line in rows if line.startswith(("default", "tb", "spec")))
