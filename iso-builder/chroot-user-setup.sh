#!/bin/bash

set -e

if ! id "void-chad" &>/dev/null; then
  useradd -m -s /bin/bash void-chad
fi

usermod -aG wheel,audio,video,cdrom,input void-chad

echo "root:void" | chpasswd
echo "void-chad:void" | chpasswd

cat >/etc/pam.d/su <<'EOF'
#%PAM-1.0
auth       sufficient pam_rootok.so
auth       sufficient pam_wheel.so trust group=wheel
auth       include   system-auth
account    include   system-auth
session    include   system-auth
EOF

cat >/usr/local/bin/sudo <<'EOF'
#!/bin/bash

if [ $# -eq 0 ]; then
    exec su
else
    cmd="$*"
    
    if command -v printf >/dev/null 2>&1 && printf "%q " test >/dev/null 2>&1; then
        su -c "$(printf "%q " "$@")"
    else
        su -c "$cmd"
    fi
fi
EOF

chmod +x /usr/local/bin/sudo

echo 'export PATH="/usr/local/bin:$PATH"' >/etc/profile.d/custom-path.sh
chmod +x /etc/profile.d/custom-path.sh

cat >>/home/void-chad/.bashrc <<'EOF'

alias sudo='/usr/local/bin/sudo'

check_sudo() {
    if ! command -v sudo >/dev/null 2>&1; then
    fi
}
check_sudo
EOF

chown void-chad:void-chad /home/void-chad/.bashrc

cat >/home/void-chad/.bash_profile <<'EOF'
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi
EOF

chown void-chad:void-chad /home/void-chad/.bash_profile

if ! command -v sudo >/dev/null 2>&1; then
  echo "void-chad ALL=(ALL:ALL) NOPASSWD: ALL" >/etc/sudoers.d/void-chad
  chmod 440 /etc/sudoers.d/void-chad
fi

echo ""
echo "User: void-chad"
echo "Password: void"
echo "Password root: void"
echo ""
echo "sudo script is located at: /usr/local/bin/sudo"
echo "Usage: sudo <command>"
echo ""
