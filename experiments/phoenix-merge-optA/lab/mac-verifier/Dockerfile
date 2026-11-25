# A Linux x86-64 machine for scripts/release/rebuild.sh on the Mac Studio
# (under Rosetta in colima): the tools it needs, Docker's CLI and buildx to
# reach the VM's daemon through its socket. Tools only; nothing of the build.
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends git python3 curl unzip zip ca-certificates libicu74 docker.io docker-buildx \
 && rm -rf /var/lib/apt/lists/*
