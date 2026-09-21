# Fedomakase

An opinionated Hyprland desktop for **Fedora Linux**, ported from [Omarchy](https://omarchy.org).

## What it is

Fedomakase (*Fedora* + *Omakase*) brings Omarchy's curated Hyprland setup — keybindings, CLI utilities, themes, web app integration — to Fedora 44 and later, using native Fedora tooling throughout. Upstream Omarchy targets Arch; this port tracks it while swapping the Arch-specific pieces for Fedora equivalents.

## How it works

- **Base system**: built on the official Fedora Everything Netinstall ISO with a customized Anaconda kickstart.
- **Installer**: Anaconda's `%pre` stage runs a [Gum](https://github.com/charmbracelet/gum) TUI on TTY3 for disk selection, LUKS2 encryption, and user setup. Choices are written to a `%include` file that drives partitioning. No hardcoded credentials anywhere.
- **Packages**: `pacman`/`AUR` become `dnf`/`rpm`/`COPR`. The ISO's package list is generated at build time from [`omarchy/install/omarchy-fedora-base.packages`](omarchy/install/omarchy-fedora-base.packages), with every entry resolved against live repo metadata.
- **Hyprland stack**: [nett00n/hyprland](https://copr.fedorainfracloud.org/coprs/nett00n/hyprland/) COPR (hyprland, quickshell, uwsm, and the rest of the compositor stack).
- **Omarchy tools**: [whelanh/omarchy](https://copr.fedorainfracloud.org/coprs/whelanh/omarchy/) COPR (aether, omacut, omawrite, tensaku, and the other first-party binaries), plus [scottames/ghostty](https://copr.fedorainfracloud.org/coprs/scottames/ghostty/) for the terminal and [atim/starship](https://copr.fedorainfracloud.org/coprs/atim/starship/) for the prompt.
- **Updates**: a post-update hook re-applies the Fedora adaptations whenever upstream Omarchy refreshes, so updates don't clobber the port.
- **TPM2 unlock**: with LUKS and a TPM2 chip, the passphrase is enrolled against PCRs 0+7 during install and dracut ships the `tpm2-tss` module.

## What changed from upstream

| Area | Arch (upstream) | Fedora (here) |
|---|---|---|
| Package manager | `pacman` / `yay` | `dnf` / `rpm` |
| Community packages | AUR | COPR |
| Initramfs | `mkinitcpio` | `dracut` |
| Firewall | `ufw` | `firewalld` |
| App launcher wrapper | `uwsm-app` | `uwsm app` |
| Terminal default | manual selection | `xdg-terminal-exec` seed |
| Display manager | SDDM, Arch configs | SDDM launching Hyprland via `uwsm` |
| Package testing | `PKGBUILD` / `makepkg` | `.spec` / `rpmbuild` |

The full breakdown is in [fedomakase-fixes.md](fedomakase-fixes.md).

## Building an ISO

You need a Fedora 44+ host with `bsdtar`, `rsync`, `wget`, `dnf`, network access, and the [Fedora Everything Netinstall ISO](https://fedoraproject.org/workstation/download). ISOs can be flashed to USB or booted via [Ventoy](https://www.ventoy.net/).

Netinstall (fetches packages during setup, ~1.3 GB):

```bash
sudo bash build/build-netinstall-iso.sh /path/to/Fedora-Everything-netinst-x86_64-44-*.iso
```

This produces `fedomakase-44-x86_64.iso`. Unresolvable packages warn, missing critical packages abort.

Offline (self-contained, ~3 GB, still needs hardware verification):

```bash
sudo bash build/build-offline-iso.sh /path/to/Fedora-Everything-netinst-x86_64-44-*.iso
```

## Installing on an existing system

If you already run Omarchy on Fedora:

```bash
sudo bash scripts/apply.sh
```

This installs the patch runner into `/usr/share/omarchy`, applies everything once, and registers the post-update hook. To re-apply manually after an upstream update:

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
