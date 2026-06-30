param(
    [switch]$PushOnly
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$bundledGit = 'C:\Users\Prasun PC\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\git\cmd\git.exe'
$git = if (Test-Path -LiteralPath $bundledGit) { $bundledGit } else { (Get-Command git).Source }
$safe = $repo.Replace('\', '/')

function Invoke-Git {
    & $git -c "safe.directory=$safe" -C $repo @args
    if ($LASTEXITCODE -ne 0) { throw "Git command failed: $($args -join ' ')" }
}

if (-not $PushOnly) {
    Invoke-Git add --all
    & $git -c "safe.directory=$safe" -C $repo diff --cached --quiet
    if ($LASTEXITCODE -eq 1) {
        $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Invoke-Git commit -m "Automatic workspace update $stamp"
    } elseif ($LASTEXITCODE -ne 0) {
        throw 'Unable to inspect staged changes.'
    }
}

Invoke-Git push origin main
