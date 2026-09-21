#!/bin/bash
# Hook check-mode tests: --check passes on the fixed tree and names
# exactly the files missing their fix on an upstream (unpatched) tree.
# Run from anywhere: bash test/hook-checks.sh

set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OMARCHY="$REPO_DIR/omarchy"
RUNNER="$REPO_DIR/scripts/omarchy-apply-fedora-patches"
FAILS=0

pass() { echo "  ok  - $1"; }
fail() { echo "  FAIL- $1"; (( FAILS++ )); }

echo "=== fedomakase hook checks ==="

# 1. The repo payload is the fixed source of truth — --check must pass on it.
if OMARCHY_PATH="$OMARCHY" bash "$RUNNER" --check &>/dev/null; then
  pass "payload tree passes --check"
else
  fail "payload tree passes --check"
  OMARCHY_PATH="$OMARCHY" bash "$RUNNER" --check || true
fi

# 2. Simulate an upstream update: fixture with Arch-ism content.
FIXTURE=$(mktemp -d)
trap 'rm -rf "$FIXTURE"' EXIT
mkdir -p "$FIXTURE/bin" "$FIXTURE/default/omarchy" "$FIXTURE/etc/sddm.conf.d" \
  "$FIXTURE/install" "$FIXTURE/config/omarchy/hooks/pre-refresh-repos.d"
cp "$OMARCHY/bin/omarchy-pkg-aur-accessible" \
   "$OMARCHY/bin/omarchy-voxtype-install" \
   "$OMARCHY/bin/omarchy-voxtype-remove" \
   "$OMARCHY/bin/omarchy-channel-set" \
   "$OMARCHY/bin/omarchy-reinstall-pkgs" \
   "$OMARCHY/bin/omarchy-refresh-repos" \
   "$OMARCHY/bin/omarchy-update-aur-pkgs" \
   "$OMARCHY/bin/omarchy-pkg-install" "$FIXTURE/bin/"
cp "$OMARCHY/default/omarchy/omarchy-menu.jsonc" "$FIXTURE/default/omarchy/"
cp "$OMARCHY/etc/sddm.conf.d/10-wayland.conf" "$FIXTURE/etc/sddm.conf.d/"
cp "$OMARCHY/install/omarchy-fedora-copr.repos" \
   "$OMARCHY/install/omarchy-fedora-base.packages" "$FIXTURE/install/"
cp "$OMARCHY/config/omarchy/hooks/pre-refresh-repos.d/add-custom-repo.sample" \
   "$FIXTURE/config/omarchy/hooks/pre-refresh-repos.d/"

# Revert three files to upstream (unfixed) content, as an update would.
sed -i 's|nett00n/hyprland|solopasha/hyprland|' "$FIXTURE/bin/omarchy-pkg-aur-accessible"
sed -i 's|omarchy-refresh-repos|omarchy-refresh-pacman|' "$FIXTURE/bin/omarchy-channel-set"
sed -i 's|"label":"COPR"|"label":"AUR"|g' "$FIXTURE/default/omarchy/omarchy-menu.jsonc"

out=$(OMARCHY_PATH="$FIXTURE" bash "$RUNNER" --check 2>&1)
status=$?
(( status != 0 )) && pass "--check fails on upstream tree" || fail "--check fails on upstream tree"
for desc in "COPR health-check URL" "refresh-repos caller (channel-set)" "menu COPR label"; do
  grep -q "MISSING - $desc" <<<"$out" && pass "--check names: $desc" || fail "--check names: $desc"
done
grep -q "=== 3 missing fix(es) ===" <<<"$out" && pass "--check counts 3 missing" || fail "--check counts 3 missing"

# 3. Fresh fixture (all fixed) must pass.
FIXTURE2=$(mktemp -d)
trap 'rm -rf "$FIXTURE" "$FIXTURE2"' EXIT
cp -r "$OMARCHY/bin" "$OMARCHY/default" "$OMARCHY/etc" "$OMARCHY/install" "$OMARCHY/config" "$FIXTURE2/"
if OMARCHY_PATH="$FIXTURE2" bash "$RUNNER" --check &>/dev/null; then
  pass "fixed fixture passes --check"
else
  fail "fixed fixture passes --check"
fi

echo "=== $FAILS failure(s) ==="
exit $(( FAILS > 0 ))
