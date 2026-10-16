echo "Ensure mise is installed"

if omarchy-pkg-missing mise-bin; then
  omarchy-pkg-add mise-bin
fi
