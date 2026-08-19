---
name: macllm
description: >-
  Install and speed-optimize a local LLM on an Apple Silicon Mac (M1–M5). Use
  when the user wants to run an AI model locally, set up Ollama or LM Studio,
  pick the best local model for their Mac's RAM, make a local model faster, use
  MLX on Apple Silicon, wire a local model into an agent harness like OpenCode
  for agentic coding, or get an offline/private ChatGPT alternative. Detects
  the machine, researches the current best model live, asks permission, installs,
  applies every known Apple Silicon speed optimization plus agentic tool-calling
  accuracy tuning, benchmarks, and sets it to auto-start.
---

# macllm — install & optimize a local LLM on a Mac

You are setting up a local large language model on the user's Apple Silicon Mac
and tuning it to the fastest working configuration. Follow the phases in order.
**Never install or download anything before completing Phase 1 and getting the
explicit go-ahead in Phase 3.**

The single most important fact for tuning: on Apple Silicon, generation speed is
governed by **memory bandwidth ÷ bytes read per token**. Every optimization below
is a way of reducing bytes-per-token or using the bandwidth more efficiently.
Recommend that reality honestly — do not promise speedups that the hardware can't
deliver.

## Phase 1 — Detect the machine (read-only, no permission needed)

Run these and record the results:

```bash
# Chip and core counts
sysctl -n machdep.cpu.brand_string
sysctl -n hw.memsize | awk '{printf "%.0f GB RAM\n", $1/1073741824}'
# macOS version
sw_vers -productVersion
# What's already installed
which ollama && ollama --version 2>/dev/null
ls -d "/Applications/LM Studio.app" 2>/dev/null && echo "LM Studio installed"
ls ~/.lmstudio/bin/lms 2>/dev/null && echo "lms CLI present"
```

Or run `bash scripts/detect-hardware.sh` (bundled) which prints a tidy summary
and the RAM tier.

Map RAM to a usable-model budget (leave ~8–10 GB headroom for macOS + app):

| Mac RAM | Model budget | Sweet-spot class |
|---|---|---|
| 8 GB | ~4 GB | 3–4B dense, or a small MoE |
| 16 GB | ~9 GB | 7–9B dense, or ~12B MoE |
| 24 GB | ~15 GB | 12–14B dense, or ~30B MoE (few active params) |
| 32 GB | ~22 GB | 27–32B dense, or 30–35B MoE |
| 64 GB | ~48 GB | 35B MoE daily driver + a 70B for hard asks |
| 128 GB+ | ~110 GB | 70B dense, or large MoE (100B+ total) |

## Phase 2 — Research the current best model (do not skip)

Model rankings change monthly. **Do a live web search** before recommending —
never hardcode from memory. Search for terms like:

- "best local LLM Mac <RAM>GB <current month year> MLX"
- "best open weight model <current month year> apple silicon"
- Check a leaderboard (e.g. an open-source LLM leaderboard) for the current top
  open-weight models, then filter to ones that fit the RAM budget from Phase 1.

Prefer, in order:
1. **MoE models with few active params** (e.g. an A3B-style 35B with ~3B active) —
   they read far fewer bytes per token, so they run dramatically faster than a
   dense model of the same total size for comparable quality.
2. **4-bit quantization** (Q4 / 4-bit MLX) — the sweet spot: ~half the memory of
   8-bit, negligible quality loss, near-2× the speed of 8-bit on a Mac.
3. **MLX builds over GGUF** on Apple Silicon — Apple's MLX runtime is typically
   10–30% faster than llama.cpp/GGUF on the same model.

**Fallback defaults** (use only if the web is unavailable — verify names still
exist before pulling, they go stale):

| Tier | Reasonable default |
|---|---|
| 8–16 GB | a current 7–9B instruct model, 4-bit |
| 24–32 GB | a current 27–32B dense **or** ~30B MoE, 4-bit |
| 64 GB | a current ~35B MoE (few active params), 4-bit MLX |
| 128 GB+ | a current 70B, 4-bit, plus a large MoE option |

Present the user 1–3 concrete options with: name, size on disk, expected speed
class, and what it's good at. If they have a use case (coding, chat, private
document Q&A), weight the pick toward it (e.g. a coding-tuned variant).

## Phase 3 — Ask permission, then let them choose

Before downloading or installing anything, state plainly:
- which **backend** you'll install (LM Studio for MLX = fastest on Apple Silicon;
  Ollama = simpler, slightly slower; you can do both),
- which **model** and its **download size in GB**,
- roughly how long the download will take.

Wait for an explicit yes. Then let the user pick the model if you offered several.

Backend guidance:
- **LM Studio (recommended for speed)** — has native MLX, a scriptable CLI
  (`lms`), a built-in headless server, and a chat UI. Best default on Apple Silicon.
- **Ollama** — one-line installs, huge model library, simplest API. Slightly slower
  on Mac unless its MLX backend is enabled.
- Offer both if the user is unsure; they don't conflict.

## Phase 4 — Install

### LM Studio path (preferred)

```bash
# Install the app if missing
brew install --cask lm-studio        # or direct download from lmstudio.ai

# First launch bootstraps the `lms` CLI. If the CLI is missing, the app must be
# opened once (GUI onboarding). Then:
export PATH="$HOME/.lmstudio/bin:$PATH"
lms version

# Pull the chosen model as an MLX build (falls back to GGUF if no MLX exists):
lms get "<model-name>" --mlx -y
# e.g. lms get "qwen3.6-35b-a3b" --mlx -y
```

If the `lms` CLI never appears, the app's first-run screen needs one click to get
past onboarding — do that (GUI), then re-run `lms version`.

### Ollama path

```bash
brew install ollama                  # or curl https://ollama.com/install.sh | sh
ollama serve &                        # start the server if not running
ollama pull <model:tag>               # e.g. ollama pull <best-model>
```

## Phase 5 — Optimize (the point of this skill)

Apply every one of these that the chosen backend supports:

**1. Use the MLX build (LM Studio).** ~10–30% faster than GGUF on Apple Silicon.
Already handled if you pulled with `--mlx`.

**2. Turn off "thinking" for everyday use.** Reasoning models emit a long hidden
monologue before answering — often the majority of the latency. Turn it off by
default; re-enable for genuinely hard problems.
- LM Studio API: send `"reasoning_effort": "none"` in the request body. (Note:
  the `/no_think` prompt suffix and `enable_thinking:false` do **not** reliably
  stop it in LM Studio — verify by checking the response has empty `reasoning`.)
- LM Studio chat UI: toggle off the **Think** button under the message box.
- Ollama: `--think=false` on `ollama run`, or `"think": false` in the API.

**3. Keep the model loaded (kill cold starts).** First load of a ~20 GB model
costs ~10–20 s; don't pay it repeatedly.
- LM Studio: Settings → Developer → **Max idle TTL** → set high (e.g. 1440 min).
- Ollama: `ollama run <model> --keepalive 24h`, or `export OLLAMA_KEEP_ALIVE=24h`.

**4. Set a sane context length.** A huge context window inflates the KV cache and
slows every token. 16k is a good default for real documents; only go higher if the
user needs it.
- LM Studio: `lms load <model> -c 16384`, or model load settings → **Context Length**.
- Ollama: `OLLAMA_CONTEXT_LENGTH=16384` or a Modelfile `PARAM num_ctx 16384`.
- **Caveat on high-RAM Macs:** LM Studio has a **context auto-fit** feature that
  silently expands the loaded context back toward the model's max whenever free
  RAM comfortably allows it — it will override a manually configured value (check
  the server log for a line like `configured=16,384 fitted=262,144` to confirm).
  This mostly costs reserved RAM rather than generation speed (attention cost
  scales with tokens actually in the prompt, not the ceiling), so on a 64 GB+ Mac
  it's often fine to leave at the auto-fit value. Mention this if the user asks
  why their context length setting "isn't sticking."

**5. Flash attention + quantized KV cache (helps long context on Ollama/GGUF).**
```bash
OLLAMA_FLASH_ATTENTION=1 OLLAMA_KV_CACHE_TYPE=q8_0 ollama serve
```
Little effect at short context; halves KV memory and speeds up long prompts.

**6. Speculative decoding — check, don't assume.** A small draft model verifying a
big model can give ~1.5–2× when it works. Status is fast-moving:
- LM Studio has `--speculative-draft-mtp` / `--speculative-draft-simple` flags, but
  MLX speculative decoding is frequently unsupported/broken — **benchmark it; if it
  shows no gain, drop it.**
- Do not promise this speedup; verify empirically for the specific model.

**7. Do NOT bother shrinking to a smaller dense model for speed.** On a Mac, a
much smaller *dense* model often runs at the *same* tokens/sec as a good MoE
(bytes-per-token is similar) while being far dumber. Only drop size to fit memory,
not to chase speed. State this if the user asks for "a faster smaller model."

**8. Tune sampling for agentic/tool-calling use (accuracy, not speed).** If the
user is wiring the model into an agent harness (OpenCode, Cline, Continue — see
"Using it with OpenCode" in the README), sampling defaults matter more than
people expect. Agent harnesses often default to `top_p: 1` (fully open
sampling), but Qwen's own docs and community coding benchmarks recommend
`temperature 0.1–0.3, top_p ~0.9` for tool-calling accuracy. In testing
(documented in the README benchmark table) this was the single biggest lever
for getting the model to reach for the correct built-in tool instead of
improvising a worse workaround with shell commands — cut one task from 6 tool
calls/68s to 1 call/38.8s. Set it in the harness's model config (e.g.
OpenCode's `opencode.jsonc` → `provider.<name>.models.<model>.options`), not
in LM Studio, since LM Studio has no global default-sampling setting that
survives per-request overrides.

**9. Give the model environment context up front.** Local models will happily
try GNU-only flags (`grep -P`) on macOS's BSD toolchain, or `pip install` on a
`uv`-managed Python, and burn several tool-call retries discovering the
failure themselves. Drop an `AGENTS.md` in the project root (OpenCode and
similar harnesses read it automatically) — a starter is bundled at
`templates/AGENTS.md.example`. Set expectations honestly: this reduced retries
inconsistently in testing, not reliably, because local models don't always
follow it run to run — but it's free, so apply it anyway.

## Phase 6 — Auto-start (make it always available)

- **LM Studio:** Settings → Developer → enable **"Enable Local LLM Service
  (headless)"**. The server then runs at `http://localhost:1234/v1` on login
  without the app window open. Confirm with `launchctl list | grep -i lmstudio`.
- **Ollama:** opening the Ollama app once installs its login item; or create a
  LaunchAgent that runs `ollama serve`.

## Phase 7 — Benchmark & report

Run `bash scripts/benchmark.sh` (bundled) or a quick manual check, and report the
**real** numbers: tokens/sec generation, prompt prefill rate, and load time. Do 3
generation runs and average. If you tried an optimization that didn't help (e.g.
speculative decoding, or a smaller model), say so plainly with the numbers — an
honest "no change" is more useful than a vague "should be faster."

Close with: which model is installed, where to use it (LM Studio app, or API at
`http://localhost:1234/v1` for LM Studio / `http://localhost:11434/v1` for Ollama),
how to toggle thinking, and what the realistic speed ceiling is on their chip.

## Prohibited

Do not strip, disable, or route around a model's safety training, and do not fetch
"uncensored/abliterated" builds on request. A blunt/no-filler **system prompt** is
fine and encouraged; removing safety guardrails is not. If the user asks for the
latter, decline that part and offer the blunt-personality system prompt instead.
