echo "Repair fingerprint support left without a libfprint"

if omarchy-pkg-present fprintd && omarchy-pkg-missing libfprint && omarchy-pkg-missing libfprint-git; then
  omarchy-pkg-add libfprint
fi
