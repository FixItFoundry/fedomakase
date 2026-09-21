#!/bin/bash
# Static sanity checks for the Fedomakase port.
# Run from anywhere: bash test/build-checks.sh

set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OMARCHY="$REPO_DIR/omarchy"
FAILS=0

pass() { echo "  ok  - $1"; }
fail() { echo "  FAIL- $1"; (( FAILS++ )); }
check() { # check <description> <command...>
  local desc="$1"; shift
  if "$@" &>/dev/null; then pass "$desc"; else fail "$desc"; fi
}

echo "=== fedomakase build checks ==="

# --- Canonical layout ---
check "netinstall kickstart exists"            test -s "$OMARCHY/installer/omarchy-ks.cfg"
check "offline kickstart exists"               test -s "$OMARCHY/installer/omarchy-ks-offline.cfg"
check "gum installer exists"                   test -s "$OMARCHY/installer/omarchy-installer.sh"
check "no stale kickstart copies at repo root" bash -c "! ls '$REPO_DIR'/installer/omarchy-ks* '$REPO_DIR'/scripts/omarchy-ks* 2>/dev/null"
check "no .bak files committed"                bash -c "! find '$REPO_DIR' -name '*.bak' | grep -q ."

# --- Kickstart integrity: choices-driven install, no hardcoded creds ---
for ks in "$OMARCHY/installer/omarchy-ks.cfg" "$OMARCHY/installer/omarchy-ks-offline.cfg"; do
  name=$(basename "$ks")
  check "$name: consumes Gum include file"   grep -q '^%include /tmp/fedomakase-part.cfg' "$ks"
  check "$name: has package splice markers"  bash -c "grep -q 'FEDOMAKASE-PACKAGES-BEGIN' '$ks' && grep -q 'FEDOMAKASE-PACKAGES-END' '$ks'"
  check "$name: no hardcoded default password" bash -c "! grep -Eq -- '--password=.?omarchy' '$ks'"
  check "$name: references payload installer"  grep -q 'omarchy-fedora/installer/omarchy-installer.sh' "$ks"
done
check "kickstarts+builds use nett00n COPR"  bash -c "grep -rq 'nett00n' '$OMARCHY/installer/' '$REPO_DIR/build/'"
check "no lionheartp/solopasha references remain" bash -c "! grep -rn 'lionheartp\|solopasha' '$OMARCHY/installer/' '$REPO_DIR/build/' '$OMARCHY/install/' '$OMARCHY/bin/omarchy-pkg-aur-accessible'"
check "no jcasco machine paths anywhere"     bash -c "! grep -rn 'jcasco' '$REPO_DIR/build' '$REPO_DIR/scripts' '$OMARCHY/installer'"

# --- Installer <-> kickstart contract ---
check "installer writes part cfg consumed by ks" \
  bash -c "grep -q 'fedomakase-part.cfg' '$OMARCHY/installer/omarchy-installer.sh'"
check "installer hashes user password" \
  bash -c "grep -q 'openssl passwd -6' '$OMARCHY/installer/omarchy-installer.sh'"
check "installer rejects double quotes in LUKS passphrase" \
  bash -c "grep -q 'cannot contain double-quote' '$OMARCHY/installer/omarchy-installer.sh'"

# --- SDDM must go through uwsm (regression guard) ---
check "sddm wayland conf launches via uwsm" \
  grep -q "CompositorCommand=uwsm start" "$OMARCHY/etc/sddm.conf.d/10-wayland.conf"

# --- Manifest: single source of truth health ---
MANIFEST="$OMARCHY/install/omarchy-fedora-base.packages"
check "manifest exists and is non-trivial" \
  bash -c "(( \$(grep -vcE '^#|^\$' '$MANIFEST') > 100 ))"
check "manifest: quickshell present"            grep -q '^quickshell$' "$MANIFEST"
check "manifest: no waybar (QuickShell is the shell)" bash -c "! grep -q '^waybar$' '$MANIFEST'"
check "manifest: perl-JSON-PP present (menu keybinds)"  grep -q '^perl-JSON-PP$' "$MANIFEST"
check "manifest: libxkbcommon-utils present (keybinds)" grep -q '^libxkbcommon-utils$' "$MANIFEST"
check "copr repos file points at nett00n"    grep -q '^nett00n/hyprland$' "$OMARCHY/install/omarchy-fedora-copr.repos"
check "copr repos file points at whelanh"    grep -q '^whelanh/omarchy$' "$OMARCHY/install/omarchy-fedora-copr.repos"
check "copr repos file points at ghostty"    grep -q '^scottames/ghostty$' "$OMARCHY/install/omarchy-fedora-copr.repos"
check "manifest: whelanh set present" bash -c "grep -q '^omacut$' '$MANIFEST' && grep -q '^omawrite$' '$MANIFEST' && grep -q '^tensaku$' '$MANIFEST' && grep -q '^hyprland-preview-share-picker$' '$MANIFEST' && grep -q '^aether$' '$MANIFEST'"

# --- Build scripts fail loud ---
for b in "$REPO_DIR/build/build-netinstall-iso.sh" "$REPO_DIR/build/build-offline-iso.sh"; do
  name=$(basename "$b")
  check "$name: set -euo pipefail"        grep -q 'set -euo pipefail' "$b"
  check "$name: gum download not swallowed" bash -c "! grep -E 'wget .*gum.*\|\| true' '$b'"
done

# --- No giant binaries in the repo ---
check "gum ELF not present on disk" \
  bash -c "! find '$REPO_DIR' -type f -path '*installer/gum' | grep -q ."
check "gum ELF not tracked (or pending deletion) in git" \
  bash -c "cd '$REPO_DIR' && for f in \$(git ls-files | grep 'installer/gum\$'); do git status --porcelain -- \"\$f\" | grep -q 'D' || exit 1; done; exit 0"

# --- Syntax check every shell script in the port layer ---
SYNTAX_FAIL=0
while IFS= read -r script; do
  bash -n "$script" 2>/dev/null || { echo "  FAIL- bash -n $script"; (( FAILS++ )); SYNTAX_FAIL=1; }
done < <(find "$REPO_DIR/build" "$REPO_DIR/scripts" "$OMARCHY/installer" -maxdepth 2 -type f \( -name "*.sh" -o -perm -111 \) ! -name "*.rpm" ! -name "gum")
(( SYNTAX_FAIL == 0 )) && pass "all port scripts pass bash -n"

if command -v shellcheck &>/dev/null; then
  SC_FAIL=0
  for script in "$REPO_DIR"/build/*.sh "$OMARCHY/installer/omarchy-installer.sh" "$REPO_DIR/scripts/apply.sh"; do
    shellcheck -S warning "$script" 2>/dev/null || { echo "  FAIL- shellcheck $script"; (( FAILS++ )); SC_FAIL=1; }
  done
  (( SC_FAIL == 0 )) && pass "shellcheck clean on port scripts"
else
  echo "  note- shellcheck not installed; skipping (dnf install ShellCheck)"
fi

# --- ghostty must resolve through its COPR (not in official Fedora) ---
check "netinstall ks includes ghostty COPR repo" \
  grep -q "scottames/ghostty" "$OMARCHY/installer/omarchy-ks.cfg"
check "netinstall ks includes nett00n COPR repo" \
  grep -q "nett00n/hyprland" "$OMARCHY/installer/omarchy-ks.cfg"
check "netinstall ks includes whelanh COPR repo" \
  grep -q "whelanh/omarchy" "$OMARCHY/installer/omarchy-ks.cfg"
check "build scripts query ghostty COPR during resolution" \
  bash -c "! grep -L scottames '$REPO_DIR/build/build-netinstall-iso.sh' '$REPO_DIR/build/build-offline-iso.sh' | grep -q ."
check "build scripts query whelanh COPR during resolution" \
  bash -c "! grep -L whelanh '$REPO_DIR/build/build-netinstall-iso.sh' '$REPO_DIR/build/build-offline-iso.sh' | grep -q ."

# --- self-heal chain must survive upstream overwrites ---
check "hook restores runner from user-land stash" \
  grep -q '.local/share/fedomakase' "$REPO_DIR/scripts/apply-fedora-patches.hook"
check "apply.sh populates the stash" \
  grep -q 'local/share/fedomakase' "$REPO_DIR/scripts/apply.sh"

echo "=== $FAILS failure(s) ==="
exit $(( FAILS > 0 ))
