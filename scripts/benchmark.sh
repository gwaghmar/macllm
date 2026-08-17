#!/usr/bin/env bash
# benchmark.sh — measure real tokens/sec for a loaded local model.
# Works against LM Studio (:1234) or Ollama (:11434), OpenAI-compatible API.
#
# Usage:
#   scripts/benchmark.sh lmstudio <model-id>
#   scripts/benchmark.sh ollama   <model:tag>
#
# Example:
#   scripts/benchmark.sh lmstudio qwen/qwen3.6-35b-a3b
#   scripts/benchmark.sh ollama   qwen3.6:35b-a3b
set -euo pipefail

BACKEND="${1:-}"
MODEL="${2:-}"
if [ -z "$BACKEND" ] || [ -z "$MODEL" ]; then
  echo "usage: $0 <lmstudio|ollama> <model-id>"; exit 1
fi

case "$BACKEND" in
  lmstudio) URL="http://localhost:1234/v1/chat/completions"; NOTHINK='"reasoning_effort":"none"' ;;
  ollama)   URL="http://localhost:11434/v1/chat/completions"; NOTHINK='"reasoning_effort":"none"' ;;
  *) echo "unknown backend: $BACKEND"; exit 1 ;;
esac

PROMPT="Write a detailed 400-word explanation of how a build system with caching and incremental rebuilds works."

req() {
  local maxtok="$1"
  curl -s "$URL" -H "Content-Type: application/json" \
    -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"$PROMPT\"}],\"max_tokens\":$maxtok,\"stream\":false,$NOTHINK}"
}

echo "== macllm benchmark: $BACKEND / $MODEL =="
echo "warming up..."
req 10 >/dev/null || { echo "request failed — is the server running and the model loaded?"; exit 1; }

python3 - "$URL" "$MODEL" "$NOTHINK" "$PROMPT" <<'PY'
import json, sys, time, urllib.request
url, model, nothink, prompt = sys.argv[1:5]
extra = {}
if nothink:
    k, v = nothink.replace('"','').split(':'); extra[k] = v
def call(maxtok):
    body = json.dumps({"model":model,"messages":[{"role":"user","content":prompt}],
                       "max_tokens":maxtok,"stream":False, **extra}).encode()
    req = urllib.request.Request(url, body, {"Content-Type":"application/json"})
    t0 = time.time(); r = json.load(urllib.request.urlopen(req, timeout=600)); dt = time.time()-t0
    u = r["usage"]; return u["prompt_tokens"], u["completion_tokens"], dt
rates = []
for i in range(3):
    _, ct, dt = call(700); rates.append(ct/dt)
    print(f"  run {i+1}: {ct/dt:5.1f} tok/s")
print(f"\ngeneration: {sum(rates)/len(rates):.1f} tok/s (avg of 3)")
PY
