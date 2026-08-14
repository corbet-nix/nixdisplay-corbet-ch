{
  description = "nixdisplay — the monitor registry, output layouts and dynamic (kanshi) output profiles for a declarative Wayland desktop, extracted from nixdesktop";

  # nixpkgs is the ONLY input. This flake declares identity/geometry and generates one dotfile
  # (kanshi's config); all of it is pure Nix, it installs nothing, and it names no absolute binary.
  #
  # UNLIKE the compositor repos (nixniri, nixscroll) it does NOT take nixhost for `lib.probeFact`.
  # Those repos probe THIS repo's `nixdisplay.layouts`/`nixdisplay.monitors` from a DIFFERENT
  # namespace, where a bare `config.nixdisplay.bar or {}` cannot tell "not composed" from "composed
  # but the leaf moved". Here those tables are our OWN: modules/monitors.nix and modules/layouts.nix
  # read each other with a plain defensive `config.nixdisplay.<t> or {}`, which is exactly right for
  # two modules that ship and are composed together. Nothing here reads a sibling repo at all: the
  # only `nixdesktop` mention left in the tree is one doc cross-reference (a session over in
  # nixdesktop names a `nixdisplay.layouts.<name>`), never a `config` read — so nixpkgs is genuinely
  # the whole input set.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ];
    in
    {
      # ── IDENTITY AND GEOMETRY ─────────────────────────────────────────────────────────────
      # `monitors` is FLEET-WIDE identity (a panel roams between hosts); `layouts` is per-host
      # arrangement (a desk does not). Two modules, not one, because a host that addresses only
      # connectors — a headless box, an evdi-only dock — legitimately wants the second and not the
      # first, and each reads the other defensively rather than importing it. Both are pure
      # option+assertion modules with no `pkgs` argument and no plane-specific config, so the SAME
      # file composes into a NixOS, a system-manager or a home-manager evaluation unchanged. They
      # are offered on the NixOS and system-manager planes for the same reason the registry existed
      # in the first place: the Arch/CachyOS hosts (system-manager) have the same monitors on the
      # same desks as the NixOS ones, and a table that lived on only one plane would be re-typed on
      # the other. A compositor config that READS them (a home-manager module) does its read through
      # `lib.probeFact` against whatever tree the consumer composed them into — it does not import
      # this module itself, which is why there is deliberately no homeManagerModules.{monitors,layouts}.
      nixosModules.monitors = ./modules/monitors.nix;
      nixosModules.layouts = ./modules/layouts.nix;
      nixosModules.roles = ./modules/roles.nix;
      # A convenience default for the common case (a host that addresses monitors by identity wants
      # both tables). No existing consumer imports `.default` — the import sites all name `.monitors`
      # and `.layouts` explicitly — so this bundling surprises nobody who does not ask for it.
      nixosModules.default = { imports = [ ./modules/monitors.nix ./modules/layouts.nix ./modules/roles.nix ]; };
      systemManagerModules.monitors = ./modules/monitors.nix;
      systemManagerModules.layouts = ./modules/layouts.nix;
      systemManagerModules.roles = ./modules/roles.nix;
      systemManagerModules.default = { imports = [ ./modules/monitors.nix ./modules/layouts.nix ./modules/roles.nix ]; };

      # ── DYNAMIC OUTPUT PROFILES ───────────────────────────────────────────────────────────
      # kanshi profiles generated from `nixdisplay.layouts`, for the one thing a compositor's own
      # output config cannot express: switching an output OFF *because other outputs are present*.
      # A home-manager module that writes `~/.config/kanshi/config` AND declares its own
      # graphical-session user service — self-contained, borrowing nothing from a sibling repo's
      # session layer (see the module's own header for why nixdisplay owns its daemon end to end).
      # A host that enables it must leave the compositor's own output config unset: exactly one owner
      # per output, or the two race and the last writer wins.
      homeManagerModules.kanshi = ./home/kanshi.nix;
      homeManagerModules.default = ./home/kanshi.nix;

      # ── CHECKS ────────────────────────────────────────────────────────────────────────────
      # `nix flake check` only type-checks that `*Modules` ARE modules; it never evaluates them. Both
      # tables are nothing but assertions over derived arithmetic — identity strings, the logical
      # rectangle an output occupies once scale and transform are applied, the overlap test on top —
      # which is precisely the code that ships broken while `flake check` stays green. These evaluate
      # the real modules against fixtures and assert every fired message. See each check's own header
      # for the silent runtime failure (a matcher that matches nothing; niri auto-placing a
      # wrongly-"overlapping" output and logging one warn line) it exists to make loud.
      checks = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in
        {
          monitor-identity = import ./checks/monitor-identity.nix { inherit pkgs; };
          layout-geometry = import ./checks/layout-geometry.nix { inherit pkgs; };
        });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixpkgs-fmt);
    };
}
