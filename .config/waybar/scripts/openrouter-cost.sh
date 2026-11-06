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
done

# ---------- API call ----------
API_KEY="${OPENROUTER_API_KEY:-}"
if [[ -z "$API_KEY" ]]; then
  printf '{"text":" no key","tooltip":"OPENROUTER_API_KEY not set","class":"warning"}\n'
  exit 0
fi

RESPONSE=$(curl -sf --max-time 10 \
  -H "Authorization: Bearer $API_KEY" \
  https://openrouter.ai/api/v1/auth/key 2>/dev/null || true)

# ---------- parse & render ----------
if [[ -z "$RESPONSE" ]]; then
  printf '{"text":" error","tooltip":"OpenRouter API unreachable","class":"warning"}\n'
  exit 0
fi

# Parse usage/limit from JSON using grep (no jq dependency).
USAGE=$(echo "$RESPONSE" | grep -oE '"usage":[0-9.]+' | cut -d: -f2)
LIMIT=$(echo "$RESPONSE" | grep -oE '"limit":[0-9.]+' | cut -d: -f2)
LABEL=$(echo "$RESPONSE" | grep -oE '"label":"[^"]+"' | cut -d\" -f4)

# Defaults if fields missing
USAGE=${USAGE:-0}
LIMIT=${LIMIT:-0}

# Format dollar amounts
USAGE_FMT=$(printf "%.2f" "$USAGE")
LIMIT_FMT=$(printf "%.2f" "$LIMIT")

# Pick a class based on usage threshold
CLASS=""
if (( $(echo "$LIMIT > 0" | bc -l) )); then
  PCT=$(echo "scale=2; $USAGE * 100 / $LIMIT" | bc)
  if (( $(echo "$PCT >= 80" | bc -l) )); then
    CLASS="warning"
  elif (( $(echo "$PCT >= 95" | bc -l) )); then
    CLASS="critical"
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