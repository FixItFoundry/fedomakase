#!/bin/bash
# Fedora Port: Fix Arch-specific references in documentation
# Run with: sudo bash /tmp/omarchy-fedora-port/apply-docs.sh

set -e
OMARCHY=/usr/share/omarchy

echo "=== Fixing Omarchy Documentation for Fedora ==="

# --- AGENTS.md ---
echo "[1/5] Fixing AGENTS.md..."
sed -i 's|Raw `command -v`, `pacman`, and `pacman-key` are acceptable in package-helper contexts|Raw `command -v`, `dnf`, and `rpm` are acceptable in package-helper contexts|' "$OMARCHY/AGENTS.md"
sed -i 's|install packages (handles both pacman and AUR)|install packages (handles dnf and COPR)|' "$OMARCHY/AGENTS.md"
sed -i 's|use this instead of raw `pacman -R\*`|use this instead of raw `dnf remove`|' "$OMARCHY/AGENTS.md"
sed -i 's|Migrations may use raw `pacman`, `command -v`|Migrations may use raw `dnf`, `rpm`, `command -v`|' "$OMARCHY/AGENTS.md"

# --- file-layout.md ---
echo "[2/5] Fixing docs/file-layout.md..."
sed -i 's|Two Arch packages are built from this one repo (PKGBUILDs live in|Two Fedora packages are built from this one repo (spec files live in|' "$OMARCHY/docs/file-layout.md"
sed -i 's|`omarchy-keyring` (GPG keys for pacman)|`omarchy-keyring` (GPG keys for dnf)|' "$OMARCHY/docs/file-layout.md"
sed -i 's|Arch'\''s `useradd -m` copies|Fedora'\''s `useradd -m` copies|' "$OMARCHY/docs/file-layout.md"
sed -i 's|are owned by upstream Arch packages, so we can'\''t install over|are owned by upstream Fedora packages, so we can'\''t install over|' "$OMARCHY/docs/file-layout.md"
sed -i 's|them via pacman without a file conflict|them via dnf without a file conflict|' "$OMARCHY/docs/file-layout.md"
sed -i 's|This is documented in the PKGBUILD.|This is documented in the spec file.|' "$OMARCHY/docs/file-layout.md"
sed -i 's|watcher cannot tell a bypassed `pacman -Syu` from|watcher cannot tell a bypassed `dnf upgrade` from|' "$OMARCHY/docs/file-layout.md"
sed -i 's|waits for any active pacman transaction|waits for any active dnf transaction|' "$OMARCHY/docs/file-layout.md"
sed -i 's|final pacman/udev/localdb passes|final dnf/udev/localdb passes|' "$OMARCHY/docs/file-layout.md"
# PKGBUILD references in the quick reference table
sed -i 's|in `omarchy-settings` PKGBUILD + scriptlet|in `omarchy-settings` spec file + scriptlet|' "$OMARCHY/docs/file-layout.md"
sed -i 's|in `omarchy-settings` PKGBUILD$|in `omarchy-settings` spec file|' "$OMARCHY/docs/file-layout.md"
sed -i 's|in `omarchy-settings` PKGBUILD |in `omarchy-settings` spec file |g' "$OMARCHY/docs/file-layout.md"

# --- migrations.md ---
echo "[3/5] Fixing docs/migrations.md..."
sed -i 's|state that pacman cannot safely own by|state that dnf cannot safely own by|' "$OMARCHY/docs/migrations.md"
sed -i 's|waits for any active pacman transaction|waits for any active dnf transaction|' "$OMARCHY/docs/migrations.md"
sed -i 's|bypassed the pacman guard with `sudo env OMARCHY_ALLOW_DIRECT_PACMAN=1 pacman|bypassed the dnf guard with `sudo env OMARCHY_ALLOW_DIRECT_DNF=1 dnf|' "$OMARCHY/docs/migrations.md"
sed -i 's|-Syu`,|-y`,|' "$OMARCHY/docs/migrations.md"

# --- update-process.md ---
echo "[4/5] Fixing docs/update-process.md..."
sed -i 's|sudo pacman -Syu|sudo dnf upgrade|g' "$OMARCHY/docs/update-process.md"
sed -i 's|Migrations run per-user after pacman finishes|Migrations run per-user after dnf finishes|' "$OMARCHY/docs/update-process.md"
sed -i 's|nudged back by the pacman guard|nudged back by the dnf guard|' "$OMARCHY/docs/update-process.md"
sed -i 's|## Raw pacman guard|## Raw dnf guard|' "$OMARCHY/docs/update-process.md"
sed -i 's|The `omarchy` package installs an ALPM pre-transaction hook|The `omarchy` package installs a dnf pre-transaction hook|' "$OMARCHY/docs/update-process.md"
sed -i 's|/usr/share/libalpm/hooks/00-omarchy-update-guard.hook|/etc/dnf/plugins/omarchy-update-guard.conf|' "$OMARCHY/docs/update-process.md"
sed -i 's|The guard detects direct pacman system-upgrade commands|The guard detects direct dnf system-upgrade commands|' "$OMARCHY/docs/update-process.md"
sed -i 's|pacman --sync --refresh --sysupgrade|dnf upgrade --refresh|' "$OMARCHY/docs/update-process.md"
sed -i 's|and the v4 upgrader run pacman through|and the v4 upgrader run dnf through|' "$OMARCHY/docs/update-process.md"
sed -i 's|env OMARCHY_UPDATE_PACMAN=1 pacman|env OMARCHY_UPDATE_DNF=1 dnf|g' "$OMARCHY/docs/update-process.md"
sed -i 's|sudo env OMARCHY_ALLOW_DIRECT_PACMAN=1 pacman|sudo env OMARCHY_ALLOW_DIRECT_DNF=1 dnf|g' "$OMARCHY/docs/update-process.md"
sed -i 's|The guard does not start `omarchy update` itself because pacman|The guard does not start `omarchy update` itself because dnf|' "$OMARCHY/docs/update-process.md"
sed -i 's|ALPM hooks for `omarchy-settings`|dnf plugins for `omarchy-settings`|' "$OMARCHY/docs/update-process.md"
sed -i 's|`omarchy-migrate` after pacman finishes|`omarchy-migrate` after dnf finishes|' "$OMARCHY/docs/update-process.md"
sed -i 's|## Path 2: direct `sudo pacman -Syu` attempt|## Path 2: direct `sudo dnf upgrade` attempt|' "$OMARCHY/docs/update-process.md"
sed -i 's|cannot distinguish a bypassed `pacman -Syu` from|cannot distinguish a bypassed `dnf upgrade` from|' "$OMARCHY/docs/update-process.md"
sed -i 's|Direct pacman updates do not run|Direct dnf updates do not run|' "$OMARCHY/docs/update-process.md"
sed -i 's|Ensures Omarchy keyring and Arch keyring|Ensures Omarchy keyring and Fedora keyring|' "$OMARCHY/docs/update-process.md"
sed -i 's|targeted `pacman -Sy` for keyring|targeted `dnf install` for keyring|' "$OMARCHY/docs/update-process.md"
sed -i 's|Runs `sudo env OMARCHY_UPDATE_PACMAN=1 pacman|Runs `sudo env OMARCHY_UPDATE_DNF=1 dnf|' "$OMARCHY/docs/update-process.md"
sed -i 's|so the ALPM guard allows|so the dnf guard allows|' "$OMARCHY/docs/update-process.md"
sed -i 's|Waits for pacman, then runs|Waits for dnf, then runs|' "$OMARCHY/docs/update-process.md"
sed -i 's|ALPM pre-transaction guard that aborts direct `pacman -Syu`|dnf pre-transaction guard that aborts direct `dnf upgrade`|' "$OMARCHY/docs/update-process.md"
sed -i 's|unless Omarchy set `OMARCHY_UPDATE_PACMAN=1`|unless Omarchy set `OMARCHY_UPDATE_DNF=1`|' "$OMARCHY/docs/update-process.md"
sed -i 's|or the user explicitly set `OMARCHY_ALLOW_DIRECT_PACMAN=1`|or the user explicitly set `OMARCHY_ALLOW_DIRECT_DNF=1`|' "$OMARCHY/docs/update-process.md"
sed -i 's|Updates AUR packages with `yay -Sua`|Updates COPR packages|' "$OMARCHY/docs/update-process.md"
sed -i 's|if foreign packages exist and AUR is reachable|if COPR packages are installed|' "$OMARCHY/docs/update-process.md"
sed -i 's|users may still install AUR packages|users may still install COPR packages|' "$OMARCHY/docs/update-process.md"
sed -i 's|currently initramfs generation|currently dracut initramfs generation|' "$OMARCHY/docs/update-process.md"
sed -i 's|`omarchy update` runs `omarchy-migrate` after pacman finishes|`omarchy update` runs `omarchy-migrate` after dnf finishes|' "$OMARCHY/docs/update-process.md"
sed -i 's|Package-time migration runners do not apply migrations inside pacman|Package-time migration runners do not apply migrations inside dnf|' "$OMARCHY/docs/update-process.md"
sed -i 's|Direct `sudo pacman -Syu` no longer uses|Direct `sudo dnf upgrade` no longer uses|' "$OMARCHY/docs/update-process.md"
sed -i 's|Pacman guard scope|dnf guard scope|' "$OMARCHY/docs/update-process.md"
sed -i 's|The guard detects direct pacman sysupgrade|The guard detects direct dnf upgrade|' "$OMARCHY/docs/update-process.md"
sed -i 's|commands that set `OMARCHY_UPDATE_PACMAN=1`|commands that set `OMARCHY_UPDATE_DNF=1`|' "$OMARCHY/docs/update-process.md"
sed -i 's|Pacnew/pacsave handling is still missing|rpmsave handling is still missing|' "$OMARCHY/docs/update-process.md"
sed -i 's|`.pacnew` and `.pacsave` files|`.rpmsave` and `.rpmnew` files|' "$OMARCHY/docs/update-process.md"
# Catch remaining pacman refs in table rows
sed -i 's|`omarchy-refresh-pacman`|`omarchy-refresh-repos`|g' "$OMARCHY/docs/update-process.md"
sed -i 's|targeted `pacman -Sy` for keyring bootstrapping|targeted `dnf install` for keyring bootstrapping|' "$OMARCHY/docs/update-process.md"
sed -i 's|targeted transition `--overwrite` entries so the ALPM guard allows|targeted transition entries so the dnf guard allows|' "$OMARCHY/docs/update-process.md"

# --- SKILL.md ---
echo "[5/5] Fixing default/omarchy-skill/SKILL.md..."
sed -i 's|pre-refresh-pacman.d/|pre-refresh-repos.d/|' "$OMARCHY/default/omarchy-skill/SKILL.md"
sed -i 's|omarchy pkg aur add <pkgs\.\.\.>.*for AUR-only packages|omarchy pkg add <pkgs...> for COPR packages|' "$OMARCHY/default/omarchy-skill/SKILL.md"

echo ""
echo "=== Done! ==="
echo "Updated: AGENTS.md, file-layout.md, migrations.md, update-process.md, SKILL.md"
