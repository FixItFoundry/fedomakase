# Install all packages from the Omarchy Fedora base manifest.
# This is the single source of truth for what goes into an Omarchy system.
# Run after COPR repos are enabled so COPR packages resolve.

manifest="$OMARCHY_INSTALL/omarchy-fedora-base.packages"

if [[ ! -f $manifest ]]; then
  echo "WARNING: Package manifest not found at $manifest" >&2
  return
fi

packages=()
while IFS= read -r line; do
  line="${line%%#*}"
  line="${line//[[:space:]]/}"
  [[ -z $line ]] && continue
  packages+=("$line")
done < "$manifest"

if ((${#packages[@]} == 0)); then
  echo "WARNING: No packages found in $manifest" >&2
  return
fi

echo "Installing ${#packages[@]} packages from $manifest..."
dnf install -y "${packages[@]}" 2>/dev/null || {
  echo "WARNING: Some packages from $manifest failed to install" >&2
}
