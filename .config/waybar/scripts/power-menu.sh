#!/usr/bin/env bash

actions=$(echo -e "  Lock\n  Shutdown\n  Reboot\n$(printf '\u200A')  Suspend\n  Hibernate\n  Logout")

# Display logout menu
selected_option=$(echo -e "$actions" | wofi --dmenu --insensitive --hide-search --lines 6)

# Perform actions based on the selected option
case "$selected_option" in
*Lock)
  hyprlock
  ;;
*Shutdown)
  systemctl poweroff
  ;;
*Reboot)
  systemctl reboot
  ;;
*Suspend)
  systemctl suspend
  ;;
*Hibernate)
  systemctl hibernate
  ;;
*Logout)
  hyprctl dispatch exit 0
  ;;
esac
