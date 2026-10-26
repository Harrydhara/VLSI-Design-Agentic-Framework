# Citation check for the final report's related work

Every statement in Section 2 of `report.tex` that cites a paper was checked against
that paper's own full text, not against summaries or other papers' descriptions of
it. This file records what was read and where each claim appears, so anyone can
re-check it. Claims are paraphrased here, as in the report.

**How it was checked (2026-10-21):**
- **Paper text:** the arXiv HTML full text of the version listed below.
- **Title, authors and year:** the arXiv API.
- **Venue, pages and DOI:** Crossref (`api.crossref.org/works`, title search), except where noted.
- **arXiv-only papers:** two have no published version in Crossref, so the report cites them as arXiv preprints.

| Key | Paper | Venue, and how it was confirmed | Text read |
|---|---|---|---|
| thakur2023 | Thakur et al., Benchmarking LLMs for automated Verilog RTL code generation | DATE 2023, pp. 1–6, DOI 10.23919/DATE56975.2023.10137086 (Crossref) | arXiv 2212.11140v1 |
| verilogeval | Liu, Pinckney, Khailany, Ren, VerilogEval | ICCAD 2023 (invited), pp. 1–8, DOI 10.1109/ICCAD57390.2023.10323812 (Crossref) | arXiv 2309.07544v2 |
| revisiting | Pinckney et al., Revisiting VerilogEval | ACM TODAES 30(6), 2025, pp. 1–20, DOI 10.1145/3718088 (Crossref) | arXiv 2408.11053v2, abstract |
| rtllm | Lu, Liu, Zhang, Xie, RTLLM | ASP-DAC 2024, pp. 722–727, DOI 10.1109/ASP-DAC58780.2024.10473904 (Crossref) | arXiv 2308.05345v3 |
| chipchat | Blocklove, Garg, Karri, Pearce, Chip-Chat | MLCAD 2023, pp. 1–6, DOI 10.1109/MLCAD58807.2023.10299874 (Crossref) | arXiv 2305.13243v2 |
| autochip | Thakur et al., AutoChip | arXiv preprint only (see note 1) | arXiv 2311.04887v2 |
| rtlfixer | Tsai, Liu, Ren, RTLFixer | DAC 2024, pp. 1–6, DOI 10.1145/3649329.3657353 (Crossref; published title says "Large Language Model") | arXiv 2311.16543v3, abstract |
| verilogcoder | Ho, Ren, Khailany, VerilogCoder | AAAI 2025, vol. 39 no. 1, pp. 300–307, DOI 10.1609/aaai.v39i1.32007 (Crossref) | arXiv 2408.08927v2 |
| mage | Zhao et al., MAGE | DAC 2025, pp. 1–7, DOI 10.1109/DAC63849.2025.11133191 (Crossref) | arXiv 2412.07822v1 |
| autobench | Qiu et al., AutoBench | MLCAD 2024, pp. 1–10, DOI 10.1145/3670474.3685956 (Crossref) | arXiv 2407.03891v2 |
| selfrefine | Madaan et al., Self-Refine | NeurIPS 2023, Advances in NeurIPS 36 (proceedings.neurips.cc listing) | arXiv 2303.17651v2, abstract |
| huang2024 | Huang et al., LLMs cannot self-correct reasoning yet | ICLR 2024 (arXiv comment by the authors; ML Anthology entry) | arXiv 2310.01798v2, abstract |
| rtlcoder | Liu et al., RTLCoder | IEEE LAD 2024, pp. 1–5, DOI 10.1109/LAD62341.2024.10691788 (Crossref; arXiv v5 is this version) | arXiv 2312.08617v5 |
| chipnemo | Liu et al., ChipNeMo | arXiv preprint only (not found in Crossref) | arXiv 2311.00176v5, abstract |

**Note 1, AutoChip.** The v2 PDF carries the ACM template header for DAC '24, but its DOI field is
still the template placeholder and Crossref has no DAC '24 entry for it, so the report cites the
preprint. A later follow-up by some of the same authors (arXiv 2411.11856) has a different title
and is not cited.

## Claims and where they appear

**Thakur et al. (DATE 2023)**
- Fine-tuned open models on Verilog from GitHub and from textbooks: abstract; §III-A.
- Tested with testbenches on 17 problems, each with a difficulty level: abstract; §IV-A.
- The fine-tuned CodeGen-16B did best, and outperformed Codex on functional correctness: abstract; §I, the outline of the paper.

**VerilogEval (ICCAD 2023)**
- 156 problems from HDLBits: abstract; §I.
- Text descriptions in two sets:
  - one generated with gpt-3.5-turbo (VerilogEval-machine): §II-B1, Fig. 3;
  - one converted by hand (VerilogEval-human): §II-B2.
- Correctness is decided by comparing simulation outputs with a golden solution: abstract; §II-C.
- The simulator is Icarus Verilog: §II-C.
- The metric is pass@k: §II-D.

**Revisiting VerilogEval (TODAES 2025)**
- Extends the tasks to specification-to-RTL and classifies failures automatically: abstract.

**RTLLM (ASP-DAC 2024)**
- 30 designs (11 arithmetic, 19 logic): §I; §III-C.
- Each design comes with a description, a testbench and a hand-written reference design: §III-B.
- Three goals: syntax, then functionality, then design quality as power, performance and area after synthesis: abstract; §III-A.

**Chip-Chat (MLCAD 2023)**
- An experienced engineer worked with ChatGPT-4 to design an 8-bit accumulator-based processor: abstract; §III-A, §III-B.
- The processor was taped out on a Skywater 130 nm shuttle: abstract.
- The engineer steered the model and verified its output, including authoring the testbenches: §III-B, the paragraph on partitioning.

**AutoChip (arXiv 2311.04887v2)**
- Each candidate is compiled with Icarus Verilog and simulated with the testbench that comes with the problem (replicas of HDLBits' testbenches): §3; §4, "Verilog Testbenches".
- Compiler and simulator output goes back to the model until all tests pass or the iteration limit is reached: §1; §3.
- Feedback from the most recent iteration only gave 24.2% more functionally correct code than no feedback: §1; §7.
- The feedback testbench is also the one that decides success: §3 (the loop exits when compilation and simulation pass); §7 (the success rate is measured against the functional testbenches).
- Problems asking for a testbench fared worst, with none of the generated code compiling: §6.

**RTLFixer (DAC 2024)**
- About 55% of errors in LLM-written Verilog are syntax errors: abstract.
- With retrieval-augmented generation and ReAct prompting it fixed about 98.5% of the compilation errors in its dataset (212 erroneous implementations from VerilogEval): abstract.

**VerilogCoder (AAAI 2025)**
- Plans the module as a task dependency graph whose sub-tasks go to agents: abstract; "VerilogCoder", "Flow Overview".
- The debug agent uses a simulator and an AST-based waveform tracer that walks back from a mismatched signal: "Verilog Tools"; "Debug Agent".
- The debug agent revises until the code passes a provided testbench: "Flow Overview"; "Debug Agent".
- 94.2% on VerilogEval-Human v2 with GPT-4 Turbo: abstract; "Main Results".

**MAGE (DAC 2025)**
- Samples candidates at high temperature and scores them in simulation: abstract; §III-B.
- Debugs with state checkpoints that locate the earliest mismatch: abstract; §III-C.
- A testbench agent writes the testbench from the specification, combined with the golden testbench when one is available: §III-A, step 1.
- A judge agent regenerates the testbench if it judges the testbench incorrect: §III-A, step 3.
- 95.7% on VerilogEval-Human v2 with Claude 3.5 Sonnet: abstract; §IV-A.
- MAGE's reference [21] for v2 is Pinckney et al.

**AutoBench (MLCAD 2024)**
- Generating testbenches directly with an LLM has a low pass rate: abstract.
- A generated testbench passes the preliminary-correctness criterion (Eval1) only if it reports no errors with the golden RTL as the design under test: §4; Table 2.

**Self-Refine (NeurIPS 2023)**
- One model generates, critiques and refines its own output: abstract.
- About 20% absolute average improvement over one-step generation, across 7 tasks: abstract.

**Huang et al. (ICLR 2024)**
- Without external feedback, LLMs struggle to self-correct their reasoning, and sometimes do worse after trying: abstract.

**RTLCoder (LAD 2024)**
- A 7B model that beats GPT-3.5 on the RTL benchmarks it evaluates: abstract.
- The training set has more than 27,000 instruction–code samples, generated with GPT-3.5: §II-C.
- Commercial tools raise privacy concerns because every instruction is uploaded to the provider, and a local open model removes them: §I.

**ChipNeMo (arXiv 2311.00176)**
- Adapts LLaMA2 models with domain-adaptive tokenization, continued pretraining, alignment and a domain-adapted retrieval model: abstract.
- Evaluated as an engineering assistant chatbot, for EDA script generation and for bug summarization: abstract.
