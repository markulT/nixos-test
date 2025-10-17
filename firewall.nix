{ config, pkgs, ... };
{
  networking.firewall.enable = true;
  networking.firewall.allowPing = true;
  networking.firewall.allowTCPPorts = [ 22 80 443 ];
}
