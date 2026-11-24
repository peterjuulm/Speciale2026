# What arch's reboot (24 November, about 08:40) cleared, before the rebuild.
uptime; date -Is
echo "guard: $(ls -l /tmp/claude-1000/ws-mem-run.sh 2>&1)"
echo "lock dir: $(ls -ld /tmp/claude-1000 2>&1)"
echo "/tmp/dch: $(ls -ld /tmp/dch 2>&1)"
echo "rb1-dch: $(du -sh /private/tmp/rb1-dch 2>&1 | cut -f1), $(find /private/tmp/rb1-dch -mindepth 1 2>/dev/null | wc -l) entries"
echo "rb1-npm: $(du -sh /private/tmp/rb1-npm 2>&1 | cut -f1)"
ls -d /private/tmp/rb1-* | tr '\n' ' '; echo
ls ~/rb1-dotnet-10.0.401/dotnet && ~/rb1-dotnet-10.0.401/dotnet --version
export DOCKER_CONFIG=/private/tmp/rb1-docker
docker version --format 'docker {{.Server.Version}}'
docker buildx ls 2>&1 | head -5
docker ps -a --format '{{.Names}} {{.Status}}' | head -20
docker image inspect ws-signing:rb-ref6 --format 'signing {{.Id}}'
gh auth status 2>&1 | head -3
grep -E 'MemTotal|MemAvailable' /proc/meminfo; df -h /private/tmp /tmp | tail -2
ls /private/tmp/rb1-rebuild6
