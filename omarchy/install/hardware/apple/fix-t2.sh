# Detect T2 MacBook models using PCI IDs
# Vendor: 106b (Apple), Device IDs: 1801 or 1802 (T2 Security Chip)
if lspci -nn | grep -q "106b:180[12]"; then
  echo "Detected MacBook with T2 chip. Installing support items..."

  omarchy-pkg-add \
    linux-t2 \
    linux-t2-headers \
    apple-t2-audio-config \
    apple-bcm-firmware \
    t2fanrd \
    tiny-dfr

  # Add user to video group (required for tiny-dfr to access /dev/dri devices)
  usermod -aG video "$OMARCHY_INSTALL_USER"

  # Enable T2 services
  systemctl enable t2fanrd.service
  systemctl enable tiny-dfr.service

  mkdir -p /etc/modules-load.d
  {
    echo "apple-bce"
    echo "hci_bcm4377"
  } > /etc/modules-load.d/t2.conf

  mkdir -p /etc/dracut.conf.d
  echo "add_drivers+=\" apple-bce usbhid hid_apple hid_generic xhci_pci xhci_hcd \"" > \
    /etc/dracut.conf.d/apple-t2.conf

  mkdir -p /etc/modprobe.d
  cat > /etc/modprobe.d/brcmfmac.conf <<'EOF'
# Fix for T2 MacBook WiFi connectivity issues
options brcmfmac feature_disable=0x82000
EOF

  if ! grep -q 'intel_iommu=on' /etc/default/grub; then
    if grep -q "^GRUB_CMDLINE_LINUX=" /etc/default/grub; then
      sudo sed -i 's/^GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 intel_iommu=on iommu=pt pcie_ports=compat"/' /etc/default/grub
    else
      echo 'GRUB_CMDLINE_LINUX="intel_iommu=on iommu=pt pcie_ports=compat"' | sudo tee -a /etc/default/grub >/dev/null
    fi
    if command -v grubby &>/dev/null; then
      sudo grubby --update-kernel=ALL --args="intel_iommu=on iommu=pt pcie_ports=compat"
    fi
  fi

  cat > /etc/t2fand.conf <<'EOF'
[Fan1]
low_temp=55
high_temp=75
speed_curve=linear
always_full_speed=false
EOF
fi
