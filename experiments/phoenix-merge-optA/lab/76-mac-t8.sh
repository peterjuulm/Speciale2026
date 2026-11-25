# The Mac Studio, 25 November: the published v0.0.0-thesis.8 (tag on
# 1c90ad428, Leo's go of the morning) rebuilt with the tag's own rebuild.sh,
# WITHOUT the lab patch and without DOCKER_DEFAULT_PLATFORM in the container:
# the tag's rebuild.sh reads the daemon's architecture (aarch64 in colima's
# vz VM), checks the kernel's x86-64 handler (Rosetta), and builds for
# linux/amd64 with BuildKit's QEMU out of its builder. This is also the test
# of those two changes (a test on dry run 7 was stopped for the tag).
# Expected: SAME for all 15 subjects. If it fails on the platform or the
# QEMU, run again with PATCH=1 so that thesis.8 is still verified.
cd "$(dirname "$0")/.." && PUBLISHED=1 T=v0.0.0-thesis.8 TIP=v0.0.0-thesis.8 NAME=t8 NO_OUTER_PLATFORM=1 REUSE=${REUSE:-} PATCH=${PATCH:-} bash lab/70-mac-verify.sh
