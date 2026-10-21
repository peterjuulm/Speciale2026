# Serilog 4.2.0 as its CI built it, imitated on Linux (pilot builds A and B).
# Declared: .nuspec repository + commit; ci.yml (windows-latest, setup-dotnet 9.0.x,
# actions/checkout@v4 at depth 1, CI_TARGET_BRANCH=main on a push to main, a
# CI_BUILD_NUMBER, which on main only means "no package suffix"); Build.ps1's
# dotnet commands, run here directly since PowerShell is not installed.
# SDK 9.0.101 from the PDB's compiler record (Roslyn 4.12.0-3.24570.6, runtime 9.0.0).
REPO=https://github.com/serilog/serilog
COMMIT=c00e17fdeb615d36c062569f7342f72c9ece4aa7
SDK_DIR=/private/tmp/nupkg-pilot/sdk/9.0.101
DEPTH=1
GIT_CONFIG="core.autocrlf=true"   # Git for Windows' default on a Windows runner
VARS="CI_TARGET_BRANCH=main"
# Build.ps1 on main with a build number: suffix "", build suffix "<branch>-<short hash>".
BUILD='dotnet --version && dotnet restore --no-cache && dotnet build -c Release --version-suffix=main-$(git rev-parse --short HEAD) /p:ContinuousIntegrationBuild=true && cd src/Serilog && dotnet pack -c Release --no-build --no-restore -o ../../artifacts'
SHIPS=lib/net9.0/Serilog.dll
