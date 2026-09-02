{ lib, ... }:
{
  # mkDefault so a host can override without mkForce -- server01 runs UTC.
  time.timeZone = lib.mkDefault "Europe/Berlin";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
}
