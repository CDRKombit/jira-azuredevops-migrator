#!/bin/sh
# Dispatches to jira-export / wi-import, taking credentials from environment variables.
set -e

CONFIG="${CONFIG:-/config/config.json}"
cmd="${1:-help}"
[ $# -gt 0 ] && shift

require() {
  for v in "$@"; do
    eval "val=\${$v}"
    if [ -z "$val" ]; then echo "Missing environment variable: $v" >&2; exit 1; fi
  done
}

case "$cmd" in
  export)
    require JIRA_URL JIRA_USER JIRA_API_TOKEN
    exec dotnet /app/export/jira-export.dll -u "$JIRA_USER" -p "$JIRA_API_TOKEN" --url "$JIRA_URL" --config "$CONFIG" "$@"
    ;;
  import)
    require ADO_URL ADO_PAT
    exec dotnet /app/import/wi-import.dll --token "$ADO_PAT" --url "$ADO_URL" --config "$CONFIG" "$@"
    ;;
  help|-h|--help)
    echo "Usage: migrate export [--force] | migrate import [--force] [--continue true]"
    echo "Env:   JIRA_URL JIRA_USER JIRA_API_TOKEN ADO_URL ADO_PAT [CONFIG=/config/config.json]"
    ;;
  *)
    exec "$cmd" "$@"
    ;;
esac
