# macllm — Install & Optimize a Local LLM on your Mac (Apple Silicon)

**One command sets up a fast, private, offline AI model on your Mac.** `macllm` is
a [Claude Code](https://claude.com/claude-code) skill that detects your Apple
Silicon Mac (M1–M5), researches the best local LLM for your RAM *today*, installs
it, and applies every known Apple-Silicon speed optimization — MLX, 4-bit
quantization, thinking-off, keep-alive, and headless auto-start — then benchmarks
the result.

No subscription. No API keys. No data leaving your machine.

![Local LLM running in LM Studio on an Apple M5 Pro at ~99 tokens per second using an MLX 4-bit model](assets/lmstudio-running.png)

*A 35B model answering at ~99 tokens/sec on a 64 GB M5 Pro — MLX 4-bit, thinking off.*

---

## What is macllm?

macllm is a guided, permission-first installer and tuner for running large language
models locally on a Mac. Instead of guessing which model to download or how to make
it fast, the skill:

1. **Reads your Mac** — chip, RAM, macOS, and what's already installed.
2. **Researches the current best model** for your memory tier (rankings change every
   month, so it searches live rather than trusting a stale list).
3. **Asks before installing anything** — you approve the backend, the model, and the
   download size.
4. **Installs** via LM Studio (MLX, fastest on Apple Silicon) or Ollama.
5. **Optimizes** — the part most guides skip.
6. **Auto-starts** the model server so it's always ready.
7. **Benchmarks** and reports the real tokens/sec.

## Who is this for?

- Anyone who wants a **private, offline ChatGPT alternative** on a Mac.
- Developers wiring a **local model into an editor** (Continue, Cline) or scripts.
- People with **sensitive data** (legal, medical, financial) that shouldn't hit a cloud API.
- Anyone who downloaded a local model, found it **slow**, and wants it tuned properly.

---

## Quick start

> Requires [Claude Code](https://claude.com/claude-code) and an Apple Silicon Mac.

```bash
# 1. Add the skill to your Claude Code skills directory
git clone https://github.com/gwaghmar/macllm.git ~/.claude/skills/macllm

# 2. In Claude Code, run:
/macllm
```

Claude will profile your Mac, propose the best model, and walk you through the rest.

**Prefer to do it by hand?** The scripts work standalone:

```bash
bash scripts/detect-hardware.sh                       # profile your Mac
bash scripts/benchmark.sh lmstudio qwen/qwen3.6-35b-a3b   # measure tok/s
```

---

## How it works

```mermaid
flowchart TD
    A[Run /macllm] --> B[Phase 1: Detect Mac<br/>chip · RAM · installed backends]
    B --> C[Phase 2: Research best model<br/>live web search for your RAM tier]
    C --> D{Phase 3: Ask permission<br/>backend · model · download size}
    D -->|approved| E[Phase 4: Install<br/>LM Studio MLX or Ollama]
    D -->|declined| X[Stop — nothing installed]
    E --> F[Phase 5: Optimize]
    F --> G[Phase 6: Auto-start<br/>headless server on login]
    G --> H[Phase 7: Benchmark<br/>report real tokens/sec]
```

### The optimization phase, in detail

Each of these reduces bytes-read-per-token or uses memory bandwidth better — the
two things that actually govern speed on a Mac.

```mermaid
flowchart LR
    subgraph choice[Model choice]
      M1[MoE, few active params] --> M2[4-bit quant] --> M3[MLX build]
    end
    subgraph runtime[Runtime]
      R1[Thinking OFF by default] --> R2[Keep model loaded]
      R2 --> R3[Context length 16k]
      R3 --> R4[Flash attn + KV q8<br/>long context]
    end
    subgraph verify[Verify]
      V1[Speculative decoding?<br/>benchmark — keep only if it helps]
    end
    choice --> runtime --> verify
```

---

## Why local models are slow — and how macllm fixes it

On Apple Silicon there is one governing equation:

> **generation speed ≈ memory bandwidth ÷ bytes read per token**

Everything macllm does follows from it:

| Optimization | What it does | Why it's faster |
|---|---|---|
| **MoE model** (few active params) | Reads only the active experts per token | 10× fewer bytes than a dense model of the same total size |
| **4-bit quantization** | Compresses the weights | ~½ the bytes of 8-bit, ~2× the speed, negligible quality loss |
| **MLX runtime** | Apple's native ML framework | 10–30% faster than GGUF/llama.cpp on M-series |
| **Thinking off** | Skips the hidden reasoning monologue | Most of the *perceived* latency, gone |
| **Keep-alive** | Model stays in memory | Kills the 10–20 s cold-start reload |
| **Context 16k** | Right-sized KV cache | A bloated context window slows every token |

### What does NOT make it faster (myths this skill debunks)

- **"Use a smaller model."** On a Mac, a much smaller *dense* model often runs at the
  *same* tokens/sec as a good MoE — same bytes-per-token — while being far dumber.
  Shrink only to fit memory, never for speed.
- **"Speculative decoding always helps."** Sometimes 1.5–2×, often unsupported for
  MLX and worth exactly nothing. macllm benchmarks it and keeps it only if it helps.

---

## Best local LLM for your Mac (by RAM)

Rankings change monthly — the skill searches live — but as a rule of thumb:

| Mac RAM | Model class | Typical use |
|---|---|---|
| 8 GB | 3–4B dense, 4-bit | Basic chat, autocomplete |
| 16 GB | 7–9B dense, 4-bit | Solid everyday assistant |
| 24–32 GB | 27–32B dense or ~30B MoE, 4-bit | Strong reasoning, coding |
| 64 GB | ~35B MoE (few active), 4-bit MLX | Fast daily driver + private RAG |
| 128 GB+ | 70B dense or large MoE | Near-frontier local quality |

---

## Optimized, always-on setup

macllm enables LM Studio's headless server so your model is ready at
`http://localhost:1234/v1` the moment you log in — no app window required — and sets
the idle timeout high so it never reloads mid-session.

![LM Studio Developer settings showing the headless Local LLM Service enabled and a 1440-minute model idle timeout](assets/optimized-settings.png)

*Headless Local LLM Service on; model idle timeout raised to 24 hours.*

---

## Using your local model

Once installed, point any OpenAI-compatible tool at the local server:

| Backend | Base URL | Example model id |
|---|---|---|
| LM Studio | `http://localhost:1234/v1` | `qwen/qwen3.6-35b-a3b` |
| Ollama | `http://localhost:11434/v1` | `qwen3.6:35b-a3b` |

- **Chat UI:** open the LM Studio app and type, like ChatGPT.
- **In your editor:** point Continue or Cline at the base URL above.
- **Agentic coding (file writes, running commands):** point
  [OpenCode](https://opencode.ai) at the local server — see below.
- **Private document Q&A / RAG:** run [Open WebUI](https://docs.openwebui.com/) on
  top of the local server for a full ChatGPT-style interface with file upload.
- **Turn thinking off** for instant answers: send `"reasoning_effort": "none"` in the
  API request, or toggle the **Think** button off in the LM Studio chat.

---

## Using it with OpenCode

A raw chat UI can only *describe* a file or a shell command — it can't create or run
one. [OpenCode](https://opencode.ai) is the agent harness: it gives the model tools
(write files, run shell commands, edit code) and executes what the model calls. The
model your `qwen3.6-35b-a3b` MLX build ships with `tool_use` capability, so it works
out of the box.

```bash
brew install opencode
```

Add the local server as a custom provider in `~/.config/opencode/opencode.jsonc`:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "model": "lmstudio/qwen/qwen3.6-35b-a3b",
  "provider": {
    "lmstudio": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "LM Studio (local)",
      "options": {
        "baseURL": "http://localhost:1234/v1"
      },
      "models": {
        "qwen/qwen3.6-35b-a3b": {
          "name": "Qwen 3.6 35B A3B",
          "options": {
            "temperature": 0.3,
            "top_p": 0.9
          }
        }
      }
    }
  }
}
```

The `"model"` key makes it the default so you don't need `--model` on every run.
LM Studio's server has to be running (Phase 6, headless mode) for this to work.

The `temperature`/`top_p` override matters more than it looks — see the benchmark
below. OpenCode's own default is `top_p: 1` (fully open sampling), but Qwen's
docs and community coding benchmarks recommend a tighter `temperature 0.1–0.3,
top_p ~0.9` for agentic/tool-calling accuracy. In testing this made the model
reliably reach for the correct built-in tool on the first try instead of
improvising with shell commands.

```bash
# One-off task
opencode run "create hello.py that prints hello world, then run it"

# Interactive
opencode
```

For an Ollama backend instead, swap the `baseURL` to
`http://localhost:11434/v1` and the model id to your `ollama pull`'d tag.

Also drop an `AGENTS.md` in your project root with any environment quirks the
model should know up front (e.g. "this is macOS — `grep` has no `-P`, use
`sed -E` or Python instead"). OpenCode reads it automatically as project
context. A starter is bundled at
[`templates/AGENTS.md.example`](templates/AGENTS.md.example) — copy it in and
extend it with your own project's quirks. In testing this didn't reliably fix
retries by itself (see below) — local models don't always follow it
consistently run to run — but it's free and occasionally helps, so there's no
reason to skip it.

### Can it search the internet through OpenCode?

Sort of, not really. OpenCode gives the model a `WebFetch` tool that retrieves
a URL you (or the model) already knows — there's no Google/Bing-style search
behind it. So it can read a page, it can't discover one. If you need "search
the web for X," pair OpenCode with an MCP server that provides real search
(e.g. a Brave/Tavily search MCP) — macllm doesn't set this up for you.

### Real numbers — tested on a 64 GB M5 Pro, `qwen/qwen3.6-35b-a3b` MLX 4-bit

**Task 1 — fetch a live URL** ("get the current HN top story title and save it
to a file"):

| Run | Sampling | Result | Tool calls | Wall time |
|---|---|---|---|---|
| 1 (baseline) | `top_p: 1` (OpenCode default) | ✅ correct, but improvised with `curl`/`grep`, hit BSD-vs-GNU `grep -P` failure | 6 | 68.3s |
| 2 (+ `AGENTS.md` hint) | `top_p: 1` | ✅ correct, different bug this time (Python typo), hint didn't get used | 4 | 66.9s |
| 3 (+ tuned sampling) | `temperature: 0.3, top_p: 0.9` | ✅ correct, went straight to the built-in `WebFetch` tool | **1** | **38.8s** |

Sampling tuning was the variable that actually mattered here — not the prompt
hint. Small sample size (one task, one seed each), so treat this as a
directional signal, not a statistically rigorous benchmark.

**Task 2 — genuinely hard coding task:** implement a thread-safe LRU cache with
per-key TTL eviction (stdlib only, O(1) ops), write pytest coverage for basic
ops/LRU order/TTL expiry/thread-safety, run the tests, fix whatever's broken.

- **Total wall time: 5m 18s** (CPU time only ~35s of that — most of the wall
  clock was model inference between tool calls, not execution)
- **Tool calls:** 2 file writes, 4 edits, ~11 shell calls, 1 read
- **Test iterations:** 19 failed / 12 passed → 2 failed / 29 passed → **31 / 31
  passed**
- **Real bugs found and fixed**, not just retried:
  1. `delete()` wasn't checking TTL, so expired keys were deletable and
     returned `True` incorrectly.
  2. Eviction only cleared one expired entry per `put()` instead of all of
     them, leaving stale entries when the cache was full of expired data.
  3. Called `OrderedDict.first_key()`, which doesn't exist — self-corrected to
     `next(iter(self._cache))`.
- **Friction point worth knowing about:** it burned real time (~5 tool calls)
  fighting `pip install pytest` on a `uv`-managed macOS Python — hit PEP 668's
  "externally managed environment" error, then several failed attempts before
  landing on `uv venv .venv && uv pip install pytest -p .venv/bin/python`. If
  your Mac uses `uv` for Python, expect this exact stumble; putting a note in
  `AGENTS.md` about how to install packages in your environment removes it.

**Bottom line:** it gets to a fully correct, fully tested result — but expect
5x-ish wall-clock overhead versus a hosted frontier model on anything nontrivial,
mostly from inference latency between tool calls and from environment-specific
trial and error it has to discover itself. Tuning `temperature`/`top_p` and
giving it environment context up front (`AGENTS.md`) both help; neither closes
the gap entirely.

**Note:** local models — even good ones — are less reliable at multi-step tool use
than frontier hosted models. Expect more retries on longer agentic tasks; this is a
model-capability limit, not a config problem.

---

## FAQ

### What is the best local LLM for a Mac in 2026?
It depends on your RAM. On 64 GB Apple Silicon, a ~35B mixture-of-experts model with
few active parameters, in a 4-bit MLX build, is the current sweet spot — near the
quality of much larger models at high speed. macllm searches for the current top pick
at install time, because the best model changes almost monthly.

### Is MLX faster than Ollama on a Mac?
Yes — Apple's MLX runtime is typically 10–30% faster than GGUF/llama.cpp on the same
model and hardware. In this project's own testing, an MLX 4-bit build ran ~30% faster
than the equivalent Ollama GGUF build (≈97 vs ≈74 tokens/sec on an M5 Pro).

### How do I make my local LLM faster on a Mac?
Use an MoE model, a 4-bit quant, and the MLX runtime; turn off "thinking" for everyday
use; keep the model loaded to avoid cold starts; and right-size the context window.
macllm applies all of these automatically. Beyond that, generation speed is capped by
your chip's memory bandwidth — only a higher-bandwidth Mac (e.g. Max/Ultra) goes faster.

### Do I need an internet connection to use it?
Only to download the model once. After that it runs fully offline — nothing you type
leaves your Mac.

### Is this private?
Yes. The model runs locally; prompts and responses never touch a cloud service.

### Does it work on Intel Macs?
The tunings target Apple Silicon (M1–M5), where MLX and unified memory apply. It will
detect a non-arm64 Mac and warn you.

---

## Requirements

- Apple Silicon Mac (M1 / M2 / M3 / M4 / M5), 8 GB RAM minimum (16 GB+ recommended)
- macOS 14+
- [Homebrew](https://brew.sh) (for one-line installs)
- [Claude Code](https://claude.com/claude-code) (to run the `/macllm` skill)

## Safety

macllm sets up models with their built-in safety training intact. It will help you
give a model a **blunt, no-filler personality** via a system prompt, but it will not
strip safety guardrails or fetch "uncensored" builds.

## License

MIT — see [LICENSE](LICENSE).

---

*Keywords: local LLM Mac, Apple Silicon LLM, MLX, LM Studio, Ollama, offline AI,
private ChatGPT alternative, run LLM locally, best local model M1 M2 M3 M4 M5,
optimize local LLM speed, macOS local AI, Claude Code skill.*
