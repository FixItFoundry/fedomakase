# Configure DNF repositories after package installation completes.
# On Fedora, we ensure COPR repos from the single source of truth are persisted in /etc/yum.repos.d/.

COPR_FILE="${OMARCHY_INSTALL:-/usr/share/omarchy/install}/omarchy-fedora-copr.repos"
if [[ -f "$COPR_FILE" ]]; then
  mkdir -p /etc/yum.repos.d
  while IFS= read -r copr; do
    [[ -z "$copr" || "$copr" =~ ^[[:space:]]*# || "$copr" == *=* ]] && continue
    owner="${copr%%/*}"
    project="${copr##*/}"
    repo_file="/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:${owner}:${project}.repo"
    if [[ ! -f "$repo_file" ]]; then
      cat > "$repo_file" <<EOF
[copr:copr.fedorainfracloud.org:${owner}:${project}]
name=Copr repo for ${project} owned by ${owner}
baseurl=https://copr-be.cloud.fedoraproject.org/results/${owner}/${project}/fedora-\$releasever-\$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://copr-be.cloud.fedoraproject.org/results/${owner}/${project}/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
EOF
    fi
  done < "$COPR_FILE"
fi

# During Kickstart %post (iso-chroot), Anaconda already installed %packages;
# only run install-base-packages.sh when invoked standalone outside the ISO installer.
if [[ ${OMARCHY_SETUP_CONTEXT:-runtime} != "iso-chroot" ]] && [[ ${OMARCHY_INSTALL_BASE_PACKAGES:-0} == "1" ]]; then
  source "$OMARCHY_INSTALL/install-base-packages.sh"
fi

source "$OMARCHY_INSTALL/hardware/dnf.sh"
