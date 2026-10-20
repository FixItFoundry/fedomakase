# Set links for Nautilus action icons
mkdir -p /usr/share/icons/Yaru/scalable/actions
ln -snf /usr/share/icons/Adwaita/symbolic/actions/go-previous-symbolic.svg \
          /usr/share/icons/Yaru/scalable/actions/go-previous-symbolic.svg
ln -snf /usr/share/icons/Adwaita/symbolic/actions/go-next-symbolic.svg \
          /usr/share/icons/Yaru/scalable/actions/go-next-symbolic.svg
gtk-update-icon-cache /usr/share/icons/Yaru &>/dev/null || true

# Seed Chromium's first run: follow system appearance ("device") instead of dark,
# and skip the terms-of-service dialog Chromium 151 turned on by default.
mkdir -p /usr/lib/chromium /etc/chromium
echo '{"distribution":{"require_eula":false},"browser":{"theme":{"color_scheme":0,"color_scheme2":0}}}' > \
  /usr/lib/chromium/initial_preferences
cp -f /usr/lib/chromium/initial_preferences /etc/chromium/master_preferences 2>/dev/null || true

# Fedora's chromium package ships chromium-browser.desktop; alias chromium.desktop for Omarchy scripts
if [[ -f /usr/share/applications/chromium-browser.desktop && ! -e /usr/share/applications/chromium.desktop ]]; then
  ln -sf /usr/share/applications/chromium-browser.desktop /usr/share/applications/chromium.desktop
fi
if [[ -x /usr/bin/chromium-browser && ! -e /usr/bin/chromium ]]; then
  ln -sf /usr/bin/chromium-browser /usr/bin/chromium
fi
