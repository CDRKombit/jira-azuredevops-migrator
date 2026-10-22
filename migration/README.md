# Migrating Jira (kombit.atlassian.net) to Azure DevOps (dev.azure.com/kombitdk)

This folder is mounted into the container as `/workspace`. The config, user mapping, exported JSON,
attachments, journals and logs all end up here.

## 1. Build the image (from the repo root)

```powershell
docker build -t jira-ado-migrator .
```

## 2. Prepare

1. `Copy-Item migration\.env.example migration\.env` and fill in the tokens.
2. Edit `config.json`:
   - `source-project`: the Jira project key, and `query`: JQL for what to export.
   - `target-project`: an **existing** Azure DevOps project; `process-template` must match its process (Agile/Scrum/CMMI/Basic).
   - `type-map`, `field-map` (status → state, custom fields), `link-map`. See `docs/config.md`.
3. Fill `users.txt` with `jira-email=ado-email`, one line per user.

## 3. Run

```powershell
# Export from Jira into migration\ (one JSON file per issue plus attachments)
docker run --rm -it --env-file migration\.env -v "${PWD}\migration:/workspace" jira-ado-migrator export --force

# Import into Azure DevOps
docker run --rm -it --env-file migration\.env -v "${PWD}\migration:/workspace" jira-ado-migrator import
```

Keep `-it`: the tools can stop and ask a question on the console.

Leave out `--force` to resume an interrupted run. The journals (`itemsJournal.txt`, `attachmentsJournal.txt`)
record what has already been imported. `import --force` imports everything again and creates duplicates,
so only use it against a test project.

## Recommended approach

Do a trial run with a small JQL query (e.g. `project = KEY AND created >= -30d`) into a throwaway ADO project.
Check the result and the logs (`jira-export-log-*.txt`, `wi-import-log-*.txt`), adjust the mappings, then run
the full migration.
