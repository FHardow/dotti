#!/usr/bin/env bash
# Stream CPU load + package temperature to waybar as one JSON line per tick.
# Temperature is skipped on hosts without the Intel coretemp sensor.

interval=${1:-2}
temp_file=$(ls /sys/devices/platform/coretemp.0/hwmon/hwmon*/temp1_input 2>/dev/null | head -n 1)
model=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//')

read -r _ user nice system idle iowait irq softirq steal _ </proc/stat
prev_total=$((user + nice + system + idle + iowait + irq + softirq + steal))
prev_idle=$((idle + iowait))

while sleep "$interval"; do
  read -r _ user nice system idle iowait irq softirq steal _ </proc/stat
  total=$((user + nice + system + idle + iowait + irq + softirq + steal))
  idle_all=$((idle + iowait))
  usage=$((100 * ((total - prev_total) - (idle_all - prev_idle)) / (total - prev_total)))
  prev_total=$total prev_idle=$idle_all

  text=" ${usage}%"
  temp=0
  if [[ -n $temp_file ]]; then
    temp=$(($(<"$temp_file") / 1000))
    text+="   ${temp}°"
  fi

  if ((temp >= 85 || usage >= 95)); then
    class=critical
  elif ((temp >= 75 || usage >= 80)); then
    class=warning
  else
    class=normal
  fi

  read -r load1 load5 load15 _ </proc/loadavg
  mhz=$(awk '/cpu MHz/ {sum += $4; n++} END {printf "%d", sum / n}' /proc/cpuinfo)

  tooltip="${model}\n"
  tooltip+="\nLoad:   ${usage}%"
  [[ -n $temp_file ]] && tooltip+="\nTemp:   ${temp}°C"
  tooltip+="\nClock:  ${mhz} MHz avg"
  tooltip+="\nAvg:    ${load1} ${load5} ${load15}"

  printf '{"text": "%s", "tooltip": "%s", "class": "%s", "percentage": %s}\n' \
    "$text" "$tooltip" "$class" "$usage"
done
