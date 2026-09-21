# Fedomakase 🍱

An opinionated, curated Hyprland desktop environment for **Fedora Linux** — built as a direct homage to [Omarchy](https://omarchy.org).

---

## 🌟 What is Fedomakase?

**Fedomakase** (*Fedora* + *Omakase*) brings the "Chef's Choice", highly-curated Hyprland desktop experience of Omarchy to the Fedora Linux ecosystem.

While upstream Omarchy targets Arch Linux, Fedomakase ports the entire desktop experience—its keybindings, custom CLI utilities, wayland sessions, theme engines, and web app integration—directly onto **Fedora 44+**, leveraging native Fedora tooling.

---

## 🛠️ How It Works

- **Base System**: Built on top of the official **Fedora Everything Netinstall ISO** using a customized Anaconda Kickstart.
- **Interactive TTY Installer**: Anaconda's `%pre` stage launches a [Gum](https://github.com/charmbracelet/gum) TUI on TTY3 for disk selection, **LUKS2 encryption**, and user setup. Choices are written to a `%include` file that drives real partitioning — there are no hardcoded credentials anywhere in the kickstart.
- **Package Architecture**: `pacman`/`AUR` replaced with native `dnf`, `rpm`, and COPR. The ISO's `%packages` block is generated at build time from [`omarchy/install/omarchy-fedora-base.packages`](omarchy/install/omarchy-fedora-base.packages) — the single source of truth — with every package resolved against live repo metadata.
- **Hyprland Stack**: [nett00n/hyprland](https://copr.fedorainfracloud.org/coprs/nett00n/hyprland/) COPR (automated, Fedora 43/44/45, x86_64+aarch64). Covers hyprland, quickshell, uwsm, and everything else the manifest needs.
- **Omarchy Binaries**: [whelanh/omarchy](https://copr.fedorainfracloud.org/coprs/whelanh/omarchy/) COPR (aether, cliamp, herdr, hyprland-preview-share-picker, omacalc, omacut, omawrite, tensaku, try, ttfx) + [scottames/ghostty](https://copr.fedorainfracloud.org/coprs/scottames/ghostty/) for ghostty.
- **Self-Healing Updates**: A post-update hook re-applies all Fedora-specific adaptations whenever upstream Omarchy components are refreshed.
- **TPM2 Auto-Unlock**: When LUKS is chosen and a TPM2 is present, the passphrase is enrolled against PCRs 0+7 automatically during install; dracut ships the `tpm2-tss` module.

# COPR / Custom packages (nett00n/hyprland + whelanh/omarchy + scottames/ghostty) are
# resolved at build time; all manifest names must resolve or the build warns.

---

## 🔧 Summary of Fixes & Adaptations

| Subsystem | Upstream (Arch) | Fedomakase (Fedora) |
|---|---|---|
| **Package Manager** | `pacman` / `yay` | `dnf` / `rpm` |
| **User Repositories** | Arch User Repository (`AUR`) | Fedora `COPR` |
| **Initramfs Generation** | `mkinitcpio` | `dracut` (with `tpm2-tss` module) |
| **TPM Auto-Unlock** | `systemd-cryptenroll` | `systemd-cryptenroll` + `dracut -f` (PCRs 0+7) |
| **Firewall Management** | `ufw` | `firewalld` (`firewall-cmd`) |
| **Wayland Application Launcher** | `uwsm-app` wrapper | `uwsm app` native execution |
| **Default Terminal** | Manual terminal selection | `xdg-terminal-exec` pre-seeded config |
| **Display Manager** | SDDM with custom Arch configs | SDDM launching Hyprland through `uwsm` |
| **Packaging Test Tool** | `PKGBUILD` / `makepkg` | `.spec` / `rpmbuild` (`omarchy-dev-pkg-test`) |

For the complete line-by-line breakdown of every script, configuration, and binary modified, see [fedomakase-fixes.md](fedomakase-fixes.md).

---

## 💿 ISO Building & Usage

Scripts generate bootable ISOs flashable to USB or bootable via [Ventoy](https://www.ventoy.net/).

### Prerequisites

- Fedora 44 (or later) host system
- `bsdtar`, `rsync`, `wget`, `dnf` (network access required for package resolution)
- Official [Fedora Everything Netinstall ISO](https://fedoraproject.org/workstation/download)

### 1. Netinstall ISO (requires internet during installation)

Builds an ISO (~1.3 GB) that fetches latest packages over the network during Anaconda setup:

```bash
sudo bash build/build-netinstall-iso.sh /path/to/Fedora-Everything-netinst-x86_64-44-*.iso
```

**Output:** `fedomakase-44-x86_64.iso`

The build resolves every manifest package against live metadata, splices the resolved set into the kickstart, warns about unresolvable names, hard-fails if any critical package (hyprland, quickshell, sddm…) can't be found, and verifies the payload before repacking.

### 2. Offline ISO (no internet during installation) — Phase 2

Builds a self-contained DVD (~3+ GB) mirroring all manifest packages into an embedded local repository:

```bash
sudo bash build/build-offline-iso.sh /path/to/Fedora-Everything-netinst-x86_64-44-*.iso
```

**Output:** `fedomakase-offline-44-x86_64.iso`

> ⚠️ The offline install path still needs verification on real hardware before it can be trusted (Anaconda mount-layout assumptions).

---

## 🚀 Installing on an Existing System

If you already have a Fedora system running Omarchy and want the Fedomakase adaptations:

```bash
sudo bash scripts/apply.sh
```

This installs the patch runner and helpers into `/usr/share/omarchy`, applies all idempotent patches once, and registers the post-update hook in `~/.config/omarchy/hooks/post-update.d/`.

To manually re-apply after an upstream update:

```bash
sudo omarchy-apply-fedora-patches
```

---

## 📁 Repository Structure

```
fedomakase/
├── build/
│   ├── build-netinstall-iso.sh    # Builds fedomakase-44-x86_64.iso
│   └── build-offline-iso.sh       # Builds fedomakase-offline-44-x86_64.iso
├── omarchy/                       # Embedded Omarchy payload (installed to /usr/share/omarchy)
│   ├── installer/
│   │   ├── omarchy-installer.sh   # Gum TUI run from Anaconda %pre (TTY3)
│   │   ├── omarchy-ks.cfg         # Netinstall kickstart (canonical)
│   │   └── omarchy-ks-offline.cfg # Offline kickstart (canonical)
│   ├── etc/sddm.conf.d/           # SDDM uwsm session config
│   └── install/
│       ├── omarchy-fedora-base.packages   # Single source of truth for packages
│       └── omarchy-fedora-copr.repos      # COPR configuration
├── scripts/
│   ├── apply.sh                   # One-time bootstrap on a running system
│   ├── omarchy-apply-fedora-patches  # Idempotent patch runner (post-update hook)
│   ├── omarchy-setup-tpm2-unlock  # Standalone TPM2 enrollment helper
│   └── omarchy-dev-pkg-test       # rpmbuild-based packaging test tool
├── test/build-checks.sh           # Static sanity checks for the port
└── fedomakase-fixes.md            # Detailed technical changelog
```

---

## 📜 License & Credits

- **Fedomakase** is an open-source homage port maintained by the community.
- Original **Omarchy** concept and desktop environment by the [Omarchy Team](https://omarchy.org).
- Licensed under the same terms as upstream Omarchy (see [LICENSE](omarchy/LICENSE)).
