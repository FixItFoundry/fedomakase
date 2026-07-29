# Flatpak Chrome Downloads Were Invisible

**Date:** 2026-07-28
**Component:** `omarchy-install-browser`, package lists

## The Problem

After switching Chrome from RPM to Flatpak (`com.google.Chrome`), downloaded files
were invisible — they saved somewhere but never appeared in `~/Downloads`.

The user could see the download complete in Chrome's UI, but `ls ~/Downloads`
showed nothing. The file seemed to vanish.

## Root Cause

`xdg-user-dirs` was not installed. This meant:

1. `XDG_DOWNLOAD_DIR` was never set (no `~/.config/user-dirs.dirs` was generated)
2. Flatpak's `xdg-download` filesystem bind mount had no target to bind to
3. Chrome (running inside the Flatpak sandbox) wrote to its internal `/run/user/1000/doc/`
   temp mount, not to the real filesystem
4. When Chrome declared the download "complete", the file was released from the
   sandbox portal — but since no real `~/Downloads` existed, it went nowhere visible

## Why It Wasn't Caught Sooner

- RPM Chrome writes directly to the filesystem and doesn't need the xdg portal bridge
- The Flatpak sandbox masks the problem: Chrome *thinks* it's saving correctly
- On systems where `xdg-user-dirs` happens to be pulled in by GNOME or another DE,
  the problem doesn't manifest

## The Fix

Added the entire xdg-* family to all three package manifests (`install/post-install/`,
both kickstart `%packages` sections):

```
xdg-user-dirs
xdg-user-dirs-gtk
xdg-utils
xdg-dbus-proxy
xdg-desktop-portal
xdg-desktop-portal-gnome
xdg-desktop-portal-wlr
xdg-native-messaging-proxy
```

These were already correct for the Arch original but had been overlooked in the
Fedora port because the kickstart `%packages` was being hand-maintained as a
separate list rather than derived from the reference manifest.

## Lesson

The manifest (`omarchy-fedora-base.packages`) must be the single source of truth.
Any divergence between kickstart `%packages` and the manifest will cause
missing-package bugs that are hard to diagnose because they manifest as
application misbehavior, not as install failures.
