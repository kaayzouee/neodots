# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Installs Fastfetch and links the Neodots layout.
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

{ pkgs, ... }:

{
  programs.fastfetch.enable = true;

  home.file.".config/fastfetch/config.jsonc".source = ../../config/fastfetch/config.jsonc;
}
