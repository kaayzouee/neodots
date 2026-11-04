# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Validate age key ownership and permissions without reading its value.
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
key=$1
if ! test -f "$key" || ! test "$(stat -Lc %u "$key")" = "$(id -u)"; then
  echo 'SOPS requires an existing age key owned by this user; restore your protected backup.' >&2
  exit 1
fi
case "$(stat -Lc %a "$key")" in
  400|600) ;;
  *) echo 'SOPS age key must have mode 0400 or 0600; see docs/security/SOPS-RECOVERY.md.' >&2; exit 1 ;;
esac
