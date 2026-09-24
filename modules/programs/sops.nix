{ pkgs, ... }:

{
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.defaultSopsFile = ../../secrets/secrets.yaml;
}
