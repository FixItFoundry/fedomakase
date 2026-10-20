#!/usr/bin/env python3
"""Read the tablet-mode switch a convertible 2-in-1 exposes.

ChromeOS-class embedded controllers report a "tablet mode" switch (the Linux
SW_TABLET_MODE input switch) on their button/switch device. The kernel maps
the controller's switch bit onto it, so reading that switch tells a session
whether the screen has been folded over the keyboard.

A manual override wins over the hardware, for 2-in-1s whose controller never
reports the fold because it has no hinge sensor.

Usage:
  tablet-mode.py supported   exit 0 when the hardware exposes the switch
  tablet-mode.py state       print "tablet" or "laptop"; exit 0 in tablet mode
  tablet-mode.py watch       print "tablet" or "laptop" whenever it changes
"""

import ctypes
import os
import sys
import time

IOC_READ = 2

# _IOR('E', 0x1b, unsigned long[16]) -- the switch bitmap.
EVIOCGSW = (IOC_READ << 30) | (128 << 16) | (ord("E") << 8) | 0x1B

SW_TABLET_MODE = 1

INPUT_CLASS = os.environ.get("OMARCHY_INPUT_CLASS_PATH", "/sys/class/input")
OVERRIDE_FILE = os.path.expanduser("~/.local/state/omarchy/2in1/mode")
POLL_SECONDS = 0.2

libc = ctypes.CDLL("libc.so.6", use_errno=True)


def switch_capabilities(event_dir):
    """Return the switch bitmap a device supports, or None."""
    path = os.path.join(event_dir, "device", "capabilities", "sw")
    try:
        with open(path) as handle:
            words = handle.read().split()
    except OSError:
        return None
    if not words:
        return None
    try:
        # The last word holds the lowest bits.
        return int(words[-1], 16)
    except ValueError:
        return None


def device_path(event_dir):
    return os.path.join("/dev/input", os.path.basename(event_dir))


def find_tablet_device():
    """Return the event directory of a device exposing SW_TABLET_MODE."""
    try:
        entries = sorted(os.listdir(INPUT_CLASS))
    except OSError:
        return None

    for name in entries:
        if not name.startswith("event"):
            continue
        event_dir = os.path.join(INPUT_CLASS, name)
        capabilities = switch_capabilities(event_dir)
        if capabilities is None:
            continue
        if capabilities & (1 << SW_TABLET_MODE):
            return event_dir
    return None


def read_switches(path):
    """Return the device's switch bitmap, or None when it cannot be read."""
    try:
        fd = os.open(path, os.O_RDONLY)
    except OSError:
        return None
    try:
        buffer = (ctypes.c_ulong * 16)()
        result = libc.ioctl(
            ctypes.c_int(fd),
            ctypes.c_ulong(EVIOCGSW),
            ctypes.byref(buffer),
        )
        if result < 0:
            return None
        return buffer[0]
    finally:
        os.close(fd)


def hardware_mode():
    """Return True in tablet mode, False in laptop mode, None when unknown."""
    event_dir = find_tablet_device()
    if event_dir is None:
        return None
    switches = read_switches(device_path(event_dir))
    if switches is None:
        return None
    return bool(switches & (1 << SW_TABLET_MODE))


def override_mode():
    """Return the manual override, or None when there is none."""
    try:
        with open(OVERRIDE_FILE) as handle:
            mode = handle.read().strip()
    except OSError:
        return None
    if mode == "tablet":
        return True
    if mode == "laptop":
        return False
    return None


def current_mode():
    """Return the mode in force: the manual override, else the hardware."""
    override = override_mode()
    if override is not None:
        return override
    return hardware_mode()


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else "state"

    if command == "supported":
        sys.exit(0 if find_tablet_device() else 1)

    if command == "state":
        mode = current_mode()
        if mode is None:
            print("laptop")
            sys.exit(1)
        print("tablet" if mode else "laptop")
        sys.exit(0 if mode else 1)

    if command == "watch":
        last = None
        while True:
            mode = current_mode()
            if mode is not None and mode != last:
                print("tablet" if mode else "laptop", flush=True)
                last = mode
            time.sleep(POLL_SECONDS)

    sys.stderr.write(f"Usage: {sys.argv[0]} supported|state|watch\n")
    sys.exit(2)


if __name__ == "__main__":
    main()
