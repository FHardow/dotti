#!/usr/bin/env bash
# Show OpenRouter API spending in the waybar.
#
# Reads OPENROUTER_API_KEY from the environment.
# Caches the API response to /tmp/openrouter-cost.json for 5 min to avoid
# hammering the API on every waybar poll.
#
# Returns JSON for waybar custom module:
#   {"text": "$0.12", "tooltip": "OpenRouter: $0.12 / $10.00 limit", "class": ""}

set -euo pipefail

CACHE_FILE="${XDG_RUNTIME_DIR:-/tmp}/openrouter-cost.json"
CACHE_TTL=300  # 5 minutes
NOW=$(date +%s)

# ---------- cache read ----------
if [[ -f "$CACHE_FILE" ]]; then
  CACHE_AGE=$(( NOW - $(stat -c '%Y' "$CACHE_FILE" 2>/dev/null || echo 0) ))
  if (( CACHE_AGE < CACHE_TTL )); then
    cat "$CACHE_FILE"
    exit 0
  fi
fi

# ---------- API call ----------
API_KEY="${OPENROUTER_API_KEY:-}"
if [[ -z "$API_KEY" ]]; then
  printf '{"text":" no key","tooltip":"OPENROUTER_API_KEY not set","class":"warning"}\n'
  exit 0
fi

RESPONSE=$(curl -sf --max-time 10 \
  -H "Authorization: Bearer $API_KEY" \
  https://openrouter.ai/api/v1/auth/key 2>/dev/null || true)

# ---------- debug (set DEBUG=true) ----------
if [[ "${DEBUG:-}" == "true" ]]; then
  echo "$RESPONSE" >&2
fi

# ---------- parse & render ----------
if [[ -z "$RESPONSE" ]]; then
  printf '{"text":" error","tooltip":"OpenRouter API unreachable","class":"warning"}\n'
  exit 0
fi

# Parse usage/limit from JSON using sed (no jq dependency).
USAGE=$(echo "$RESPONSE" | sed -n 's/.*"usage"[[:space:]]*:[[:space:]]*\([0-9.]*\).*/\1/p' | tr -d '[:space:]')
LIMIT=$(echo "$RESPONSE" | sed -n 's/.*"limit"[[:space:]]*:[[:space:]]*\([0-9.]*\).*/\1/p' | tr -d '[:space:]')
LABEL=$(echo "$RESPONSE" | sed -n 's/.*"label"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

# Defaults if fields missing or empty
USAGE=${USAGE:-0}
LIMIT=${LIMIT:-0}

# Sanitize: remove any non-numeric characters except dot
USAGE=$(echo "$USAGE" | tr -cd '0-9.')
LIMIT=$(echo "$LIMIT" | tr -cd '0-9.')

# Format dollar amounts (force locale-independent decimal)
USAGE_FMT=$(LC_ALL=C printf "%.2f" "$USAGE" 2>/dev/null || echo "0.00")
LIMIT_FMT=$(LC_ALL=C printf "%.2f" "$LIMIT" 2>/dev/null || echo "0.00")

# Pick a class based on usage threshold
CLASS=""
# awk handles floating point, unlike bash
HAS_LIMIT=$(awk -v l="$LIMIT" 'BEGIN{print (l>0) ? 1 : 0}' 2>/dev/null)
if [[ "$HAS_LIMIT" == "1" ]]; then
  PCT=$(awk -v u="$USAGE" -v l="$LIMIT" 'BEGIN{printf "%.0f", u*100/l}' 2>/dev/null)
  if (( PCT >= 95 )); then
    CLASS="critical"
  elif (( PCT >= 80 )); then
    CLASS="warning"
  fi
fi

TOOLTIP="OpenRouter: \$$USAGE_FMT"
[[ "$LIMIT_FMT" != "0.00" ]] && TOOLTIP+=" / \$$LIMIT_FMT limit"
TOOLTIP+="
API key: ${LABEL:-unknown}"

JSON=$(printf '{"text":" $%s","tooltip":"%s","class":"%s"}\n' \
  "$USAGE_FMT" "$TOOLTIP" "$CLASS")

# Write cache
echo "$JSON" > "$CACHE_FILE"
echo "$JSON"