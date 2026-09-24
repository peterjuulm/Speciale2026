#!/bin/bash
# One-time setup on arch for reprotest's user_group variation, which runs the
# experiment build as a second user. Run it yourself, as root:
#
#     sudo bash setup-user-group.sh
#
# It changes the system, so read it first. What it does, and how to undo it:
# 1. Creates the system user rb1b: no password, no login shell.
#    Undo: userdel -r rb1b
# 2. Copies Leo's .NET SDK (~/.dotnet, about 700 MB) to /opt/rb1-dotnet, so
#    both users build with the same SDK. /home/leos is 0700, so rb1b cannot
#    reach ~/.dotnet. Undo: rm -rf /opt/rb1-dotnet
# 3. Creates /private/tmp/rb1-shared (mode 1777) for the files both users'
#    builds write: mode lists and rb1b's process samples.
#    Undo: rm -rf /private/tmp/rb1-shared
# 4. Installs the sudo rules reprotest prints for this variation
#    (reprotest --print-sudoers) as /etc/sudoers.d/reprotest-rb1b, after
#    checking them with visudo. They let leos run any command as rb1b without
#    a password, and chown reprotest's build folders between leos and rb1b.
#    Undo: rm /etc/sudoers.d/reprotest-rb1b
#
# Written 24 September 2026.
set -eu
[ "$(id -u)" = 0 ] || { echo "run with sudo" >&2; exit 1; }

id rb1b > /dev/null 2>&1 || useradd --system --user-group --no-create-home --shell /usr/bin/nologin rb1b
echo "user: $(id rb1b)"

if [ ! -x /opt/rb1-dotnet/dotnet ]; then
  mkdir -p /opt/rb1-dotnet
  cp -a /home/leos/.dotnet/. /opt/rb1-dotnet/
  chown -R root:root /opt/rb1-dotnet
  chmod -R a+rX,go-w /opt/rb1-dotnet
fi
echo "SDK: $(/opt/rb1-dotnet/dotnet --version), csc $(sha256sum /opt/rb1-dotnet/sdk/9.0.120/Roslyn/bincore/csc.dll | cut -c1-16)"

mkdir -p /private/tmp/rb1-shared
chmod 1777 /private/tmp/rb1-shared

RULES=$(mktemp)
sudo -u leos /home/leos/.local/bin/reprotest --print-sudoers --vary=user_group.available+=rb1b:rb1b 2> /dev/null > "$RULES"
visudo -cf "$RULES"
install -m 0440 -o root -g root "$RULES" /etc/sudoers.d/reprotest-rb1b
rm -f "$RULES"
echo "sudo rules: /etc/sudoers.d/reprotest-rb1b, $(grep -c ^leos /etc/sudoers.d/reprotest-rb1b) lines"
sudo -u leos sudo -n -u rb1b true && echo "leos can run commands as rb1b without a password"
