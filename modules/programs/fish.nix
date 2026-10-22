# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Enables the fish shell system-wide.
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

{ ... }:

{
  programs.fish.enable = true;

  # Fish 4.8+ removed tools/create_manpage_completions.py. Keep Fish's
  # built-in and vendor completions, but skip Nixpkgs' broken man-page
  # completion generation while unstable catches up.
  programs.fish.generateCompletions = false;
}
