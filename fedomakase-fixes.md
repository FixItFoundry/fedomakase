# Fedomakase — Technical Fixes & Changes Reference

This document details all changes made to port Omarchy from Arch Linux to Fedora for **Fedomakase**.

## Overview

Omarchy upstream targets Arch Linux. This port adapts the installer, scripts, menus, and documentation to work on Fedora while preserving the same UX and feature set.

Key differences:
- Package manager: `pacman` → `dnf`/`rpm`
- User repo: AUR → COPR
- Build format: `PKGBUILD`/`makepkg` → `.spec`/`rpmbuild`
- Initramfs: `mkinitcpio` → `dracut`
- TPM: TPM2-only enrollment with dracut tpm2-tss module (removed TPM 1.2/clevis workaround)
- Default terminal: `xdg-terminal-exec` now ships with default config

---

## TPM2 Auto-Unlock

**Problem:** On Fedora, dracut replaces Arch's mkinitcpio for initramfs generation. The `tpm2-tss` dracut module must be explicitly enabled, and the crypttab entry needs `tpm2-device=auto` for systemd-cryptenroll to work at boot. Legacy keyfile-based workaround (TPM 1.2 via clevis) had invalid dracut syntax.

**Solution:** Rewrote TPM enrollment as TPM2-only. The enrollment flow now:
1. Enrolls LUKS key via `systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+7`
2. Creates `/etc/dracut.conf.d/tpm2.conf` with `add_dracutmodules+=" tpm2-tss "`
3. Removes legacy `/etc/dracut.conf.d/omarchy-keyfile.conf` (was broken mkinitcpio syntax)
4. Updates crypttab to add `tpm2-device=auto` option
5. Rebuilds initramfs via `dracut -f`

### TPM2 enrollment (the only path now)
```bash
# Enroll LUKS key
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+7 /dev/$luks_dev

# Configure dracut
echo 'add_dracutmodules+=" tpm2-tss "' | sudo tee /etc/dracut.conf.d/tpm2.conf

# Remove legacy keyfile config
sudo rm -f /etc/dracut.conf.d/omarchy-keyfile.conf

# Update crypttab
sudo sed -i "/$(cryptsetup luksUUID /dev/$luks_dev)/s/[[:space:]]*$/ tpm2-device=auto/" /etc/crypttab

# Rebuild initramfs
sudo dracut -f
```

### Why TPM 1.2/clevis was removed
- Fedora no longer ships `clevis` with TPM 1.2 support by default
- TPM 1.2 is obsolete hardware; modern systems (2016+) all have TPM 2.0
- The old workaround stored a keyfile on `/boot` with brittle mkinitcpio-style dracut syntax
- If TPM2 is unavailable at install time, the kickstart now prints a warning and skips enrollment

### Files modified
- `bin/omarchy-setup-tpm2-unlock` — Full rewrite: TPM2-only, adds dracut config, fixes crypttab update, rebuilds initramfs
- `installer/omarchy-ks.cfg` — Section 5 updated: TPM2-only, creates dracut config, removes legacy keyfile, rebuilds initramfs
- `installer/omarchy-ks-offline.cfg` — Same changes as online kickstart
- `scripts/omarchy-apply-fedora-patches` — Added dracut TPM2 config step, removes legacy keyfile

---

## Keybinding Fixes

**Problem:** The default `utilities.lua` shipped by Omarchy may not carry Fedora-specific keybinding adjustments, and the file is overwritten on every `dnf upgrade`.

**Solution:** `fedora-patches/utilities.lua` is copied to `default/hypr/bindings/utilities.lua` on every post-update hook run, ensuring Fedora keybindings survive upstream updates.

### Files modified
- `default/hypr/bindings/utilities.lua` — Maintained in `fedora-patches/utilities.lua`, restored by `omarchy-apply-fedora-patches`

---

## Webapp Manifests

**Problem:** Omarchy ships `.desktop` launcher files and icons in `/usr/share/omarchy/applications/` but does not deploy them to user `~/.local/share/applications/` or `/etc/skel/`. Users would not see Omarchy webapp entries in their app launcher.

**Solution:** The apply script copies all `.desktop` files and icons to every existing user's home directory and to `/etc/skel/` for future users.

### Files handled
- `/usr/share/omarchy/applications/*.desktop` — Deployed to each user's `~/.local/share/applications/` and `/etc/skel/.local/share/applications/`
- `/usr/share/omarchy/applications/icons/` — Deployed to each user's `~/.local/share/icons/` and `/etc/skel/.local/share/icons/`

---

## Firewall Fixes

**Problem:** Omarchy scripts use `ufw` (Arch convention) and the `uwsm-app` wrapper. Fedora ships `firewalld` and uses `uwsm app` directly.

**Solution:** Global `uwsm-app` → `uwsm app` replacement across all Omarchy scripts, plus targeted ufw → firewalld rewrites in the Sunshine and SSHD service scripts.

### Scripts patched
| Script | Change |
|--------|--------|
| All scripts in `/usr/share/omarchy/` | `uwsm-app` → `uwsm app` (global sed) |
| `omarchy-install-service-sunshine` | `ufw` → `firewall-cmd` for port rules |
| `omarchy-remove-service-sunshine` | `ufw` → `firewall-cmd` for port removal |
| `omarchy-setup-security-sshd` | `ufw` → `firewall-cmd` for ssh service |
| `omarchy-remove-security-sshd` | `ufw` → `firewall-cmd` for ssh removal |

---

## xdg-terminal-exec Default Config

**Problem:** `xdg-terminal-exec` was missing from kickstart `%packages` and had no default terminal preference installed. Users had to manually install it.

**Solution:** Added package to kickstart and installed default config to `/etc/xdg/`.

### Files modified
- `installer/omarchy-ks.cfg` — Added `xdg-terminal-exec` to `%packages`, copies `hyprland-xdg-terminals.list` to `/etc/xdg/xdg-terminals.list` in `%post`
- `installer/omarchy-ks-offline.cfg` — Same changes

---

## Menu Labels

**Problem:** Menu referenced Arch Wiki and AUR — misleading on Fedora.

### Changes
| Old | New |
|-----|-----|
| `learn.arch` → `wiki.archlinux.org` | `learn.fedora` → `docs.fedoraproject.org` |
| `"label":"AUR"` | `"label":"COPR"` |
| `"NordVPN [AUR]"` | `"NordVPN [COPR]"` |

### Files modified
- `default/omarchy/omarchy-menu.jsonc`

---

## Update Scripts

### omarchy-update-firmware
Hardcoded `/boot/EFI/arch/` → `/boot/EFI/fedora/`

### omarchy-update-analyze-logs
Replaced Arch `initcpios`/`Initcpio` grep patterns with Fedora `dracut`/`initramfs`/`initrd` patterns.

### omarchy-upgrade-to-quattro
Removed "designed for Arch Linux systems" message (script already noted Fedora as base).

### Files modified
- `bin/omarchy-update-firmware`
- `bin/omarchy-update-analyze-logs`
- `bin/omarchy-upgrade-to-quattro`

---

## Install Scripts — Package Names

Browser and service installers used AUR package names (often with `-bin` suffix) that don't exist in Fedora/COPR.

| Script | Old Package | New Package |
|--------|-------------|-------------|
| `omarchy-install-browser` (edge) | `microsoft-edge-stable-bin` | `microsoft-edge-stable` |
| `omarchy-install-browser` (brave) | `brave-bin` | `brave-browser` |
| `omarchy-install-browser` (brave-origin) | `brave-origin-bin` | `brave-browser-origin` |
| `omarchy-install-browser` (zen) | `zen-browser-bin` | `zen` |
| `omarchy-install-service-nordvpn` | `nordvpn-bin` | `nordvpn` |

Note: `google-chrome` is the same on both Arch and Fedora (from Google's repo).

### Files modified
- `bin/omarchy-install-browser`
- `bin/omarchy-install-service-nordvpn`

---

## Install Scripts — Comments

| File | Old | New |
|------|-----|-----|
| `bin/omarchy-install-editor-emacs` | "via the omarchy-emacs AUR package" | "via COPR" |
| `bin/omarchy-install-gaming-retroarch` | "installed by pacman" | "installed by dnf" |
| `bin/omarchy-theme-set-gnome` | "reached from arch-chroot" | "reached from chroot" |

### Files modified
- `bin/omarchy-install-editor-emacs`
- `bin/omarchy-install-gaming-retroarch`
- `bin/omarchy-theme-set-gnome`

---

## RetroArch — AUR-only Packages Removed

The `-git` suffixed libretro packages are AUR-only and don't exist in Fedora repos.

Removed:
- `libretro-cap32-git`
- `libretro-fbneo-git`
- `libretro-uae-git`
- `libretro-vice-x*-git` (all variants)
- `libretro-database-git`
- `retroarch-joypad-autoconfig-git`

Trailing backslash on `libretro-yabause` line fixed (was no longer last in list).

### Files modified
- `bin/omarchy-install-gaming-retroarch`

---

## Systemd Units

### omarchy-migrate-notify.service
Comment updated: `pacman writes that directory` → `dnf writes that directory`

### Files modified
- `default/systemd/user/omarchy-migrate-notify.service`

---

## Config Hooks

### pre-refresh-pacman.d/add-custom-repo.sample
Rewritten for Fedora. Original referenced `/etc/pacman.conf` and `pacman -Syyuu`. New version shows `dnf copr enable` and `dnf.conf` exclude examples.

### Files modified
- `config/omarchy/hooks/pre-refresh-pacman.d/add-custom-repo.sample`

---

## dev-pkg-test Rewrite

**Problem:** Script was entirely Arch-based — used `PKGBUILD`, `makepkg`, and `.pkg.tar.*` format.

**Solution:** Rewritten for Fedora RPM workflow.

### Architecture comparison
| | Arch | Fedora |
|---|---|---|
| Build recipe | `PKGBUILD` | `.spec` file |
| Build tool | `makepkg -s --skipchecksums --noconfirm` | `rpmbuild -bb` |
| Output format | `.pkg.tar.*` | `.rpm` |
| Package query | `pacman -Q` | `rpm -q` |
| Lookup dir | `pkgbuilds/<name>/PKGBUILD` | `specs/<name>/<name>.spec` |

### Files modified
- `bin/omarchy-dev-pkg-test` (full rewrite, original backed up as `.arch-bak`)

---

## Documentation Updates

All `.md` files updated to replace Arch-specific terminology with Fedora equivalents.

### AGENTS.md
- `pacman`, `pacman-key` → `dnf`, `rpm`
- `handles both pacman and AUR` → `handles dnf and COPR`
- `raw pacman -R*` → `raw dnf remove`
- Migrations may use `dnf`, `rpm`

### docs/file-layout.md
- `Two Arch packages` → `Two Fedora packages`
- `PKGBUILDs` → `spec files`
- `GPG keys for pacman` → `GPG keys for dnf`
- `Arch's useradd` → `Fedora's useradd`
- `upstream Arch packages` → `upstream Fedora packages`
- `via pacman` → `via dnf`
- `documented in the PKGBUILD` → `documented in the spec file`
- `bypassed pacman -Syu` → `bypassed dnf upgrade`
- `active pacman transaction` → `active dnf transaction`
- `final pacman/udev` → `final dnf/udev`
- All `PKGBUILD` references in quick-reference table → `spec file`

### docs/migrations.md
- `state that pacman cannot safely own` → `state that dnf cannot safely own`
- `active pacman transaction` → `active dnf transaction`
- `OMARCHY_ALLOW_DIRECT_PACMAN=1 pacman -Syu` → `OMARCHY_ALLOW_DIRECT_DNF=1 dnf -y`

### docs/update-process.md
- `sudo pacman -Syu` → `sudo dnf upgrade`
- `after pacman finishes` → `after dnf finishes`
- `pacman guard` → `dnf guard`
- `ALPM pre-transaction hook` → `dnf pre-transaction hook`
- `/usr/share/libalpm/hooks/` → `/etc/dnf/plugins/`
- `pacman --sync --refresh --sysupgrade` → `dnf upgrade --refresh`
- `OMARCHY_UPDATE_PACMAN=1 pacman` → `OMARCHY_UPDATE_DNF=1 dnf`
- `OMARCHY_ALLOW_DIRECT_PACMAN=1 pacman -Syu` → `OMARCHY_ALLOW_DIRECT_DNF=1 dnf upgrade`
- `ALPM hooks for omarchy-settings` → `dnf plugins for omarchy-settings`
- `Arch keyring` → `Fedora keyring`
- `pacman -Sy` → `dnf install`
- `AUR packages with yay -Sua` → `COPR packages`
- `initramfs generation` → `dracut initramfs generation`
- `Pacman guard scope` → `dnf guard scope`
- `Pacnew/pacsave` → `rpmsave/rpmnew`
- `.pacnew` and `.pacsave` → `.rpmsave` and `.rpmnew`

### default/omarchy-skill/SKILL.md
- `opinionated Arch Linux` → `opinionated Fedora Linux`
- `**Arch Linux**` → `**Fedora Linux**`
- `pre-refresh-pacman.d/` → `pre-refresh-repos.d/`
- `omarchy pkg aur add` → `omarchy pkg add` for COPR

---

## Files Modified (complete list)

### Binaries
- `bin/omarchy-setup-tpm2-unlock` — TPM2-only rewrite with dracut config
- `bin/omarchy-dev-pkg-test` — Full rewrite for Fedora
- `bin/omarchy-update-firmware` — EFI path fix
- `bin/omarchy-update-analyze-logs` — dracut patterns
- `bin/omarchy-upgrade-to-quattro` — Message fix
- `bin/omarchy-install-browser` — Package name fixes
- `bin/omarchy-install-service-nordvpn` — Package name fix
- `bin/omarchy-install-editor-emacs` — Comment fix
- `bin/omarchy-install-gaming-retroarch` — Comment fix, removed -git packages
- `bin/omarchy-theme-set-gnome` — Comment fix
- `bin/omarchy-install-service-sunshine` — ufw → firewalld rewrites
- `bin/omarchy-remove-service-sunshine` — ufw → firewalld rewrites
- `bin/omarchy-setup-security-sshd` — ufw → firewalld rewrite
- `bin/omarchy-remove-security-sshd` — ufw → firewalld rewrite

### Installer
- `installer/omarchy-ks.cfg` — TPM2-only, dracut config, initramfs rebuild
- `installer/omarchy-ks-offline.cfg` — Same as above

### Config/Defaults
- `default/omarchy/omarchy-menu.jsonc` — Fedora/COPR labels
- `default/hypr/bindings/utilities.lua` — Maintained in `fedora-patches/utilities.lua`
- `default/systemd/user/omarchy-migrate-notify.service` — Comment fix
- `default/omarchy-skill/SKILL.md` — Arch → Fedora references
- `config/omarchy/hooks/pre-refresh-pacman.d/add-custom-repo.sample` — Rewritten

### Patch infrastructure
- `bin/omarchy-apply-fedora-patches` — Full script (re-applies all patches after updates)
- `fedora-patches/utilities.lua` — Keybindings file restored on post-update

### Documentation
- `AGENTS.md`
- `docs/file-layout.md`
- `docs/migrations.md`
- `docs/update-process.md`

---

## Surviving Upstream Updates

**The core problem:** Omarchy ships as an RPM package (`omarchy-fedora`). When upstream pushes an update, `dnf upgrade` overwrites every file in `/usr/share/omarchy/`. All our Fedora patches are applied directly to those files — they get wiped on every update.

**The solution:** A post-update hook and an `omarchy-apply-fedora-patches` script that re-applies all patches automatically.

### Architecture

```
omarchy update
  → omarchy-update runs the update pipeline
  → omarchy-hook post-update fires
  → ~/.config/omarchy/hooks/post-update.d/apply-fedora-patches.hook runs
  → calls omarchy-apply-fedora-patches (with sudo)
  → re-applies all Fedora-specific sed fixes and file copies
```

### What gets re-applied

Every patch listed in this document is re-applied by `omarchy-apply-fedora-patches`:

- **Keybinding fixes** (`utilities.lua` copied from `fedora-patches/`)
- **Menu labels** (AUR→COPR, Arch Wiki→Fedora Docs)
- **TPM2 unlock script** (copied from `fedora-patches/`)
- **Kickstart files** (copied from `fedora-patches/`)
- **Dracut TPM2 config** (creates `tpm2-tss` dracut module, removes legacy keyfile config)
- **Webapp manifests** (`.desktop` files + icons deployed to all users and `/etc/skel/`)
- **Update scripts** (firmware path, analyze-logs dracut patterns, quattro message)
- **Install scripts** (browser package names, nordvpn, emacs, retroarch, gnome theme, firewall ufw→firewalld, global `uwsm-app`→`uwsm app`)
- **Systemd units** (migrate-notify pacman→dnf)
- **Dev-pkg-test** (copied from `fedora-patches/`)
- **Skill docs** (Arch→Fedora references)
- **Hook samples** (rewritten for dnf/copr)
- **All documentation** (AGENTS.md, file-layout.md, migrations.md, update-process.md)

### Patch source files

Large file rewrites (TPM unlock, kickstart, dev-pkg-test) are stored as complete patched copies in `/usr/share/omarchy/fedora-patches/` (or `~/Projects/Omarchy-Fedora/`). The script copies these over after updates.

Smaller sed-based fixes are applied inline by the script — idempotent and safe to run repeatedly.

### Installing the hook

On first run of `apply.sh`, the migration installs the hook:

```bash
mkdir -p ~/.config/omarchy/hooks/post-update.d
cp /usr/share/omarchy/fedora-patches/apply-fedora-patches.hook \
   ~/.config/omarchy/hooks/post-update.d/
chmod +x ~/.config/omarchy/hooks/post-update.d/apply-fedora-patches.hook
```

### Manual re-application

If the hook doesn't run or you need to force a re-apply:

```bash
sudo omarchy-apply-fedora-patches
```

Or from the project directory:

```bash
sudo bash ~/Projects/Omarchy-Fedora/apply.sh
```

### Updating the patches themselves

When new upstream Omarchy adds scripts or changes structure:

1. Review the upstream diff for new/changed files in `/usr/share/omarchy/bin/`
2. Add new sed rules to `omarchy-apply-fedora-patches` for any new Arch references
3. Copy any new files that need full rewrites into `fedora-patches/`
4. Update this document with the new changes

---

## How to Apply

### Fresh install (first time)

```bash
sudo bash ~/Projects/Omarchy-Fedora/apply.sh
```

This applies all patches AND installs the post-update hook so future upstream updates are handled automatically.

### After an upstream update (if hook didn't run)

```bash
sudo omarchy-apply-fedora-patches
```

### Individual patch files

```bash
# Patch files stored in fedora-patches/
sudo cp ~/Projects/Omarchy-Fedora/fedora-patches/omarchy-setup-tpm2-unlock /usr/share/omarchy/bin/
sudo cp ~/Projects/Omarchy-Fedora/fedora-patches/omarchy-ks.cfg /usr/share/omarchy/installer/
sudo cp ~/Projects/Omarchy-Fedora/fedora-patches/omarchy-ks-offline.cfg /usr/share/omarchy/installer/
sudo cp ~/Projects/Omarchy-Fedora/fedora-patches/omarchy-dev-pkg-test /usr/share/omarchy/bin/
sudo chmod +x /usr/share/omarchy/bin/omarchy-dev-pkg-test
sudo cp ~/Projects/Omarchy-Fedora/fedora-patches/utilities.lua /usr/share/omarchy/default/hypr/bindings/utilities.lua

# The apply script itself
sudo cp ~/Projects/Omarchy-Fedora/scripts/omarchy-apply-fedora-patches /usr/share/omarchy/bin/
sudo chmod +x /usr/share/omarchy/bin/omarchy-apply-fedora-patches

# The post-update hook
sudo cp ~/Projects/Omarchy-Fedora/fedora-patches/apply-fedora-patches.hook \
   ~/.config/omarchy/hooks/post-update.d/
sudo chmod +x ~/.config/omarchy/hooks/post-update.d/apply-fedora-patches.hook
```
