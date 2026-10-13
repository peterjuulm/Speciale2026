#!/bin/bash
# scripts/pack-release-zip.sh and the two release steps that call it, tested
# (written 13 October 2026).
#
# Takes the script and the workflows from COMMIT, and the steps before it from
# COMMIT^. From the two normalised zips of a layer Z run (run.sh), it checks:
#   T1  the script, from folders with scrambled times and modes, gives those
#       zips byte for byte; T1b a trailing slash and a stale zip at the target
#       change nothing;
#   T2  the Linux release step, before and after, run as GitHub runs a step
#       without a shell (bash -e) in a workspace with one commit at EPOCH,
#       gives those zips;
#   T3  the new Windows step gives the same zips in two workspaces set up
#       differently (disk against tmpfs, umask, time zone, locale, files
#       created in reverse order, scrambled times and modes); T3b the old
#       step gives the same entry names at the same paths;
#   T4, T5  what the script refuses, and that it refuses before it changes
#       anything.
#
#   ZIPS=<folder with the two zips> EPOCH=<the run's ZEPOCH> pack-zip-test.sh COMMIT
#
# The zips' tag is v0.0.0-thesis (TAG). zip comes from TOOLS (default
# /private/tmp/rb1-tools, the measurements' Info-ZIP 3.0). T and M are
# scratch folders, M on tmpfs; both are deleted at the end.
set -euo pipefail
W=${REPO:-/home/leos/Dev/Weel-Sandvig/WS.Phoenix-repro}
NEW=${1:?usage: ZIPS=<folder> EPOCH=<seconds> pack-zip-test.sh COMMIT}
OLD=$NEW^
ZN=${ZIPS:?set ZIPS to the folder with the two normalised zips}
EPOCH=${EPOCH:?set EPOCH to the ZEPOCH of the Z run}
TAG=${TAG:-v0.0.0-thesis}
T=${T:-/private/tmp/rb1-pack-test}
M=${M:-/tmp/rb1-pack-tmpfs}
REF_WEB=$(sha256sum < $ZN/ws-pems-linux-x64-$TAG.zip | cut -d' ' -f1)
REF_JOB=$(sha256sum < $ZN/ws-pems-job-worker-linux-x64-$TAG.zip | cut -d' ' -f1)
export PATH=${TOOLS:-/private/tmp/rb1-tools}:/usr/bin
unset SOURCE_DATE_EPOCH
rm -rf $T $M; mkdir -p $T $M
S=$T/pack-release-zip.sh
git -C $W show $NEW:scripts/pack-release-zip.sh > $S && chmod 755 $S
echo "COMMIT $(git -C $W rev-parse --short $NEW), before it $(git -C $W rev-parse --short $OLD); zips $REF_WEB $REF_JOB"
h() { sha256sum "$1" | cut -d' ' -f1; }
check() { if [[ "$2" == "$3" ]]; then echo "PASS $1"; else echo "FAIL $1: $2 != $3"; fi; }
step() { python3 - "$@" <<'PY'
import sys,yaml
y=yaml.safe_load(open(sys.argv[1]))
s=[x for x in y['jobs'][sys.argv[2]]['steps'] if x.get('name')==sys.argv[3]]
assert len(s)==1, sys.argv[3]
open(sys.argv[4],'w').write(s[0]['run'])
print(sys.argv[4], 'working-directory:', s[0].get('working-directory','(root)'))
PY
}
sim() { mkdir -p "$1/scripts"; git -C "$1" init -q
  GIT_COMMITTER_DATE="@$EPOCH +0000" GIT_AUTHOR_DATE="@$EPOCH +0000" git -C "$1" -c user.name=t -c user.email=t@t commit -q --allow-empty -m sim
  cp "$S" "$1/scripts/"; }
perturb() { local files; mapfile -d '' files < <(find "$1" -type f -print0)
  chmod g+w "${files[@]:0:500}"; chmod o-r "${files[@]: -300}"
  find "$1" -exec touch -d "@$((EPOCH - 86400*400))" {} +
  touch -d "2031-02-03 04:05:06" "${files[@]:0:200}"; }
gh_step() { local ws=$1 wd=$2 sh=$3; shift 3   # as GitHub runs a step without shell: bash -e {0}
  (cd "$ws/$wd" && env -i PATH=$PATH HOME=$T GITHUB_WORKSPACE=$ws "$@" bash -e "$sh"); }

date +%T
echo "== T1: the script, from perturbed trees, gives the release's measured zips"
mkdir -p $T/t1 && cd $T/t1
unzip -q $ZN/ws-pems-linux-x64-$TAG.zip; unzip -q $ZN/ws-pems-job-worker-linux-x64-$TAG.zip
echo "files: web $(find ws-pems-linux-x64 -type f | wc -l), job $(find ws-pems-job-worker-linux-x64 -type f | wc -l)"
perturb ws-pems-linux-x64; perturb ws-pems-job-worker-linux-x64
SOURCE_DATE_EPOCH=$EPOCH $S ws-pems-linux-x64 web.zip
SOURCE_DATE_EPOCH=$EPOCH $S ws-pems-job-worker-linux-x64 job.zip
check T1-web "$(h web.zip)" $REF_WEB
check T1-job "$(h job.zip)" $REF_JOB
echo "== T1b: a trailing slash on the folder, and a stale zip at the target"
zip -q stale.zip /etc/os-release
SOURCE_DATE_EPOCH=$EPOCH $S ws-pems-job-worker-linux-x64/ stale.zip
check T1b "$(h stale.zip)" $REF_JOB

echo "== T2: the Linux release step, old (HEAD) and new (worktree), as written"
git -C $W show $OLD:.github/workflows/03-release.yml > $T/03-old.yml
git -C $W show $NEW:.github/workflows/03-release.yml > $T/03-new.yml
step $T/03-old.yml publish-linux "Create release archives" $T/step-linux-old.sh
step $T/03-new.yml publish-linux "Create release archives" $T/step-linux-new.sh
for v in old new; do sim $T/t2-$v; mkdir -p $T/t2-$v/release; done
mv $T/t1/ws-pems-linux-x64 $T/t1/ws-pems-job-worker-linux-x64 $T/t2-new/release/
cp -a $T/t2-new/release/. $T/t2-old/release/
for v in old new; do
  perturb $T/t2-$v/release/ws-pems-linux-x64; perturb $T/t2-$v/release/ws-pems-job-worker-linux-x64
  gh_step $T/t2-$v . $T/step-linux-$v.sh REF_NAME=$TAG
  check T2-$v-web "$(h $T/t2-$v/release/ws-pems-linux-x64-$TAG.zip)" $REF_WEB
  check T2-$v-job "$(h $T/t2-$v/release/ws-pems-job-worker-linux-x64-$TAG.zip)" $REF_JOB
done
rm -rf $T/t1 $T/t2-old

echo "== T3: the Windows step, new, in two workspaces under different conditions"
git -C $W show $OLD:.github/workflows/00-reusable-windows-publish.yml > $T/win-old.yml
git -C $W show $NEW:.github/workflows/00-reusable-windows-publish.yml > $T/win-new.yml
step $T/win-old.yml publish-windows "Create release archives" $T/step-win-old.sh
step $T/win-new.yml publish-windows "Create release archives" $T/step-win-new.sh
R=$T/t2-new/release
sim $T/t3a; mkdir -p $T/t3a/release/win
cp -a $R/ws-pems-linux-x64 $T/t3a/release/win/ws-pems-win-x64
cp -a $R/ws-pems-job-worker-linux-x64 $T/t3a/release/win/ws-pems-job-worker-win-x64
sim $M/t3b; mkdir -p $M/t3b/release/win
for pair in "ws-pems-linux-x64 ws-pems-win-x64" "ws-pems-job-worker-linux-x64 ws-pems-job-worker-win-x64"; do
  set -- $pair
  (cd $R/$1 && find . -type d | LC_ALL=C sort -r | while read -r d; do mkdir -p "$M/t3b/release/win/$2/$d"; done
   find . -type f | LC_ALL=C sort -r | while read -r f; do cp "$f" "$M/t3b/release/win/$2/$f"; done)
done
perturb $M/t3b/release/win/ws-pems-win-x64; perturb $M/t3b/release/win/ws-pems-job-worker-win-x64
echo "first names as listed: A $(ls -U $T/t3a/release/win/ws-pems-win-x64 | head -3 | tr '\n' ' ')/ B $(ls -U $M/t3b/release/win/ws-pems-win-x64 | head -3 | tr '\n' ' ')"
(umask 022; gh_step $T/t3a release/win $T/step-win-new.sh TZ=UTC LC_ALL=C.UTF-8 RELEASE_VERSION=$TAG)
(umask 002; gh_step $M/t3b release/win $T/step-win-new.sh TZ=GMT-14 LANG=et_EE.UTF-8 LC_ALL=et_EE.UTF-8 RELEASE_VERSION=$TAG)
ls $T/t3a/release/*.zip | sed "s|$T/t3a/||"
for z in ws-pems-win-x64-$TAG.zip ws-pems-job-worker-win-x64-$TAG.zip; do
  check "T3 $z A=B" "$(h $T/t3a/release/$z)" "$(h $M/t3b/release/$z)"
  unzip -tq $T/t3a/release/$z
done
echo "== T3b: the old Windows step gives the same entry names, at the same paths"
sim $T/t3o; mkdir -p $T/t3o/release/win
cp -a $T/t3a/release/win/ws-pems-win-x64 $T/t3a/release/win/ws-pems-job-worker-win-x64 $T/t3o/release/win/
gh_step $T/t3o release/win $T/step-win-old.sh RELEASE_VERSION=$TAG
for z in ws-pems-win-x64-$TAG.zip ws-pems-job-worker-win-x64-$TAG.zip; do
  if diff <(unzip -Z1 $T/t3o/release/$z | LC_ALL=C sort) <(unzip -Z1 $T/t3a/release/$z | LC_ALL=C sort) >/dev/null; then echo "PASS T3b $z names ($(unzip -Z1 $T/t3a/release/$z | wc -l))"; else echo "FAIL T3b $z names"; fi
done

echo "== T4: errors"
cd $T; set +e
$S t3a x.zip 2>&1; echo "  no SOURCE_DATE_EPOCH: exit $?"
SOURCE_DATE_EPOCH=abc $S t3a x.zip 2>&1; echo "  not a number: exit $?"
SOURCE_DATE_EPOCH=1 $S missing x.zip 2>&1; echo "  missing folder: exit $?"
SOURCE_DATE_EPOCH=1 $S t3a 2>&1; echo "  one argument: exit $?"
echo "== T5: what the script refuses, before it changes anything"
mkdir -p $T/t5/f/sub && cd $T/t5 && echo x > f/sub/a && touch -d @1000000000 f/sub/a
ok() { local want=$1; shift; out=$(SOURCE_DATE_EPOCH=$EPOCH $S "$@" 2>&1); rc=$?
  if [[ $rc -eq 2 && $(stat -c %Y f/sub/a) -eq 1000000000 ]]; then echo "PASS refused ($want): $out"; else echo "FAIL $want: rc $rc, $out"; fi; }
ok "zip inside the folder" f f/x.zip
ok "zip deep inside the folder" f f/sub/x.zip
ok "zip path starting with -" f -x.zip
ok "folder with a slash" ./f x.zip
ok "folder ." . x.zip
ln -s sub f/link; ok "a symbolic link" f x.zip; rm f/link
touch f/$'new\nline'; ok "a name with a newline" f x.zip; rm f/$'new\nline'
mkdir -- -g; ok "folder starting with -" -g x.zip; rmdir -- -g
echo y > "f/sub/a b.txt"
SOURCE_DATE_EPOCH=$EPOCH $S f x.zip; echo "  spaces: exit $?, $(unzip -Z1 x.zip | tr '\n' ' ')"
SOURCE_DATE_EPOCH=$EPOCH $S f/ ../x2.zip; cmp x.zip ../x2.zip && echo "PASS the same zip written outside the current directory"
set -e
rm -rf $T $M
date +%T; echo done
