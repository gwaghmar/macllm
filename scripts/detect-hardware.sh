#!/usr/bin/env bash
# detect-hardware.sh — read-only Mac profile for local-LLM sizing.
# Prints chip, RAM, macOS, installed backends, and a recommended model budget.
set -euo pipefail

echo "== macllm hardware check =="

CHIP="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo unknown)"
RAM_BYTES="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"
RAM_GB=$(( RAM_BYTES / 1073741824 ))
OSV="$(sw_vers -productVersion 2>/dev/null || echo unknown)"
ARCH="$(uname -m)"

echo "Chip:      $CHIP"
echo "Arch:      $ARCH"
echo "RAM:       ${RAM_GB} GB"
echo "macOS:     $OSV"

if [ "$ARCH" != "arm64" ]; then
  echo "WARNING:   not Apple Silicon (arm64). MLX and these tunings assume an M-series chip."
fi

echo
echo "== installed backends =="
if command -v ollama >/dev/null 2>&1; then
  echo "Ollama:    $(ollama --version 2>/dev/null | head -1)"
else
  echo "Ollama:    not installed"
fi
if [ -d "/Applications/LM Studio.app" ]; then
  echo "LM Studio: installed"
else
  echo "LM Studio: not installed"
fi
if [ -x "$HOME/.lmstudio/bin/lms" ]; then
  echo "lms CLI:   present"
else
  echo "lms CLI:   not bootstrapped (open LM Studio once)"
fi

# Leave ~9 GB headroom for macOS + app.
BUDGET=$(( RAM_GB > 9 ? RAM_GB - 9 : RAM_GB / 2 ))
echo
echo "== sizing =="
echo "Usable model budget: ~${BUDGET} GB on disk/RAM"
if   [ "$RAM_GB" -le 8 ];  then TIER="3-4B dense or a small MoE";
elif [ "$RAM_GB" -le 16 ]; then TIER="7-9B dense or a ~12B MoE";
elif [ "$RAM_GB" -le 24 ]; then TIER="12-14B dense or a ~30B MoE";
elif [ "$RAM_GB" -le 32 ]; then TIER="27-32B dense or a 30-35B MoE";
elif [ "$RAM_GB" -le 64 ]; then TIER="35B MoE daily driver (+ a 70B for hard asks)";
else                            TIER="70B dense or a large 100B+ MoE";
fi
echo "Sweet-spot class:    $TIER"
echo
echo "Next: research the CURRENT best model for this tier (rankings change monthly),"
echo "prefer a 4-bit MLX MoE build, then confirm the download before installing."
