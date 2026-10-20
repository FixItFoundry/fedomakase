# Configure firewall rules for LocalSend and Docker DNS.
# On Fedora, firewalld is used; fall back to ufw if present.
if command -v firewall-offline-cmd &>/dev/null; then
  firewall-offline-cmd --add-port=53317/udp >/dev/null 2>&1 || true
  firewall-offline-cmd --add-port=53317/tcp >/dev/null 2>&1 || true
  firewall-offline-cmd --zone=trusted --add-interface=docker0 >/dev/null 2>&1 || true
  systemctl enable firewalld.service 2>/dev/null || true
  if systemctl is-active --quiet firewalld.service 2>/dev/null; then
    firewall-cmd --reload >/dev/null 2>&1 || true
  fi
elif command -v ufw &>/dev/null; then
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow 53317/udp
  ufw allow 53317/tcp
  ufw allow in proto udp from 172.16.0.0/12 to 172.17.0.1 port 53 comment 'allow-docker-dns'
  ufw allow in proto udp from 192.168.0.0/16 to 172.17.0.1 port 53 comment 'allow-docker-dns'
  sed -i 's/^ENABLED=.*/ENABLED=yes/' /etc/ufw/ufw.conf 2>/dev/null || true
  systemctl enable ufw 2>/dev/null || true
fi
