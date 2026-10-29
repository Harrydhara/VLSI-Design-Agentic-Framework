"""Talk to the language model: real clients for Ollama and MLX, and a scripted fake for tests.

All implement the same small interface, `complete(messages) -> Completion`, so agent
code never needs to know which one it has. `make_llm` picks the real client that the
config's [llm] backend names. FakeLLM makes agent logic (attempt limits, token budgets,
feedback handling) testable without a GPU, with exact, repeatable answers.
"""

from __future__ import annotations

import json
import math
import re
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Protocol, Sequence

from vlsi_agent.config import LLMConfig

ROLES = ("system", "user", "assistant")


class LLMError(RuntimeError):
    """The model produced no answer: server unreachable, unknown model, timeout, bad reply."""


@dataclass(frozen=True)
class Message:
    role: str  # "system", "user" or "assistant"
    content: str

    def __post_init__(self) -> None:
        if self.role not in ROLES:
            raise ValueError(f"role must be one of {ROLES}, got {self.role!r}")


@dataclass(frozen=True)
class Completion:
    text: str
    model: str
    prompt_tokens: int
    output_tokens: int  # includes the thinking tokens when thinking is on
    duration_s: float
    truncated: bool  # stopped at max_output_tokens before the model finished
    thinking: str = ""

    @property
    def total_tokens(self) -> int:
        return self.prompt_tokens + self.output_tokens


class LLM(Protocol):
    name: str

    def complete(self, messages: Sequence[Message]) -> Completion: ...


def estimate_tokens(text: str) -> int:
    """Rough, deterministic token count (about 4 characters per token)."""
    return math.ceil(len(text) / 4)


# --------------------------------------------------------------------------- HTTP

OLLAMA_HINT = ("is the Ollama app running? Try: ollama list" if sys.platform == "darwin"
               else "is it running? Try: systemctl status ollama")


def _http_error_text(e: urllib.error.HTTPError) -> str:
    body = e.read().decode(errors="replace")
    try:
        error = json.loads(body)["error"]
    except (ValueError, KeyError, TypeError):
        return body.strip()[:200] or e.reason
    # OpenAI-style servers send {"error": {"message": ...}}, Ollama and mlx_lm send {"error": "..."}
    return str(error.get("message", error) if isinstance(error, dict) else error)


def _post_json(base_url: str, path: str, payload: dict, timeout_s: float, server: str, hint: str) -> dict:
    """POST a JSON request and return the JSON reply; every failure becomes an LLMError."""
    base_url = base_url.rstrip("/")
    request = urllib.request.Request(base_url + path, data=json.dumps(payload).encode(),
                                     headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=timeout_s) as response:
            return json.load(response)
    except urllib.error.HTTPError as e:
        raise LLMError(f"{server} returned HTTP {e.code}: {_http_error_text(e)}") from None
    except urllib.error.URLError as e:
        if isinstance(e.reason, TimeoutError):
            raise LLMError(f"no answer from {server} within {timeout_s:g} s") from None
        raise LLMError(f"cannot reach {server} at {base_url} ({e.reason}); {hint}") from None
    except TimeoutError:
        raise LLMError(f"no answer from {server} within {timeout_s:g} s") from None
    except ValueError:
        raise LLMError(f"{server} sent a reply that is not valid JSON") from None


# --------------------------------------------------------------------------- Ollama


class OllamaLLM:
    """Client for Ollama's /api/chat endpoint (non-streaming)."""

    def __init__(self, config: LLMConfig):
        self.config = config
        self.name = f"ollama:{config.model}"

    def payload(self, messages: Sequence[Message]) -> dict:
        c = self.config
        return {
            "model": c.model,
            "messages": [{"role": m.role, "content": m.content} for m in messages],
            "stream": False,
            "think": c.think,
            "keep_alive": c.keep_alive,
            "options": {"temperature": c.temperature, "seed": c.seed, "num_predict": c.max_output_tokens},
        }

    def complete(self, messages: Sequence[Message]) -> Completion:
        if not messages:
            raise ValueError("no messages to send")
        c = self.config
        start = time.monotonic()
        data = _post_json(c.base_url, "/api/chat", self.payload(messages), c.request_timeout_s, "Ollama", OLLAMA_HINT)
        if "error" in data:
            raise LLMError(f"Ollama error: {data['error']}")
        message = data.get("message") or {}
        return Completion(
            text=message.get("content") or "",
            model=data.get("model", c.model),
            prompt_tokens=int(data.get("prompt_eval_count", 0)),
            output_tokens=int(data.get("eval_count", 0)),
            duration_s=time.monotonic() - start,
            truncated=data.get("done_reason") == "length",
            thinking=message.get("thinking") or "",
        )


# --------------------------------------------------------------------------- MLX


class MLXLLM:
    """Client for mlx_lm.server (Apple silicon), through its OpenAI-style /v1/chat/completions.

    Start the server first, with the same model as [llm] model:
        mlx_lm.server --model mlx-community/gemma-4-26b-a4b-it-4bit --port 8080
    The server keeps its model loaded while it runs, so [llm] keep_alive is not used.
    """

    def __init__(self, config: LLMConfig):
        self.config = config
        self.name = f"mlx:{config.model}"

    def payload(self, messages: Sequence[Message]) -> dict:
        c = self.config
        return {
            "model": c.model,
            "messages": [{"role": m.role, "content": m.content} for m in messages],
            "stream": False,
            "temperature": c.temperature,
            "seed": c.seed,
            "max_tokens": c.max_output_tokens,
            # Gemma 4 and Qwen 3 chat templates switch reasoning on and off with this flag.
            "chat_template_kwargs": {"enable_thinking": c.think},
        }

    def complete(self, messages: Sequence[Message]) -> Completion:
        if not messages:
            raise ValueError("no messages to send")
        c = self.config
        start = time.monotonic()
        data = _post_json(c.base_url, "/v1/chat/completions", self.payload(messages), c.request_timeout_s,
                          "the MLX server",
                          f"is it running? Start it with: mlx_lm.server --model {c.model} --port 8080")
        if "error" in data:
            raise LLMError(f"MLX server error: {data['error']}")
        try:
            choice = data["choices"][0]
        except (KeyError, IndexError, TypeError):
            raise LLMError("the MLX server sent a reply without choices") from None
        message = choice.get("message") or {}
        usage = data.get("usage") or {}
        return Completion(
            text=message.get("content") or "",
            model=data.get("model", c.model),
            prompt_tokens=int(usage.get("prompt_tokens", 0)),
            output_tokens=int(usage.get("completion_tokens", 0)),
            duration_s=time.monotonic() - start,
            truncated=choice.get("finish_reason") == "length",
            thinking=message.get("reasoning") or "",
        )


BACKEND_NAMES = {"ollama": "Ollama", "mlx": "MLX"}


def make_llm(config: LLMConfig) -> LLM:
    """The real client for the config's [llm] backend."""
    return MLXLLM(config) if config.backend == "mlx" else OllamaLLM(config)


# --------------------------------------------------------------------------- fake


class FakeLLM:
    """Scripted model for tests: returns the given responses in order, one per call.

    Each call's messages are recorded in `calls`, so a test can check exactly what the
    agent sent. A call with no scripted response left raises LLMError, so an
    unexpected extra call fails loudly. A response can be a plain string (token counts
    are estimated) or a full Completion (to script truncation or exact token counts).
    """

    name = "fake"

    def __init__(self, responses: Sequence[str | Completion]):
        self.responses = list(responses)
        self.calls: list[tuple[Message, ...]] = []

    def complete(self, messages: Sequence[Message]) -> Completion:
        if not messages:
            raise ValueError("no messages to send")
        if len(self.calls) >= len(self.responses):
            raise LLMError(f"FakeLLM has no scripted response for call {len(self.calls) + 1} "
                           f"(only {len(self.responses)} scripted)")
        self.calls.append(tuple(messages))
        item = self.responses[len(self.calls) - 1]
        if isinstance(item, Completion):
            return item
        prompt = "".join(m.content for m in messages)
        return Completion(item, "fake", estimate_tokens(prompt), estimate_tokens(item), 0.0, False)


# --------------------------------------------------------------------------- parsing

_FENCED = re.compile(r"```[^\n]*\n(.*?)```", re.DOTALL)
_HAS_MODULE = re.compile(r"\bmodule\b")
_MODULE_SPAN = re.compile(r"\bmodule\b.*\bendmodule\b", re.DOTALL)


def extract_verilog(text: str) -> str | None:
    """Pull Verilog source out of a model reply, or return None if it has no module.

    Every fenced code block that contains a module is kept and they are joined, since
    models often put helper modules in separate blocks. Without fences, the text from
    the first `module` to the last `endmodule` is used. If the reply was cut off inside
    a code block, the partial code is returned so compiling it gives a useful error.
    """
    blocks = [b.strip() for b in _FENCED.findall(text) if _HAS_MODULE.search(b)]
    if blocks:
        return "\n\n".join(blocks) + "\n"
    if text.count("```") % 2 == 1:  # odd number of fences: the last code block was cut off
        tail = text.rsplit("```", 1)[1].partition("\n")[2]
        if _HAS_MODULE.search(tail):
            return tail.strip() + "\n"
    span = _MODULE_SPAN.search(text)
    return span.group(0).strip() + "\n" if span else None
