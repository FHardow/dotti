#!/usr/bin/env bash
# Show OpenRouter account-wide spending in the waybar.
#
# Reads OPENROUTER_API_KEY from the environment.
# Caches the rendered output to $XDG_RUNTIME_DIR/openrouter-cost.json for 5 min
# to avoid hammering the API on every waybar poll.
#
# Pill shows total account spend (all keys, /api/v1/credits).
# Tooltip adds credits, remaining balance and this key's own spend (/api/v1/auth/key).
#
# Returns JSON for waybar custom module:
#   {"text": "󰚩 $1.51", "tooltip": "...", "class": ""}

set -euo pipefail

CACHE_FILE="${XDG_RUNTIME_DIR:-/tmp}/openrouter-cost.json"
CACHE_TTL=300  # 5 minutes
NOW=$(date +%s)
ICON="󰚩"  # nf-md-robot

# ---------- cache read ----------
if [[ -f "$CACHE_FILE" ]] && [[ "${DEBUG:-}" != "true" ]]; then
  CACHE_AGE=$(( NOW - $(stat -c '%Y' "$CACHE_FILE" 2>/dev/null || echo 0) ))
  if (( CACHE_AGE < CACHE_TTL )); then
    cat "$CACHE_FILE"
    exit 0
  fi
fi

# ---------- API calls ----------
API_KEY="${OPENROUTER_API_KEY:-}"
if [[ -z "$API_KEY" ]]; then
  printf '{"text":"%s no key","tooltip":"OPENROUTER_API_KEY not set","class":"warning"}\n' "$ICON"
  exit 0
fi

fetch() {
  curl -sf --max-time 10 -H "Authorization: Bearer $API_KEY" "$1" 2>/dev/null || true
}

CREDITS_RESPONSE=$(fetch https://openrouter.ai/api/v1/credits)
KEY_RESPONSE=$(fetch https://openrouter.ai/api/v1/auth/key)

# ---------- debug (set DEBUG=true) ----------
if [[ "${DEBUG:-}" == "true" ]]; then
  echo "credits: $CREDITS_RESPONSE" >&2
  echo "key:     $KEY_RESPONSE" >&2
fi

# ---------- parse & render ----------
if [[ -z "$CREDITS_RESPONSE" ]]; then
  printf '{"text":"%s error","tooltip":"OpenRouter API unreachable","class":"warning"}\n' "$ICON"
  exit 0
fi

# Extract a numeric JSON field (no jq dependency). Prints 0 if missing.
num_field() {
  local v
  v=$(echo "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\([0-9.]*\).*/\1/p" | tr -cd '0-9.')
  echo "${v:-0}"
}

money() { LC_ALL=C printf "%.2f" "$1" 2>/dev/null || echo "0.00"; }

TOTAL_USAGE=$(num_field "$CREDITS_RESPONSE" total_usage)
TOTAL_CREDITS=$(num_field "$CREDITS_RESPONSE" total_credits)
KEY_USAGE=$(num_field "$KEY_RESPONSE" usage)
LABEL=$(echo "$KEY_RESPONSE" | sed -n 's/.*"label"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

REMAINING=$(awk -v c="$TOTAL_CREDITS" -v u="$TOTAL_USAGE" 'BEGIN{print c-u}')

USAGE_FMT=$(money "$TOTAL_USAGE")
CREDITS_FMT=$(money "$TOTAL_CREDITS")
REMAINING_FMT=$(money "$REMAINING")
KEY_USAGE_FMT=$(money "$KEY_USAGE")

# Pick a class based on share of purchased credits used
CLASS=""
HAS_CREDITS=$(awk -v c="$TOTAL_CREDITS" 'BEGIN{print (c>0) ? 1 : 0}')
if [[ "$HAS_CREDITS" == "1" ]]; then
  PCT=$(awk -v u="$TOTAL_USAGE" -v c="$TOTAL_CREDITS" 'BEGIN{printf "%.0f", u*100/c}')
  if (( PCT >= 95 )); then
    CLASS="critical"
  elif (( PCT >= 80 )); then
    CLASS="warning"
  fi
fi

TOOLTIP="OpenRouter account: \$$USAGE_FMT / \$$CREDITS_FMT credits"
TOOLTIP+="\\nRemaining: \$$REMAINING_FMT"
[[ -n "$KEY_RESPONSE" ]] && TOOLTIP+="\\nThis key (${LABEL:-unknown}): \$$KEY_USAGE_FMT"

JSON=$(printf '{"text":"%s $%s","tooltip":"%s","class":"%s"}\n' \
  "$ICON" "$USAGE_FMT" "$TOOLTIP" "$CLASS")

# Write cache
echo "$JSON" > "$CACHE_FILE"
echo "$JSON"
