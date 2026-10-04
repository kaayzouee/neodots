# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee

{ config, lib, pkgs, ... }:

{
  sops.defaultSopsFile = ../../secrets/secrets.yaml;

  sops.secrets."git/name"      = { };
  sops.secrets."git/email"     = { };
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
        smtpserver     = "smtp.gmail.com";
        smtpserverport = 587;
        smtpencryption = "tls";
      };
    };

    includes = [
      { path = config.sops.templates."git-identity.conf".path; }
    ];
  };
}
