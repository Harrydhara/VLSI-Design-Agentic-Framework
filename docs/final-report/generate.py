"""Generate the final report's tables, chart data and quoted numbers from the benchmark runs.

    python docs/final-report/generate.py          # writes docs/final-report/generated/
    cd docs/final-report && latexmk -pdf report.tex

Nothing in generated/ is typed by hand: it comes from runs/bench/ through the same code
that builds docs/benchmark-report.html (docs/report/build.py), so both reports always
show the same numbers. report.tex quotes numbers with \\fact{key}; facts.tex defines them.
"""

from __future__ import annotations

import argparse
import importlib.util
import statistics
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def _load_report_builder():
    spec = importlib.util.spec_from_file_location("report_build", ROOT / "docs" / "report" / "build.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)  # it puts src/ on sys.path, so vlsi_agent imports work below
    return module


B = _load_report_builder()
from vlsi_agent.circuits import get_circuit  # noqa: E402

SPLITS = ("heldout", "dev")
KEY = {"default": "default", "tb_timing": "tbtiming", "spec_first_v1": "sfone", "spec_first": "sftwo"}  # TeX-safe


def tex(text: object) -> str:
    """Escape the few characters our labels and paths use."""
    return str(text).replace("\\", r"\textbackslash{}").replace("_", r"\_").replace("%", r"\%").replace("&", r"\&")


def pct(a: int, b: int) -> int:
    return round(100 * a / b) if b else 0


def change(first: int, final: int, text: str) -> str:
    return rf"\up{{{text}}}" if final > first else rf"\down{{{text}}}" if final < first else text


# --------------------------------------------------------------------------- data


def groups() -> dict:
    """(split, strategy) -> bench summary group, plus own-check accuracy."""
    out = {}
    for split in SPLITS:
        for strategy in B.STRATEGIES:
            g = B.summarize_group(B.rows(split, strategy), B.MAX_ATTEMPTS)
            g["rejected"], g["correct"], g["accepted"], g["wrong"] = B.accuracy(split, strategy)
            out[split, strategy] = g
    return out


def reference_checks(circuit: str, split: str) -> int | None:
    """How many checks the circuit's hidden test makes (from any scored benchmark attempt)."""
    for strategy in B.STRATEGIES:
        for seed in B.SEEDS:
            for a in B.history(split, circuit, strategy, seed)["attempts"]:
                if a["reference"] and a["reference"].get("total"):
                    return a["reference"]["total"]
    return None


# --------------------------------------------------------------------------- tables


def table_strategy(G: dict) -> str:
    lines = [r"\begin{tabular}{l rrrr c r rr}", r"\toprule",
             r"Strategy & One-shot & Iterative & Fixed & Broken & \makecell{Pass after\\1 / 2 / 3} & "
             r"\makecell{Own checks\\reject correct} & \makecell{Mean\\tokens} & \makecell{Mean\\time} \\", r"\midrule"]
    for k, split in enumerate(SPLITS):
        if k:
            lines.append(r"\midrule")
        lines.append(rf"\multicolumn{{9}}{{l}}{{\textit{{{B.SPLIT_LABEL[split]} circuits}}}} \\")
        for strategy in B.STRATEGIES:
            g = G[split, strategy]
            first, final = B.n(g["oneshot_pass"]), B.n(g["final_pass"])
            after = " / ".join(str(B.n(v)) for v in g["pass_after_attempt"].values())
            lines.append(
                rf"{tex(B.LABEL[strategy])} & {g['oneshot_pass']} & {change(first, final, g['final_pass'])} & "
                rf"{g['fixed']} & {g['broken']} & {after} & {pct(g['rejected'], g['correct'])}\% & "
                rf"{round(g['mean_tokens']):,} & {g['mean_seconds']}\,s \\")
    lines += [r"\bottomrule", r"\end{tabular}"]
    return "\n".join(lines) + "\n"


def table_circuits(split: str) -> str:
    cols = " ".join("c" for _ in B.STRATEGIES)
    head = " & ".join(tex(B.LABEL[s]) for s in B.STRATEGIES)
    lines = [rf"\begin{{tabular}}{{l {cols} r}}", r"\toprule", rf"Circuit & {head} & Median cells \\", r"\midrule"]
    for circuit in B.CIRCUITS[split]:
        cells, areas = [], []
        for strategy in B.STRATEGIES:
            rs = B.rows(split, strategy, circuit)
            g = B.summarize_group(rs, B.MAX_ATTEMPTS)
            first, final = B.n(g["oneshot_pass"]), B.n(g["final_pass"])
            text = f"{first} $\\to$ {final}" if first != final else f"{final}"
            cells.append(change(first, final, text))
            areas += [r["final_cells"] for r in rs if r["final_outcome"] == "pass" and r["final_cells"]]
        median = f"{statistics.median(areas):g}" if areas else "--"
        lines.append(rf"\texttt{{{tex(circuit)}}} & " + " & ".join(cells) + rf" & {median} \\")
    lines += [r"\bottomrule", r"\end{tabular}"]
    return "\n".join(lines) + "\n"


def table_own_checks(G: dict) -> str:
    lines = [r"\begin{tabular}{l rr rr}", r"\toprule",
             r"& \multicolumn{2}{c}{Correct designs rejected} & \multicolumn{2}{c}{Wrong designs accepted} \\",
             r"\cmidrule(lr){2-3}\cmidrule(lr){4-5}",
             r"Strategy & count & share & count & share \\", r"\midrule"]
    for k, split in enumerate(SPLITS):
        if k:
            lines.append(r"\midrule")
        lines.append(rf"\multicolumn{{5}}{{l}}{{\textit{{{B.SPLIT_LABEL[split]} circuits}}}} \\")
        for strategy in B.STRATEGIES:
            g = G[split, strategy]
            wrong = f"{g['accepted']} of {g['wrong']} & {pct(g['accepted'], g['wrong'])}\\%" if g["wrong"] else "none & --"
            lines.append(rf"{tex(B.LABEL[strategy])} & {g['rejected']} of {g['correct']} & "
                         rf"{pct(g['rejected'], g['correct'])}\% & {wrong} \\")
    lines += [r"\bottomrule", r"\end{tabular}"]
    return "\n".join(lines) + "\n"


def table_reviews() -> str:
    lines = [r"\begin{tabular}{l r rr rr}", r"\toprule",
             r"& & \multicolumn{2}{c}{Right call} & \multicolumn{2}{c}{Wrong call} \\",
             r"\cmidrule(lr){3-4}\cmidrule(lr){5-6}",
             r"Version & Reviews & \makecell{revised,\\design correct} & \makecell{kept,\\design wrong} & "
             r"\makecell{kept,\\design correct} & \makecell{revised,\\design wrong} \\", r"\midrule"]
    for k, split in enumerate(SPLITS):
        if k:
            lines.append(r"\midrule")
        lines.append(rf"\multicolumn{{6}}{{l}}{{\textit{{{B.SPLIT_LABEL[split]} circuits}}}} \\")
        for strategy in B.ROUNDS[2]:
            t = B.reviews(split, strategy)
            lines.append(rf"{tex(B.LABEL[strategy])} & {sum(t.values())} & {t['revised_correct']} & "
                         rf"{t['kept_wrong']} & {t['kept_correct']} & {t['revised_wrong']} \\")
    lines += [r"\bottomrule", r"\end{tabular}"]
    return "\n".join(lines) + "\n"


def table_circuit_list() -> str:
    lines = [r"\begin{tabular}{l l l r r}", r"\toprule",
             r"Circuit & Family & Split & \makecell{Hidden-test\\checks} & \makecell{Fixtures\\correct / faulty} \\",
             r"\midrule"]
    for split in ("dev", "heldout"):
        for circuit in B.CIRCUITS[split]:
            c = get_circuit(circuit)
            correct = sum(1 for o in c.fixtures.values() if o == "pass")
            checks = reference_checks(circuit, split)
            lines.append(rf"\texttt{{{tex(circuit)}}} & {tex(c.spec.family)} & {B.SPLIT_LABEL[split]} & "
                         rf"{checks:,} & {correct} / {len(c.fixtures) - correct} \\")
    lines += [r"\bottomrule", r"\end{tabular}"]
    return "\n".join(lines) + "\n"


# --------------------------------------------------------------------------- chart data and facts


def chart_data(G: dict) -> dict[str, str]:
    """pgfplots tables: passes after k attempts (one file per split, a column per strategy), and
    the share of correct designs the own checks rejected (a row per strategy)."""
    files = {}
    for split in SPLITS:
        lines = ["attempt," + ",".join(KEY[s] for s in B.STRATEGIES)]
        for k in range(1, B.MAX_ATTEMPTS + 1):
            lines.append(f"{k}," + ",".join(str(B.n(G[split, s]["pass_after_attempt"][k])) for s in B.STRATEGIES))
        files[f"pass-after-{split}.csv"] = "\n".join(lines) + "\n"
    own = ["strategy,label,heldout,dev"]
    for strategy in B.STRATEGIES:
        label = tex(B.LABEL[strategy]).replace(" ", "~")  # read as TeX by pgfplots
        own.append(f"{KEY[strategy]},{label}," + ",".join(
            str(pct(G[split, strategy]["rejected"], G[split, strategy]["correct"])) for split in SPLITS))
    files["own-checks.csv"] = "\n".join(own) + "\n"
    return files


def facts(G: dict) -> dict[str, object]:
    f: dict[str, object] = {}
    for (split, strategy), g in G.items():
        k = f"{split}-{KEY[strategy]}"
        f[f"{k}-oneshot"], f[f"{k}-final"] = g["oneshot_pass"], g["final_pass"]
        f[f"{k}-fixed"], f[f"{k}-broken"] = g["fixed"], g["broken"]
        f[f"{k}-rejected"] = f"{pct(g['rejected'], g['correct'])}\\%"
        f[f"{k}-tokens"] = f"{round(g['mean_tokens']):,}"
    finals = []
    for strategy in B.STRATEGIES:
        both = [G[split, strategy] for split in SPLITS]
        finals.append(sum(B.n(g["final_pass"]) for g in both))
        f[f"both-{KEY[strategy]}-oneshot"] = f"{sum(B.n(g['oneshot_pass']) for g in both)}/50"
        f[f"both-{KEY[strategy]}-final"] = f"{finals[-1]}/50"
    f["both-final-range"] = f"{min(finals)}--{max(finals)}/50"
    for split in SPLITS:
        shares = [pct(G[split, s]["rejected"], G[split, s]["correct"]) for s in B.STRATEGIES]
        f[f"{split}-rejected-range"] = f"{min(shares)}--{max(shares)}\\%"
    f["runs"] = sum(g["runs"] for g in G.values())
    f["fixed"] = sum(g["fixed"] for g in G.values())
    f["broken"] = sum(g["broken"] for g in G.values())
    circuits = [c for split in SPLITS for c in B.CIRCUITS[split]]
    fixtures = [get_circuit(c).fixtures for c in circuits]
    f["circuits"] = len(circuits)
    f["fixtures"] = sum(len(x) for x in fixtures)
    f["fixtures-correct"] = sum(1 for x in fixtures for o in x.values() if o == "pass")
    f["seeds"] = f"{min(B.SEEDS)}--{max(B.SEEDS)}"
    f["max-attempts"] = B.MAX_ATTEMPTS
    settings = B.history("heldout", B.CIRCUITS["heldout"][0], "default", min(B.SEEDS))["settings"]
    f["model"] = tex(settings["model"].removeprefix("ollama:"))
    f["temperature"] = settings["temperature"]
    f["budget"] = f"{settings['max_total_tokens']:,}"
    return f


def facts_tex(f: dict[str, object]) -> str:
    lines = ["% Generated by generate.py from runs/bench/. Use \\fact{key} in report.tex.",
             r"\makeatletter"]
    lines += [rf"\expandafter\def\csname fact@{k}\endcsname{{{v}}}" for k, v in sorted(f.items())]
    lines += [r"\makeatother", ""]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=HERE / "generated")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    G = groups()
    files = {
        "table-strategy.tex": table_strategy(G),
        "table-circuits-heldout.tex": table_circuits("heldout"),
        "table-circuits-dev.tex": table_circuits("dev"),
        "table-own-checks.tex": table_own_checks(G),
        "table-reviews.tex": table_reviews(),
        "table-circuit-list.tex": table_circuit_list(),
        "facts.tex": facts_tex(facts(G)),
        **chart_data(G),
        **{f"prompt-{p.name}": p.read_text(encoding="utf-8") for p in sorted((ROOT / "prompts" / "default").glob("*.txt"))},
    }
    for name, text in files.items():
        (args.out / name).write_text(text, encoding="utf-8", newline="\n")
    print(f"wrote {len(files)} files to {args.out}")


if __name__ == "__main__":
    main()
