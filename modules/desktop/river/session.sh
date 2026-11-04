#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Bind the supervised shell lifetime to River's window manager.
#
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation, version 3 of the License.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program. If not, see <https://www.gnu.org/licenses/>.

set -eu

# River invokes init after creating the Wayland socket. Preserve 150% scaling.
wlr-randr 2>/dev/null |
  while IFS= read -r output_line; do
    case "$output_line" in
      ""|[[:space:]]*) continue ;;
    esac
    output_name=${output_line%% *}
    wlr-randr --output "$output_name" --scale 1.5 || true
  done

wm_pid=
# Invoked indirectly by the EXIT trap, including failed startup.
# shellcheck disable=SC2329
cleanup() {
  systemctl --user stop neodots-river-session.target || true
  if [ -n "$wm_pid" ]; then
    kill "$wm_pid" 2>/dev/null || true
    wait "$wm_pid" 2>/dev/null || true
  fi
}
trap 'cleanup' EXIT
trap 'exit 143' TERM HUP
trap 'exit 130' INT

systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE
# A fresh user manager has not loaded the unit yet; reset is best-effort.
systemctl --user reset-failed neodots-quickshell.service || true
systemctl --user start neodots-river-session.target
kwm &
wm_pid=$!
status=0
wait "$wm_pid" || status=$?
wm_pid=
exit "$status"
