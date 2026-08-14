# nixdisplay

The monitor registry, output layouts and dynamic output profiles for a declarative, CPU-rendered
Wayland desktop, as reusable Nix modules. Fleet-wide monitor **identity** (a panel roams between
hosts), per-host output **geometry** (mode, scale, position, transform, with build-time overlap and
positioning checks), and hotplug-reactive **kanshi profiles** — the arrangement chosen by *what is
plugged in*, not by a config that can only describe one union of every output a host might see.

## The split

`nixdisplay` was extracted out of [nixdesktop][nixdesktop], where these modules originally lived as
`modules/monitors.nix`, `modules/layouts.nix` and `home/kanshi.nix`. nixdesktop still owns the
compositor-neutral **policy** layer (which desktop roles a session wants filled, published as
`nixdesktop.want`), the **session** layer (turning session components into systemd user services),
and the shared **chrome** (bars, notifiers, lock). This repo owns exactly the *display* concern:
which panels exist, where they sit, and which arrangement applies when.

Why its own repo, not a file in nixdesktop: this family graduates a concern to its own repo when it
can be **independently declared** and reads **nothing** from its siblings. Output geometry qualifies
on both counts — a headless box or an evdi-only dock wants it with no desktop shell at all (the
estate's own server console declares a layout and nothing else), and after the move these modules
read only their own `nixdisplay.*` namespace. That is why nixdisplay's *only* flake input is
`nixpkgs`: unlike the compositor siblings it does not even need `lib.probeFact`, because it owns the
tables it reads rather than probing them out of another repo. A lodger that reads nothing from the
house is a repo, not a room.

**Mechanism public, values private.** Every option here is schema and assertion; no default names a
real monitor, host or connector. A consumer fills `nixdisplay.monitors` / `nixdisplay.layouts` with
their own hardware.

### Breaking change from nixdesktop's copy

The option namespace moved from `nixdesktop.{monitors,layouts,dynamicOutputs}` to
**`nixdisplay.{monitors,layouts,dynamicOutputs}`**, matching this family's convention (the top-level
attribute is always the repo's own name). This is a deliberate, un-shimmed breaking change,
consistent with the family's no-compatibility-aliases policy: a consumer migrating from nixdesktop's
copy renames every reference. Nothing else about the option surface changed in the move.

## Modules

| Module | Class(es) | Owns |
|---|---|---|
| `nixosModules.monitors`, `systemManagerModules.monitors` | NixOS · system-manager | `nixdisplay.monitors` — the fleet-wide EDID identity registry (make/model/serial, aliases, `nativeMode`; derives `identifier`/`identifiable`; asserts no two declarations resolve to one identity) |
| `nixosModules.layouts`, `systemManagerModules.layouts` | NixOS · system-manager | `nixdisplay.layouts` — per-host output geometry (mode/modeline, scale, position, transform, `enable`); asserts all-or-nothing positioning and non-overlapping logical rectangles |
| `nixosModules.default`, `systemManagerModules.default` | NixOS · system-manager | both registries together — the common case for a host that addresses monitors by identity |
| `homeManagerModules.kanshi` (= `.default`) | home-manager | `nixdisplay.dynamicOutputs` — kanshi profiles generated from the layouts, plus kanshi's own graphical-session user service |

Both registries are pure option+assertion modules with no `pkgs` argument and no plane-specific
config, so the same file composes into a NixOS, system-manager or home-manager evaluation unchanged.
A compositor config that *reads* them does so via `lib.probeFact` against whatever tree it is
composed in — it never imports these modules — which is why there is deliberately no
`homeManagerModules.{monitors,layouts}`.

## Dynamic output profiles (kanshi)

`nixdisplay.dynamicOutputs` turns declared `nixdisplay.layouts` entries into kanshi profiles, for
the one thing a compositor's own output config cannot express: switching an output **off *because*
other outputs are present**. "The laptop panel is off while docked" is a statement about the *set*
of connected outputs, and no compositor config language has a concept of the current set; kanshi's
does. It selects a profile by an **exact cover** of the connected heads — see the module header for
the bijection rule the man pages only half-document (kanshi 1.9.0 `main.c:42-95`) and for why
`tolerateUnknownOutputs` defaults to false.

> ⚠ **Exactly one owner per output.** kanshi is an ordinary Wayland client submitting an output
> configuration; the compositor also applies its own at startup and every reload, and the last
> writer wins (the documented cause of sway#6863, kanshi#43, niri#676). A host that enables
> `dynamicOutputs` **must** leave the compositor's own layout unset.

nixdisplay declares kanshi as its **own** `systemd.user.services.kanshi` (bound to
`graphical-session.target`), borrowing nothing from nixdesktop's session-service layer: kanshi is a
dependency-free leaf, so it needs none of that layer's ordering/restart machinery, and writing into
a sibling's `nixdesktop.session.services` namespace would re-couple the two repos exactly where the
split exists to separate them.

## The cross-repo contracts

nixdisplay reads **nothing** functional from a sibling — its only `nixdesktop` mention anywhere in
the tree is one documentation cross-reference. It is instead *read by* several repos, all
**defensively** through `lib.probeFact` (none takes a flake input on nixdisplay), so a host that
composes a reader without nixdisplay sees the fallback rather than an evaluation error:

| Reader | Reads | For |
|---|---|---|
| [nixscroll][nixscroll] `home/scroll.nix` | `nixdisplay.layouts`, `nixdisplay.monitors` | translating a named layout into scroll `output` blocks |
| [nixniri][nixniri] `home/niri.nix` | `nixdisplay.layouts`, `nixdisplay.monitors` | the same for niri (retired fleet-wide, but the repo still reads the tables) |
| [nixdesktop][nixdesktop] `modules/session.nix` | `nixdisplay.layouts` | validating that a `sessions.<name>.layout` pointer names a declared layout |

## Status

Early. Extracted from nixdesktop; `nix flake check` is green for the eval-time modules —
`checks/monitor-identity.nix` and `checks/layout-geometry.nix` evaluate the real modules against
fixtures and assert every fired message (the identity derivation, the logical rectangle an output
occupies once scale and transform are applied, the strict overlap test on top). The kanshi
home-manager module is hand-verified, since `nix flake check` does not evaluate `homeManagerModules`
at all. Cutting the consumers (nixdesktop, nixscroll, infra) over to this repo, and enabling
`dynamicOutputs` on the hosts that want it, is the follow-on, deploy-gated work. No compatibility
shims at this stage.

[nixdesktop]: https://github.com/julian-corbet/nixdesktop-corbet-ch
[nixscroll]: https://github.com/julian-corbet/nixscroll-corbet-ch
[nixniri]: https://github.com/julian-corbet/nixniri-corbet-ch

## License

MIT
