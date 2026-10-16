# Fedomakase — Technical Fixes & Changes Reference

This document details all changes made to port Omarchy (`quattro`) from Arch Linux to Fedora for **Fedomakase**.

## Overview

Omarchy upstream targets Arch Linux. This port adapts the installer, bootloader integration, scripts, package helpers, migrations, menus, and documentation to work natively on Fedora 44+ while preserving the same UX and feature set.

Key differences:
- **Package manager**: `pacman` / `yay` → `dnf` / `rpm` (with Arch→Fedora alias mapping and Flatpak fallback)
- **Community repositories**: AUR → 9 targeted COPRs (`omarchy-fedora-copr.repos`)
- **Bootloader**: `limine` + UKI → native Fedora `GRUB2` (`systemd.tty.term.console=dumb plymouth.enable=1`, 1s hidden timeout, `menu_show_once=1` for `reboot-boot-menu`)
- **Build format**: `PKGBUILD`/`makepkg` → `.spec`/`rpmbuild`
- **Initramfs**: `mkinitcpio` → `dracut`
- **Firewall**: `ufw` → `firewalld` (`firewall-cmd`)
- **App launcher wrapper**: `uwsm-app` (shipped in Arch's `uwsm` package, omitted by `nett00n/hyprland`'s `uwsm` RPM) → `/usr/share/omarchy/bin/uwsm-app` (`#!/bin/sh` + `exec uwsm app "$@"`) symlinked at `/usr/local/bin/uwsm-app`
- **TPM**: TPM2-only enrollment with dracut `tpm2-tss` module (`/etc/dracut.conf.d/tpm2.conf`)

---

## Mainline `quattro` Integration (`51bfd1d`)

### 1. First-Party Binaries & Targeted COPRs (`omarchy-fedora-copr.repos`)
- **`nett00n/hyprland`**: `hyprland`, `hyprpaper`, `hyprlock`, `hypridle`, `hyprpicker`, `hyprsunset`, `xdg-desktop-portal-hyprland`, `quickshell`, `uwsm`, `hyprland-guiutils`
- **`whelanh/omarchy`**: `aether`, `cliamp`, `disktree-bin`, `elsewhen`, `gliff`, `herdr`, `hype`, `hyprland-preview-share-picker`, `monologue`, `omacalc`, `omacut`, `omarchy-hyprland-titlebars`, `omasnap` (replaced `tensaku`), `omavox`, `omawrite`, `owe`, `owe-lockfeed`, `signed` (replaced `xournalpp`), `try`, `ttfx` (replaced `python-terminaltexteffects`)
- **`scottames/ghostty`**: `ghostty`
- **`atim/starship`**: `starship`
- **`boobaa/lazygit`**: `lazygit`
- **`jdxcode/mise`**: `mise`
- **`anudeepd/localsend`**: `localsend`
- **`brycensranch/gpu-screen-recorder-git`**: `gpu-screen-recorder` (with Fedora native `wf-recorder` also installed in the base manifest as fallback)
- **`lecris/moonlight`**: `moonlight-qt`

### 2. Bootloader (`GRUB2`) & Console Integration
- Upstream `quattro` uses Limine with `systemd.tty.term.console=dumb` to prevent systemd v258+ from emitting terminal capability queries that print garbage characters on the Linux VT before Plymouth/SDDM take over.
- Fedomakase keeps Fedora's native **GRUB2** (preserving Btrfs/BLS/Secure Boot integration) and passes:
  `bootloader --timeout=1 --append="quiet rhgb systemd.tty.term.console=dumb plymouth.enable=1"`
- Kickstart `%post` sets `GRUB_TIMEOUT=1` and `GRUB_TIMEOUT_STYLE=hidden` in `/etc/default/grub`, regenerates `/boot/grub2/grub.cfg`, and installs `/etc/sudoers.d/omarchy-grub-bootmenu` (`0440`) allowing `%wheel` passwordless `grub2-editenv - set menu_show_once=1`.
- `bin/omarchy-system` (`reboot-boot-menu` subcommand) runs `sudo -n /usr/bin/grub2-editenv - set menu_show_once=1` before calling `systemctl reboot --boot-loader-menu=0 --no-wall 2>/dev/null || systemctl reboot --no-wall`, so selecting "Reboot to Boot Menu" in the Omarchy menu shows the GRUB menu on the next boot.

### 3. Interactive TTY Installer (`omarchy/installer/omarchy-installer.sh`)
- **KMS Console Stabilization (`wait_for_stable_terminal`)**: Waits for `/sys/class/graphics/fb0/virtual_size` and `stty size` to stabilize before measuring `COLUMNS` and drawing the Gum banner, preventing KMS mode-switching from mis-centering the UI.
- **Keyboard Layout & CJK Input Method**: Prompts from the 52-entry `OMARCHY_KEYBOARD_LAYOUTS` table (synced with `install/provisioning/setup-form.sh`), immediately loads the console keymap via `loadkeys` so LUKS and user passwords are typed in the selected layout, and writes `/tmp/fedomakase-input-method` (relayed to `/etc/omarchy/input-method` in `%post`) for Fcitx5/XKB seeding on first login.
- **Hostname & Timezone**: Prompts for RFC-1123 hostname (default `omarchy`) and timezone via `gum filter` over `/usr/share/zoneinfo/zone1970.tab` (default `UTC`), emitting `keyboard`, `timezone`, and `network --hostname=` directives into `/tmp/fedomakase-part.cfg`.

### 4. `uwsm-app` Wrapper (`/usr/share/omarchy/bin/uwsm-app`)
- Arch's `uwsm` package ships `/usr/bin/uwsm-app`, whereas `nett00n/hyprland`'s `uwsm` RPM only ships `/usr/bin/uwsm`.
- Instead of running `find /usr/share/omarchy -type f -exec sed -i 's|uwsm-app|uwsm app|g'` (which previously traversed 100+ MB of binary theme wallpapers/videos and still missed compiled binaries like `Elephant` and `Walker`), Fedomakase ships `/usr/share/omarchy/bin/uwsm-app` (`#!/bin/sh` + `exec uwsm app "$@"`) and symlinks `/usr/local/bin/uwsm-app -> /usr/share/omarchy/bin/uwsm-app` in both kickstarts, `scripts/apply.sh`, and `scripts/omarchy-apply-fedora-patches`.

### 5. Package Helpers & Alias Mapping (`bin/omarchy-pkg-*`)
- `omarchy-pkg-present`, `omarchy-pkg-missing`, `omarchy-pkg-add`, `omarchy-pkg-aur-add`, and `omarchy-pkg-drop` share a bidirectional Arch↔Fedora package alias map (`brave-bin` ↔ `brave-browser`, `microsoft-edge-stable-bin` ↔ `microsoft-edge-stable`, `zen-browser-bin` ↔ `zen-browser`, `google-chrome` ↔ `google-chrome-stable`/`com.google.Chrome`, `visual-studio-code-bin` ↔ `code`, `libreoffice-fresh` ↔ `libreoffice-writer`, `mise-bin` ↔ `mise`, `voxtype-bin` ↔ `voxtype`, `python-terminaltexteffects` ↔ `ttfx`, `libpulse` ↔ `pulseaudio-libs`, `docker-buildx` ↔ `docker-buildx-plugin`, etc.).
- `omarchy-pkg-present` only queries `flatpak info` when the package is a Flatpak ID (`*.*.*`) or has a known Flatpak alias, eliminating ~35 unnecessary `flatpak` subprocesses when rendering the Omarchy menu.
- `omarchy-update-restart` compares `uname -r` against the newest installed `kernel-core` RPM (`rpm -q --last kernel-core`) rather than checking if `/lib/modules/$(uname -r)` was deleted (since Fedora keeps 3 kernels via `installonly_limit=3`).
- `omarchy-update-orphan-pkgs` lists leaf packages via `dnf repoquery --unneeded -q` and prompts with `gum confirm` (unless `-y` is passed) instead of running `dnf autoremove -y` unconditionally.
- `omarchy-update-aur-pkgs` skips redundant work when `OMARCHY_UPDATE_LOGGED=1` because `omarchy-update-system-pkgs` already upgrades all enabled DNF and COPR repositories in a single transaction.

---

## Surviving Upstream Updates

```
omarchy update
  → omarchy-update runs the update pipeline
  → omarchy-hook post-update fires
  → ~/.config/omarchy/hooks/post-update.d/apply-fedora-patches.hook runs
  → restores stashed Fedora helpers from ~/.local/share/fedomakase/payload/
  → calls sudo omarchy-apply-fedora-patches
  → re-applies all Fedora-specific sed fixes, symlinks, and config files
```

### Verification

To verify all managed patches are intact at any time:

```bash
OMARCHY_PATH=/usr/share/omarchy bash /usr/share/omarchy/bin/omarchy-apply-fedora-patches --check
```

Or run the repository test suites:

```bash
bash test/build-checks.sh
bash test/hook-checks.sh
```
