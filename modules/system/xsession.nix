{ pkgs, ... }:
{
  xsession.enable = true;
  xsession.windowManager.command = "startxfce4";
}
