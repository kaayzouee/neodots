# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee

#!/bin/sh

set -eu

battery_dir=""

for dir in /sys/class/power_supply/BAT*; do
    if [ -d "$dir" ] && [ -r "$dir/capacity" ]; then
        battery_dir="$dir"
        break
    fi
done

if [ -z "$battery_dir" ]; then
    printf ' 0%% ?\n'
    exit 0
fi

capacity=$(cat "$battery_dir/capacity")
status=$(cat "$battery_dir/status" 2>/dev/null || printf 'Unknown')

case "$capacity" in
    90|9[0-9]|100)
        battery_icon=''
        ;;
    60|6[0-9]|7[0-9]|8[0-9])
        battery_icon=''
        ;;
    30|3[0-9]|4[0-9]|5[0-9])
        battery_icon=''
        ;;
    10|1[0-9]|2[0-9])
        battery_icon=''
        ;;
    *)
        battery_icon=''
        ;;
esac

case "$status" in
    Charging)
        status_icon=''
        ;;
    Full)
        status_icon=''
        ;;
    Discharging)
        status_icon=''
        ;;
    "Not charging")
        status_icon=''
        ;;
    *)
        status_icon='?'
        ;;
esac

printf '%s %s%% %s\n' "$battery_icon" "$capacity" "$status_icon"
