# SDK 10.0.401 into ~/rb1-dotnet-10.0.401 (under leos, not system-wide), with
# the branch's own installer and lock at thesis-merge (30b5c745d): the
# archive's SHA-512 from dotnet-sdk.lock.json, the runtime checked after.
set -euo pipefail
src=/private/tmp/rb1-merge-src
w=/private/tmp/rb1-sdk-install
rm -rf "$w"; mkdir -p "$w"
for f in global.json dotnet-sdk.lock.json scripts/install-dotnet-sdk.py; do
  mkdir -p "$w/$(dirname "$f")"; git -C "$src" show "thesis-merge:$f" > "$w/$f"
done
python3 --version
test ! -e ~/rb1-dotnet-10.0.401 || { echo "~/rb1-dotnet-10.0.401 exists already"; exit 1; }
python3 -I "$w/scripts/install-dotnet-sdk.py" --global-json "$w/global.json" --cache ~/rb1-dotnet-cache ~/rb1-dotnet-10.0.401
~/rb1-dotnet-10.0.401/dotnet --list-sdks
~/rb1-dotnet-10.0.401/dotnet --list-runtimes
