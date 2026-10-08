#!/usr/bin/env bash
# Total used/size across all mounted block-device filesystems.
# Each device is counted once, even if mounted at several paths.

df -B1 --output=source,size,used,target 2>/dev/null |
  awk -v icon="󰋊" '
    $1 ~ "^/dev/" && !seen[$1]++ {
      size += $2; used += $3
      tip = tip sprintf("\\n%-12s %5.0f / %4.0fG", $4, $3 / 2^30, $2 / 2^30)
    }
    END {
      pct = size ? int(100 * used / size) : 0
      class = pct >= 90 ? "critical" : pct >= 80 ? "warning" : "normal"
      printf "{\"text\": \"%s %.0f/%.0fG\", \"tooltip\": \"Mounted drives%s\", \"class\": \"%s\", \"percentage\": %d}\n",
        icon, used / 2^30, size / 2^30, tip, class, pct
    }'
