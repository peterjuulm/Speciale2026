#!/usr/bin/env bash
# The dev container's SDK (21 October 2026): the image from .devcontainer,
# then install-sdk.sh as the entrypoint runs it, as the vscode user, on a
# workspace at the branch and on one at main before the branch, which has
# no dotnet-sdk.lock.json. The image is built without the ws CLI: its
# download, from Weel-Sandvig/WS.CLI, answers 404 from outside WS.
#   C=<clone at the branch> M=<clone at main> OUT=<folder> devcontainer-test.sh
set -uo pipefail
C=${C:?a clone at the branch} M=${M:?a clone at main} OUT=${OUT:?a folder}
mkdir -p "$OUT"
I=rb1-devcontainer:test V=rb1-dotnet-sdks
python3 - "$C/.devcontainer/Dockerfile" "$OUT/devcontainer.Dockerfile" <<'EOF'
import re, sys
s = open(sys.argv[1]).read()
s2 = re.sub(r"# ws CLI .*?\n\n", "", s, count=1, flags=re.S)
assert s2 != s
open(sys.argv[2], "w").write(s2)
EOF
echo "build start $(date +%T)"
docker build --no-cache -t $I -f "$OUT/devcontainer.Dockerfile" "$C/.devcontainer" > "$OUT/build.log" 2>&1
echo "build exit $? $(date +%T)"
docker volume rm $V > /dev/null 2>&1; docker volume create $V > /dev/null
as_vscode() {  # workspace, command: as the entrypoint runs setup, su to vscode
  docker run --rm --entrypoint su -v "$1:/workspace:ro" -v $V:/home/vscode/.dotnet-sdks $I vscode -c "$2"
}
show='{ echo "dotnet is $(command -v dotnet) -> $(readlink -f "$(command -v dotnet)")"; cd /workspace && dotnet --version && dotnet --list-runtimes | cut -d" " -f1-2; }'
echo "== D1 the branch, a new volume"
as_vscode "$C" "bash /install-sdk.sh && $show"; echo "exit $?"
echo "== D2 the branch again, a new container: the SDK from the volume"
as_vscode "$C" "time bash /install-sdk.sh 2>&1 | tail -2; ls ~/.dotnet-sdks; $show"; echo "exit $?"
echo "== D3 a non-login shell, as an SSH command gets: PATH and install_location"
as_vscode "$C" "bash /install-sdk.sh > /dev/null && env -i PATH=/usr/local/bin:/usr/bin:/bin bash -c 'cd /workspace && dotnet --version' && cat /etc/dotnet/install_location"; echo "exit $?"
echo "== D4 main before the branch, no lock: the image's SDK"
as_vscode "$M" "bash /install-sdk.sh && $show; ls ~/.dotnet-sdks"; echo "exit $?"
docker volume rm $V > /dev/null
