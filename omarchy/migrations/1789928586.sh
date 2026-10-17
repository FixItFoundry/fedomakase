echo "Retain the installed ARM Limine recovery packages during orphan cleanup"

[[ $(uname -m) == "aarch64" && -f ${OMARCHY_LIMINE_CONF:-/etc/default/limine} ]] || exit 0

# ARM also supports boot stacks such as Asahi's, so the runtime package cannot
# depend on Limine unconditionally. The ISO installs its chosen stack explicitly;
# older ARM installations can still have these packages marked as dependencies.
# Preserve only installed packages, without installing a different boot stack.
recovery_packages=()
for pkg in limine limine-mkinitcpio-hook limine-snapper-sync snapper; do
  rpm -q -- "$pkg" &>/dev/null && recovery_packages+=("$pkg")
done

if (( ${#recovery_packages[@]} )); then
  sudo dnf mark install "${recovery_packages[@]}" 2>/dev/null || true
fi
