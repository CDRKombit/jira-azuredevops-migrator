<#
.SYNOPSIS
Runs jira-export or wi-import in a fresh jira-ado-migrator container, which is removed afterwards.

.DESCRIPTION
Tokens are read from pat\jira-pat.md and pat\azureDevOps-pat.md (git-ignored).
The Jira login defaults to <Windows username>@kombit.dk; set $env:JIRA_USER to override.
Config is mounted read-only from migration\config, data from migration\workspace.

.EXAMPLE
.\migrate.ps1 export --force
.\migrate.ps1 import
#>
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet('export', 'import', 'help')]
    [string]$Command,

    [Parameter(ValueFromRemainingArguments)]
    [string[]]$ToolArgs
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$image = 'jira-ado-migrator'

function Read-Token([string]$file) {
    $path = Join-Path $root "pat\$file"
    if (-not (Test-Path $path)) { throw "Token file not found: $path" }
    (Get-Content $path -Raw).Trim()
}

docker image inspect $image *> $null
if ($LASTEXITCODE -ne 0) { throw "Docker image '$image' not found. Build it from the repo root: docker build -t $image ." }

$envArgs = @()
switch ($Command) {
    'export' {
        $env:JIRA_URL = 'https://kombit.atlassian.net'
        if (-not $env:JIRA_USER) { $env:JIRA_USER = "$($env:USERNAME.ToLower())@kombit.dk" }
        $env:JIRA_API_TOKEN = Read-Token 'jira-pat.md'
        $envArgs = '-e', 'JIRA_URL', '-e', 'JIRA_USER', '-e', 'JIRA_API_TOKEN'
    }
    'import' {
        $env:ADO_URL = 'https://dev.azure.com/kombitdk'
        $env:ADO_PAT = Read-Token 'azureDevOps-pat.md'
        $envArgs = '-e', 'ADO_URL', '-e', 'ADO_PAT'
    }
}

# -t only when there is a console to attach to; the tools may ask questions on it.
$tty = if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) { '-i' } else { '-it' }

try {
    docker run --rm $tty @envArgs `
        -v "$root\migration\config:/config:ro" `
        -v "$root\migration\workspace:/workspace" `
        $image $Command @ToolArgs
    $exitCode = $LASTEXITCODE
}
finally {
    # The tools always log into the workspace; move the logs out after each run.
    # The journals (itemsJournal.txt, attachmentsJournal.txt) stay, as resuming an import depends on them.
    $logDir = Join-Path $root 'migration\archive\logs'
    $logs = Get-ChildItem (Join-Path $root 'migration\workspace') -Filter '*-log-*.txt' -ErrorAction SilentlyContinue
    if ($logs) {
        New-Item -ItemType Directory -Force $logDir | Out-Null
        $logs | Move-Item -Destination $logDir -Force
        Write-Host "Logs moved to $logDir"
    }
}
exit $exitCode
