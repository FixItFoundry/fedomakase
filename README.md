# Fedomakase 🍱

An opinionated, curated Hyprland desktop environment for **Fedora Linux** — built as a direct homage to [Omarchy](https://omarchy.org).

---

## 🌟 What is Fedomakase?

**Fedomakase** (*Fedora* + *Omakase*) brings the "Chef's Choice", highly-curated Hyprland desktop experience of Omarchy to the Fedora Linux ecosystem. 

While upstream Omarchy targets Arch Linux, Fedomakase ports the entire desktop experience—its keybindings, custom CLI utilities, wayland sessions, theme engines, and web app integration—directly onto **Fedora 44+**, leveraging native Fedora tooling.

---

## 🛠️ How It Works

- **Base System**: Built on top of the official **Fedora Everything Netinstall ISO** using customized Anaconda Kickstart (`.cfg`) configurations.
- **Package Architecture**: Replaced Arch `pacman` and `AUR` dependencies with native `dnf`, `rpm`, and Fedora `COPR` repositories (e.g. Hyprland COPR).
- **Interactive TTY Installer**: Features a native terminal installer powered by [Gum](https://github.com/charmbracelet/gum) for disk selection, LUKS encryption, and user setup.
- **Self-Healing Updates**: Includes a post-update hook infrastructure that automatically re-applies Fedora-specific adaptations whenever upstream Omarchy components are updated.

> 🚧 **Work in Progress: Custom COPR**  
> We are actively building a dedicated **Fedomakase COPR repository** to package the few remaining non-native Omarchy binaries into official `.rpm` spec files. Until then, missing utilities are smoothly linked to native DNF/COPR alternatives.

---

## 🔧 Summary of Fixes & Adaptations

Porting Omarchy from Arch Linux to Fedora required several structural adaptations:

| Subsystem | Upstream (Arch) | Fedomakase (Fedora) |
|---|---|---|
| **Package Manager** | `pacman` / `yay` | `dnf` / `rpm` |
| **User Repositories** | Arch User Repository (`AUR`) | Fedora `COPR` |
| **Initramfs Generation** | `mkinitcpio` | `dracut` (with `tpm2-tss` module) |
| **TPM Auto-Unlock** | `clevis` / legacy keyfiles | `systemd-cryptenroll` + `dracut -f` |
| **Firewall Management** | `ufw` | `firewalld` (`firewall-cmd`) |
| **Wayland Application Launcher** | `uwsm-app` wrapper | `uwsm app` native execution |
| **Default Terminal** | Manual terminal selection | `xdg-terminal-exec` pre-seeded config |
| **Display Manager** | SDDM with custom Arch configs | SDDM with Fedora Wayland session integration |
| **Packaging Test Tool** | `PKGBUILD` / `makepkg` | `.spec` / `rpmbuild` (`omarchy-dev-pkg-test`) |

For a complete line-by-line breakdown of every script, configuration, and binary modified, see [fedomakase-fixes.md](fedomakase-fixes.md).

---

## 💿 ISO Building & Usage

Fedomakase provides scripts to generate bootable ISOs that can be flashed to a USB drive or booted directly via [Ventoy](https://www.ventoy.net/).

### Prerequisites

- Fedora 44 (or later) host system
- `bsdtar`, `xorriso`, `dnf`, `wget` installed
- Official [Fedora Everything Netinstall ISO](https://fedoraproject.org/workstation/download)

### 1. Netinstall ISO (Requires internet during installation)

Builds a lightweight ISO (~1.3 GB) that fetches the latest packages over the network during Anaconda setup:

```bash
sudo bash build/build-netinstall-iso.sh /path/to/Fedora-Everything-netinst-x86_64-44-*.iso
```

**Output:** `fedomakase-44-x86_64.iso`

### 2. Offline ISO (No internet required during installation)

Builds a self-contained DVD ISO (~3.2 GB) containing **1,500+ pre-mirrored Fedora & COPR packages** inside an embedded local repository:

```bash
sudo bash build/build-offline-iso.sh /path/to/Fedora-Everything-netinst-x86_64-44-*.iso
```

**Output:** `fedomakase-offline-44-x86_64.iso`

---

## 🚀 Installing on an Existing System

If you already have a Fedora system running and want to apply the Fedomakase environment and patches:

```bash
sudo bash scripts/apply.sh
```

This installs all configuration files, patched utilities, and registers the automatic post-update hook in `~/.config/omarchy/hooks/post-update.d/`.

If you ever need to manually re-apply patches after an upstream update:

```bash
sudo omarchy-apply-fedora-patches
```

---

## 📁 Repository Structure

```
Omarchy-Fedora/
├── build/
│   ├── build-netinstall-iso.sh    # Builds fedomakase-44-x86_64.iso
│   └── build-offline-iso.sh       # Builds fedomakase-offline-44-x86_64.iso
├── installer/
│   ├── omarchy-installer.sh       # Interactive TTY installer (Gum UI)
│   ├── omarchy-ks.cfg             # Netinstall Anaconda Kickstart
│   └── omarchy-ks-offline.cfg     # Offline Anaconda Kickstart
├── omarchy/                       # Embedded Omarchy payload with Fedora patches
├── scripts/
│   ├── apply.sh                   # Apply Fedomakase patches to running system
│   ├── apply-docs.sh              # Apply documentation updates
│   └── omarchy-apply-fedora-patches  # Post-update re-application script
├── fedomakase-fixes.md            # Detailed technical changelog of all fixes
└── apply-fedora-patches.hook      # Automatic post-update hook
```

---

## 📜 License & Credits

- **Fedomakase** is an open-source homage port maintained by the community.
- Original **Omarchy** concept and desktop environment by the [Omarchy Team](https://omarchy.org).
- Licensed under the same terms as upstream Omarchy (see [LICENSE](omarchy/LICENSE)).
