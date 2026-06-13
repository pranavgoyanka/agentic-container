source .env
./scripts/stop.sh
./scripts/destroy.sh

# Edit .env — change WORKSPACE_FOLDER to the new project
echo =========================================
echo Starting Claude Code in $WORKSPACE_FOLDER
echo =========================================
./scripts/create.sh
./scripts/start.sh
