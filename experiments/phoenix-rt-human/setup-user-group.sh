#!/bin/bash
#
# One-time setup on arch for reprotest's user_group variation, which runs
# the experiment build as a second user, rb1b. It changes the system, so
# read it before you run it:
#
#   sudo bash setup-user-group.sh
#
# To undo it:
#
#   userdel -r rb1b
#   rm -rf /opt/rb1-dotnet /private/tmp/rb1-shared
#   rm /etc/sudoers.d/reprotest-rb1b

set -eu

if [ "$(id -u)" != 0 ]; then
    echo "run with sudo" >&2
    exit 1
fi

user=rb1b
sdk=/opt/rb1-dotnet
shared=/private/tmp/rb1-shared
rules=/etc/sudoers.d/reprotest-rb1b
reprotest=/home/leos/.local/bin/reprotest

# A system user with no password and no login shell.
if ! id "$user" > /dev/null 2>&1; then
    useradd --system --user-group --no-create-home --shell /usr/bin/nologin "$user"
fi
echo "user: $(id "$user")"

# rb1b can't read /home/leos (mode 0700), so both users get the same SDK
# from /opt. It's about 700 MB.
if [ ! -x "$sdk/dotnet" ]; then
    mkdir -p "$sdk"
    cp -a /home/leos/.dotnet/. "$sdk/"
    chown -R root:root "$sdk"
    chmod -R a+rX,go-w "$sdk"
fi
echo "SDK: $("$sdk/dotnet" --version), csc $(sha256sum "$sdk/sdk/9.0.120/Roslyn/bincore/csc.dll" | cut -c1-16)"

# Both users' builds write their mode lists and process samples here.
mkdir -p "$shared"
chmod 1777 "$shared"

# The sudo rules reprotest asks for: leos may run any command as rb1b and
# chown reprotest's build folders between the two users. Check them with
# visudo before installing them.
tmp=$(mktemp)
sudo -u leos "$reprotest" --print-sudoers --vary=user_group.available+=$user:$user 2> /dev/null > "$tmp"
visudo -cf "$tmp"
install -m 0440 -o root -g root "$tmp" "$rules"
rm -f "$tmp"
echo "sudo rules: $rules, $(grep -c ^leos "$rules") lines"

sudo -u leos sudo -n -u "$user" true && echo "leos can run commands as $user without a password"
