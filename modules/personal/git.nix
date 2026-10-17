# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Personal Git identity and credentials loaded from SOPS secrets.
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

{
  config,
  lib,
  pkgs,
  ...
}:

{
  sops.defaultSopsFile = ../../secrets/secrets.yaml;

  sops.secrets."git/name" = { };
  sops.secrets."git/email" = { };
  sops.secrets."git/smtp-user" = { };
  sops.secrets."git/smtp-pass" = { };

  sops.templates."git-identity.conf" = {
    content = ''
      [user]
        name  = ${config.sops.placeholder."git/name"}
        email = ${config.sops.placeholder."git/email"}

      [sendemail]
        smtpuser = ${config.sops.placeholder."git/smtp-user"}
        smtppass = ${config.sops.placeholder."git/smtp-pass"}
    '';
  };

  programs.git = {
    enable = true;

    settings = {
      credential = {
        "https://github.com" = {
          helper = "!${lib.getExe pkgs.gh} auth git-credential";
        };
      };

      sendemail = {
        smtpserver = "smtp.gmail.com";
        smtpserverport = 587;
        smtpencryption = "tls";
      };
    };

    includes = [
      { path = config.sops.templates."git-identity.conf".path; }
    ];
  };
}
