# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Fcitx5 input method setup (Vietnamese through fcitx5-lotus) and
#          uinput.
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
  # ---------------------------------------------------------------------------
  # Fcitx5
  # ---------------------------------------------------------------------------


  environment.systemPackages = with pkgs; [
    wl-clipboard
  ];

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
  };

  # ---------------------------------------------------------------------------
  # Linux uinput
  # ---------------------------------------------------------------------------
  # See docs/comments/inputmethod.txt.

  hardware.uinput.enable = true;

  # ---------------------------------------------------------------------------
  # Lotus
  # ---------------------------------------------------------------------------

  services.fcitx5-lotus = {
    enable = true;
    users = [ config.neodots.username ];
  };
}
