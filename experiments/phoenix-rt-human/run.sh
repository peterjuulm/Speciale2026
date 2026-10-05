#!/bin/bash
#
# Run reprotest once on the Phoenix lab, varying one axis.
#
#   run.sh LAYER AXIS [LABEL]
#
# LAYER 1 builds the two programs. LAYER 2 does what the release job does:
# a locked restore and both publishes. AXIS is a reprotest variation, or
# "none" to vary nothing, or "all". LABEL names the output files.
#
# OUT must point to a folder for the results. You can also set MIN_CPUS
# (default 2), LAB (default /private/tmp/rb1-phoenix) and FIXENV, a
# VAR=VALUE that goes in front of every dotnet command, for example
# FIXENV=LC_ALL=C.UTF-8.
#
# Every build starts and ends with "dotnet build-server shutdown", and
# MSBuild's node reuse is off, so no compiler server or MSBuild node lives
# on from one build into the next. Anything still running after the run is
# listed in leftover-LABEL.txt.
#
# AXIS=user_group runs the experiment build as rb1b (see
# setup-user-group.sh). rb1b can't read /home/leos, so both builds then use
# the SDK copy in /opt/rb1-dotnet, and a second sampler runs as rb1b.

set -u

usage() {
    echo "usage: run.sh LAYER AXIS [LABEL]" >&2
    exit 1
}

die() {
    echo "run.sh: $*" >&2
    exit 2
}

short_hash() {
    if [ -f "$1" ]; then
        sha256sum < "$1" | cut -c1-16
    else
        echo -
    fi
}

[ $# -ge 2 ] || usage
layer=$1
axis=$2
label=${3:-L$layer-$axis}

if [ -z "${OUT:-}" ]; then
    echo "run.sh: set OUT to a private data folder" >&2
    exit 1
fi
MIN_CPUS=${MIN_CPUS:-2}
FIXENV=${FIXENV:-}
LAB=${LAB:-/private/tmp/rb1-phoenix}

experiments=$(cd "$(dirname "$0")/.." && pwd)
reprotest=/home/leos/.local/bin/reprotest
store=$OUT/store-$label
shared=/private/tmp/rb1-shared

dotnet_root=/home/leos/.dotnet
modes_dir=$OUT/modes

case $axis in
none)
    vary=(--vary=-all)
    ;;
all)
    # Leave out the ones that can't run here without extra setup.
    vary=(--vary=+all,-user_group,-fileordering,-domain_host)
    ;;
user_group)
    vary=(--vary=-all,+user_group --vary=user_group.available+=rb1b:rb1b)
    dotnet_root=/opt/rb1-dotnet
    modes_dir=$shared/modes
    ;;
*)
    vary=("--vary=-all,+$axis")
    ;;
esac

# Goes in front of every dotnet command. \$PATH is expanded later, by the
# shell that runs the command, not here.
dotnet_env="env DOTNET_ROOT=$dotnet_root PATH=$dotnet_root:\$PATH DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 MSBUILDDISABLENODEREUSE=1"
if [ -n "$FIXENV" ]; then
    dotnet_env="$dotnet_env $FIXENV"
fi
stop_servers="$dotnet_env dotnet build-server shutdown > /dev/null"
version='/p:Version=0.0.0-thesis /p:InformationalVersion=v0.0.0-thesis'

case $layer in
1)
    build="$dotnet_env dotnet build src/WebAPI/WebAPI.csproj -c Release -p:SkipSpaBuild=true"
    build="$build && $dotnet_env dotnet build src/BackgroundJobExecutor/BackgroundJobExecutor.csproj -c Release"
    hash_dir='src/*/bin'
    hash_file=bin.sha256
    artifacts='bin.sha256'
    artifacts="$artifacts src/WebAPI/bin/Release/net9.0/*.dll"
    artifacts="$artifacts src/WebAPI/bin/Release/net9.0/*.pdb"
    artifacts="$artifacts src/WebAPI/bin/Release/net9.0/*.json"
    artifacts="$artifacts src/BackgroundJobExecutor/bin/Release/net9.0/BackgroundJobExecutor.*"
    ;;
2)
    build="$dotnet_env dotnet restore ./WS.Phoenix.sln --locked-mode $version"
    build="$build && $dotnet_env dotnet publish ./src/WebAPI/WebAPI.csproj -c Release -o ./release/ws-pems-linux-x64 -r linux-x64 --self-contained true --no-restore /p:SkipSpaBuild=true $version"
    build="$build && $dotnet_env dotnet publish ./src/BackgroundJobExecutor/BackgroundJobExecutor.csproj -c Release -o ./release/ws-pems-job-worker-linux-x64 -r linux-x64 --self-contained true --no-restore $version"
    hash_dir=release
    hash_file=release.sha256
    artifacts='release.sha256'
    artifacts="$artifacts release/*/ApplicationCore.* release/*/Infrastructure.*"
    artifacts="$artifacts release/*/WebAPI.* release/*/BackgroundJobExecutor.*"
    artifacts="$artifacts release/*/WebAPI release/*/BackgroundJobExecutor"
    ;;
*)
    die "LAYER must be 1 or 2"
    ;;
esac

mkdir -p "$OUT/modes" "$modes_dir"

for dir in "$LAB"/bin "$LAB"/obj "$LAB"/release "$LAB"/src/*/bin "$LAB"/src/*/obj "$LAB"/tests/bin "$LAB"/tests/obj; do
    if [ -e "$dir" ]; then
        die "the lab holds build output ($dir); clean it first"
    fi
done
if [ -e "$store" ]; then
    die "$store exists"
fi

# This is what reprotest runs as each build, control and experiment. It
# writes a hash list (an artifact, so reprotest compares it) and a list of
# file modes (reprotest only compares contents). It runs under sh -e, so we
# keep the build's exit code ourselves and still shut the servers down when
# the build fails. The \$ parts are expanded inside the build, not here.
hashes="find $hash_dir -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > $hash_file"
modes="find $hash_dir -type f -printf '%m %p\n' | LC_ALL=C sort > $modes_dir/$label-\$(umask)-\$\$.txt"
cmd="$stop_servers; rc=0; ( $build && $hashes && $modes ) || rc=\$?; $stop_servers; exit \$rc"

printf '%s\n' "${vary[*]} --min-cpus $MIN_CPUS" "$cmd" "$artifacts" > "$OUT/rt-$label.cmd"

eval "$stop_servers"

# Sample the dotnet processes while reprotest runs, so we can check
# afterwards that the variation really reached them.
DOTNET_EXE=$dotnet_root/dotnet python3 "$experiments/sample-dotnet.py" "$OUT/samples-$label.txt" &
sampler=$!

if [ "$axis" = user_group ]; then
    # NuGet creates its config with mode 0600, so rb1b couldn't read it.
    # It only lists nuget.org.
    chmod 644 /tmp/dch/.nuget/NuGet/NuGet.Config || exit 2
    cp "$experiments/sample-dotnet.py" "$shared/sample-dotnet.py"
    sudo -n -u rb1b env DOTNET_EXE=$dotnet_root/dotnet python3 "$shared/sample-dotnet.py" "$shared/samples-$label-rb1b.txt" &
fi

start=$(date -Is)
cd "$LAB" || exit 1
timeout 3600 "$reprotest" -v --min-cpus "$MIN_CPUS" --store-dir "$store" \
    "${vary[@]}" -c "$cmd" "$LAB" "$artifacts" > "$OUT/rt-$label.log" 2>&1
status=$?
sleep 2
kill $sampler
eval "$stop_servers"

if [ "$axis" = user_group ]; then
    sudo -n -u rb1b pkill -u rb1b -f "[s]amples-$label-rb1b"
    cp "$shared/samples-$label-rb1b.txt" "$OUT/"
    cp "$modes_dir/$label-"* "$OUT/modes/"
fi

# A compiler server or MSBuild node still running now survived the builds.
pgrep -af -- 'nodemode:|VBCSCompiler' | grep -v JetBrains > "$OUT/leftover-$label.txt"
leftover=$(wc -l < "$OUT/leftover-$label.txt")

control=$(short_hash "$store/control/source-root/$hash_file")
experiment=$(short_hash "$store/experiment-1/source-root/$hash_file")

printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$label" "$layer" "$axis" "$start" "$(date -Is)" \
    "$status" "$control" "$experiment" "$leftover" >> "$OUT/summary.tsv"
echo "$label exit $status control $control experiment $experiment leftover $leftover"
