#!/usr/bin/env bash
# Stream NVIDIA GPU stats to waybar as one JSON line per tick.
# Runs nvidia-smi once in loop mode instead of spawning it every interval.

interval=${1:-2}

nvidia-smi -l "$interval" --format=csv,noheader,nounits \
  --query-gpu=name,utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw,power.limit,clocks.gr,fan.speed |
  while IFS=',' read -r name util temp mem_used mem_total power power_limit clock fan; do
    # nvidia-smi pads fields with a leading space
    util=${util// /} temp=${temp// /} mem_used=${mem_used// /} mem_total=${mem_total// /}
    power=${power// /} power_limit=${power_limit// /} clock=${clock// /} fan=${fan// /}

    if ((temp >= 85 || util >= 95)); then
      class=critical
    elif ((temp >= 75 || util >= 80)); then
      class=warning
    else
      class=normal
    fi

    tooltip="${name}\n"
    tooltip+="\nLoad:   ${util}%"
    tooltip+="\nTemp:   ${temp}°C"
    tooltip+="\nVRAM:   ${mem_used} / ${mem_total} MiB"
    tooltip+="\nPower:  ${power%.*} / ${power_limit%.*} W"
    tooltip+="\nClock:  ${clock} MHz"
    tooltip+="\nFan:    ${fan}%"

    tenths=$((mem_used * 10 / 1024))
    printf -v vram '%d.%dG' $((tenths / 10)) $((tenths % 10))

    text="󰢮 ${util}%   ${temp}°  󰍛 ${vram}"
    printf '{"text": "%s", "tooltip": "%s", "class": "%s", "percentage": %s}\n' \
      "$text" "$tooltip" "$class" "$util"
  done
