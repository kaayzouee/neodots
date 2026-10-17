# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - tmux configuration.
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

{ config, pkgs, ... }:

{
  # 1. Enable tmux
  programs.tmux = {
    enable = true;

    # 2. Basic settings
    mouse = true; # Mouse support
    shortcut = "b"; # Prefix key (Ctrl+b by default)
    baseIndex = 1; # Window numbers start at 1
    escapeTime = 0; # Reduce ESC delay
    sensibleOnTop = true; # Enable sensible plugin for better defaults

    # 3. Plugin management
    plugins = with pkgs; [
      tmuxPlugins.yank # System clipboard support
      tmuxPlugins.cpu # Show CPU in status bar
      # Add more plugins here...
    ];

    # 4. Custom key bindings and advanced config
    extraConfig = ''
      # --- Session switching (trick 1) ---
      bind C-s choose-session -Z

      # --- Floating scratchpad (trick 2) ---
      bind C-p display-popup -E -w 80% -h 60% -d "#{pane_current_path}" "bash"

      # --- Mouse toggle (trick 4) ---
      bind m set -g mouse on \; display "Mouse ON"
      bind M set -g mouse off \; display "Mouse OFF"

      # --- Pane zoom (trick 5) ---
      bind z resize-pane -Z

      # --- Sync panes (trick 6) ---
      bind e set-window-option synchronize-panes

      # --- Quick rename (trick 7) ---
      bind , command-prompt "rename-window '%%'"
      bind . command-prompt "rename-pane '%%'"

      # --- Show pane numbers (trick 9) ---
      bind q display-panes -d 0

      # --- Scrollback search (trick 12) ---
      bind / copy-mode \; send-keys '/'
      bind ? copy-mode \; send-keys '?'

      # --- Layout switching (trick 13) ---
      bind Space next-layout
      bind C-Space previous-layout

      # --- Nested sessions (trick 14) ---
      bind C-a send-prefix

      # --- System clipboard (trick 3, works with yank plugin) ---
      # Set terminal for proper colors
      set -g default-terminal "tmux-256color"

      # --- Custom status bar (optional) ---
      # set -g status-right "#[fg=green]#(acpi -b 2>/dev/null | cut -d' ' -f3-4)#[default] %H:%M"

      # --- Pane navigation (replaces vim-tmux-navigator) ---
      # Pass the key through when a full-screen app is active
      # (vim/nano/less/fzf — detected via #{alternate_on});
      # otherwise use it for pane navigation.
      bind -n C-h if-shell -F "#{alternate_on}" "send-keys C-h" "select-pane -L"
      bind -n C-j if-shell -F "#{alternate_on}" "send-keys C-j" "select-pane -D"
      bind -n C-k if-shell -F "#{alternate_on}" "send-keys C-k" "select-pane -U"
      bind -n C-l if-shell -F "#{alternate_on}" "send-keys C-l" "select-pane -R"
    '';
  };

}
