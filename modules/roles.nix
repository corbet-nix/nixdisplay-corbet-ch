# SPDX-License-Identifier: MIT OR Apache-2.0
# modules/roles.nix — output role assignments: which connectors serve special functions across
# the display topology.
#
# Currently: `kioskOutputs` names which physical connectors (e.g., "DP-3") run a kiosk renderer
# (a status dashboard or similar) while every other output locks normally. A connector named here
# stays always-on and never participates in the session lock.
#
# WHY THIS IS A DISPLAY FACT. A kiosk output is a property of the desk topology, not the host or
# the session. The same desk rig may have a secondary panel that is always meant to show a status
# display; a different desk has none. This table is read by nixlock and nixwatch to determine which
# outputs to exempt from locking, and by infra to assign the kiosk role — so it lives here with the
# other display topology facts (monitors.nix, layouts.nix), not scattered across compositor or
# session modules. Other repos import this module and read the values; nothing here depends on
# them.
{ lib, config, ... }:
let
  inherit (lib) types mkOption;
in
{
  options.nixdisplay.roles = {
    kioskOutputs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "DP-3" ];
      description = ''
        Connector name(s) that are kiosk outputs: always-on, never locked, run a kiosk renderer
        (e.g., a status dashboard) while every other output locks normally.

        An output appears here by its connector name — "DP-3", "eDP-1", "HDMI-A-2" — the physical
        socket on the host, not by EDID identity or layout slug. Empty by default: a desk with no
        kiosk output assignment assigns no connector to this role.
      '';
    };
  };
}
