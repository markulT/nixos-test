{ config, pkgs, ... };
{
  networking.firewall.enable = true;
  networking.firewall.allowPing = true;
  networking.firewall.allowedTCPPorts = [ 22 80 443 ];
}
