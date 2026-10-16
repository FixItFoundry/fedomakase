# Fedomakase

An opinionated Hyprland desktop for **Fedora Linux**, ported from [Omarchy](https://omarchy.org) (`quattro`).

## What it is

Fedomakase (*Fedora* + *Omakase*) brings Omarchy's curated Hyprland setup — keybindings, CLI utilities, themes, web app integration — to Fedora 44 and later, using native Fedora tooling throughout. Upstream Omarchy targets Arch; this port tracks mainline `quattro` while swapping the Arch-specific pieces for Fedora equivalents.

## How it works

- **Base system**: built on the official Fedora Everything Netinstall ISO with a customized Anaconda kickstart.
- **Installer**: Anaconda's `%pre` stage runs a [Gum](https://github.com/charmbracelet/gum) TUI on TTY3 (after waiting for KMS console geometry to stabilize) for keyboard layout / CJK input method, disk selection, LUKS2 encryption, user account, hostname, and timezone setup. Choices are written to a `%include` file that drives partitioning and identity. No hardcoded credentials anywhere.
- **Bootloader**: native Fedora `GRUB2` configured with a 1-second hidden menu timeout (`GRUB_TIMEOUT=1`, `GRUB_TIMEOUT_STYLE=hidden`), `quiet rhgb systemd.tty.term.console=dumb plymouth.enable=1` kernel arguments (suppressing terminal query garbage on TTY before Plymouth/SDDM), and `omarchy-system reboot-boot-menu` integration via `grub2-editenv - set menu_show_once=1`.
- **Packages**: `pacman`/`AUR` become `dnf`/`rpm`/`COPR` (with Flatpak fallbacks for optional third-party apps). The ISO's package list is generated at build time from [`omarchy/install/omarchy-fedora-base.packages`](omarchy/install/omarchy-fedora-base.packages), with every entry resolved in a single batch against live repo metadata.
- **Hyprland stack**: [nett00n/hyprland](https://copr.fedorainfracloud.org/coprs/nett00n/hyprland/) COPR (`hyprland`, `quickshell`, `uwsm`, `hyprland-guiutils`, and the rest of the compositor stack).
- **Omarchy tools & COPRs**:
  - [whelanh/omarchy](https://copr.fedorainfracloud.org/coprs/whelanh/omarchy/) (`aether`, `cliamp`, `disktree-bin`, `elsewhen`, `gliff`, `herdr`, `hype`, `hyprland-preview-share-picker`, `monologue`, `omacalc`, `omacut`, `omarchy-hyprland-titlebars`, `omasnap`, `omavox`, `omawrite`, `owe`, `owe-lockfeed`, `signed`, `try`, `ttfx`)
  - [scottames/ghostty](https://copr.fedorainfracloud.org/coprs/scottames/ghostty/) (`ghostty`)
  - [atim/starship](https://copr.fedorainfracloud.org/coprs/atim/starship/) (`starship`)
  - [boobaa/lazygit](https://copr.fedorainfracloud.org/coprs/boobaa/lazygit/) (`lazygit`)
  - [jdxcode/mise](https://copr.fedorainfracloud.org/coprs/jdxcode/mise/) (`mise`)
  - [anudeepd/localsend](https://copr.fedorainfracloud.org/coprs/anudeepd/localsend/) (`localsend`)
  - [brycensranch/gpu-screen-recorder-git](https://copr.fedorainfracloud.org/coprs/brycensranch/gpu-screen-recorder-git/) (`gpu-screen-recorder`, with native `wf-recorder` also installed as fallback)
  - [lecris/moonlight](https://copr.fedorainfracloud.org/coprs/lecris/moonlight/) (`moonlight-qt`)
- **Updates**: a post-update hook re-applies the Fedora adaptations whenever upstream Omarchy refreshes, so updates don't clobber the port.
- **TPM2 unlock**: with LUKS and a TPM2 chip, the passphrase is enrolled against PCRs 0+7 during install and dracut ships the `tpm2-tss` module.

## What changed from upstream

| Area | Arch (upstream) | Fedora (here) |
|---|---|---|
| Package manager | `pacman` / `yay` | `dnf` / `rpm` + Flatpak fallback |
| Community packages | AUR | COPR (`omarchy-fedora-copr.repos`) |
| Bootloader | `limine` + `limine-mkinitcpio-hook` | `GRUB2` + `grub2-editenv menu_show_once=1` |
| Initramfs | `mkinitcpio` | `dracut` |
| Firewall | `ufw` | `firewalld` (`firewall-cmd`) |
| App launcher wrapper | `uwsm-app` (shipped in Arch `uwsm`) | `/usr/share/omarchy/bin/uwsm-app` (`exec uwsm app "$@"`) |
| Terminal default | manual selection | `xdg-terminal-exec` seed |
| Display manager | SDDM, Arch configs | SDDM launching Hyprland via `uwsm` |
| Package testing | `PKGBUILD` / `makepkg` | `.spec` / `rpmbuild` |

The full breakdown is in [fedomakase-fixes.md](fedomakase-fixes.md).

## Building an ISO

You need a Fedora 44+ host with `bsdtar`, `rsync`, `wget`, `dnf`, `xorriso`, `isomd5sum`, network access, and the [Fedora Everything Netinstall ISO](https://fedoraproject.org/workstation/download). ISOs can be flashed to USB or booted via [Ventoy](https://www.ventoy.net/).

Netinstall (fetches packages during setup, ~1.3 GB):

```bash
sudo bash build/build-netinstall-iso.sh /path/to/Fedora-Everything-netinst-x86_64-44-*.iso
```

This produces `fedomakase-44-x86_64.iso`. Unresolvable packages warn, missing critical packages abort.

Offline (self-contained, ~3 GB):

```bash
sudo bash build/build-offline-iso.sh /path/to/Fedora-Everything-netinst-x86_64-44-*.iso
```

## Installing on an existing system

If you already run Omarchy on Fedora:

```bash
sudo bash scripts/apply.sh
```

This installs the patch runner into `/usr/share/omarchy`, syncs Fedora helpers, enables all COPR repositories, installs the base package manifest, applies all patches once, and registers the post-update hook. To re-apply manually after an upstream update:

```bash
sudo omarchy-apply-fedora-patches
```

To verify the port is intact at any time (no root needed):

```bash
OMARCHY_PATH=/usr/share/omarchy bash /usr/share/omarchy/bin/omarchy-apply-fedora-patches --check
```

## Repo layout

```
fedomakase/
├── build/
│   ├── build-netinstall-iso.sh    # Builds fedomakase-44-x86_64.iso
│   └── build-offline-iso.sh       # Builds the offline ISO
├── omarchy/                       # Payload installed to /usr/share/omarchy
│   ├── installer/                 # Gum TUI + kickstarts
│   ├── etc/sddm.conf.d/           # SDDM uwsm session config
│   └── install/
│       ├── omarchy-fedora-base.packages   # Package list, single source of truth
│       └── omarchy-fedora-copr.repos      # COPR configuration
├── scripts/
│   ├── apply.sh                   # Bootstrap for running systems
│   ├── omarchy-apply-fedora-patches  # Patch runner (also the post-update hook target)
│   ├── omarchy-setup-tpm2-unlock  # TPM2 enrollment helper
│   └── omarchy-dev-pkg-test       # rpmbuild packaging test tool
├── test/
│   ├── build-checks.sh            # Static sanity checks
│   └── hook-checks.sh             # Post-update hook checks
└── fedomakase-fixes.md            # Detailed changelog
```

## License

Same terms as upstream Omarchy (see [LICENSE](omarchy/LICENSE)). Omarchy itself is by the [Omarchy team](https://omarchy.org).
