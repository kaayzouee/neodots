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
    printf ' no battery\n'
    exit 0
fi

capacity=$(cat "$battery_dir/capacity")
status=$(cat "$battery_dir/status" 2>/dev/null || printf 'Unknown')

case "$capacity" in
    90|9[0-9]|100)
        icon=''
        ;;
    60|6[0-9]|7[0-9]|8[0-9])
        icon=''
        ;;
    30|3[0-9]|4[0-9]|5[0-9])
        icon=''
        ;;
    10|1[0-9]|2[0-9])
        icon=''
        ;;
    *)
        icon=''
        ;;
esac

case "$status" in
    Charging)
        printf ' %s %s%% charging\n' "$icon" "$capacity"
        ;;
    Full)
        printf '%s %s%% full\n' "$icon" "$capacity"
        ;;
    "Not charging")
        printf '%s %s%%\n' "$icon" "$capacity"
        ;;
    Discharging)
        printf '%s %s%%\n' "$icon" "$capacity"
        ;;
    *)
        printf '%s %s%% %s\n' "$icon" "$capacity" "$status"
        ;;
esac
