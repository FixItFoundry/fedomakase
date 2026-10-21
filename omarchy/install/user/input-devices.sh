# Put the user in the input group, so the session can read the input devices.
#
# Hyprland opens the keyboard, the touchpad and the touchscreen itself, but it
# does that at log-in. Anything that needs to read a device afterwards -- a
# 2-in-1 watcher following the tablet-mode switch, for one -- is locked out
# unless the user is a member of the group that owns them.
if ! id -nG | tr ' ' '\n' | grep -qx input; then
  sudo usermod -aG input "$USER"
  echo "Added $USER to the input group. Log out and back in for it to take effect."
fi
