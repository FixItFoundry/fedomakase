# Install Panther Lake kernel for Dell XPS Panther Lake systems
# On Fedora, the mainline kernel typically includes newer Intel patches earlier.

if omarchy-hw-match "XPS" && omarchy-hw-intel-ptl; then
  echo "Detected Dell XPS Panther Lake."
  echo "Fedora's kernel typically includes Panther Lake support in mainline."
  echo "If audio drivers are missing, check for COPR kernel-ptl packages."

  # Ensure kernel-devel is installed for any DKMS modules
  omarchy-pkg-add kernel-devel
fi
