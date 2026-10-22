# Migrating Jira (kombit.atlassian.net) to Azure DevOps (dev.azure.com/kombitdk)

Two folders are mounted into the container:

| Local folder           | In container  | Contents                                                       |
|------------------------|---------------|----------------------------------------------------------------|
| `migration\config`     | `/config`     | `config.json` and `users.txt` (mounted read-only)              |
| `migration\workspace`  | `/workspace`  | Exported items (JSON), attachments, journals and logs          |

The config is kept out of the workspace because the importer treats every `*.json` in the workspace as a work item.

## 1. Build the image (from the repo root)

```powershell
docker build -t jira-ado-migrator .
```

## 2. Prepare

1. `Copy-Item migration\.env.example migration\.env` and fill in the tokens.
   Also copy `config\config.example.json` to `config\config.json` and `config\users.example.txt` to `config\users.txt`.
   The real `.env`, `config.json` and `users.txt` are git-ignored and stay local.
2. Edit `config.json`:
   - `source-project`: the Jira project key, and `query`: JQL for what to export.
   - `target-project`: an **existing** Azure DevOps project; `process-template` must match its process (Agile/Scrum/CMMI/Basic).
   - `type-map`, `field-map` (status → state, custom fields), `link-map`. See `docs/config.md`.
3. Fill `users.txt` with `jira-email=ado-email`, one line per user. Users whose Jira e-mail matches their
   Azure DevOps login need no entry.

## 3. Run

Each run starts a fresh container that is removed afterwards. Everything worth keeping lives in
`migration\config` and `migration\workspace`, so a new container always uses the latest image and current tokens.

The easiest way, from the repo root (tokens are read from `pat\jira-pat.md` and `pat\azureDevOps-pat.md`;
the Jira login defaults to `<Windows username>@kombit.dk`, override with `$env:JIRA_USER`):

```powershell
.\migrate.ps1 export --force
.\migrate.ps1 import
```

Or with plain Docker commands, using `migration\.env` for the credentials:

```powershell
$mounts = @('-v', "${PWD}\migration\config:/config:ro", '-v', "${PWD}\migration\workspace:/workspace")

# Export from Jira into migration\workspace (one JSON file per issue plus attachments)
docker run --rm -it --env-file migration\.env @mounts jira-ado-migrator export --force

# Import into Azure DevOps
docker run --rm -it --env-file migration\.env @mounts jira-ado-migrator import
```

Keep `-it`: the tools can stop and ask a question on the console.

Leave out `--force` to resume an interrupted run. The journals (`itemsJournal.txt`, `attachmentsJournal.txt`)
record what has already been imported. `import --force` imports everything again and creates duplicates,
so only use it against a test project.

When switching to a different set of issues, empty `migration\workspace` first; otherwise the old export is imported too.

## Recommended approach

Do a trial run with a small JQL query (e.g. `project = KEY AND created >= -30d`) into a throwaway ADO project.
Check the result and the logs (`jira-export-log-*.txt`, `wi-import-log-*.txt`), adjust the mappings, then run
the full migration.
