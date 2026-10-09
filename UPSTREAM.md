# Upstream baseline

- Source: https://github.com/id-Software/DOOM
- Git submodule: `original/DOOM`
- Pinned commit: `a77dfb96cb91780ca334d0d4cfd86957558007e0`
- Retrieved: 2026-10-09
- Source mapping root: `original/DOOM/linuxdoom-1.10/`
- License: upstream `LICENSE.TXT` (GPL version 2), copied to the root `LICENSE`.
- Original source notices remain untouched. New project code uses `GPL-2.0-only`.
- No WAD or commercial assets are included. Public later fixtures use Freedoom Phase 1, with independent provenance and license.
- No Chocolate Doom code or reference substitution is used in Phase 0.

Restore with `git submodule update --init --recursive`. Verify with `git -C original/DOOM rev-parse HEAD`.
