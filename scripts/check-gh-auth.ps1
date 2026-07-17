# Non-interactive GitHub CLI health check for agents running in Windows PowerShell.
# Exit 0 = ready for paper-weight kanban work. Exit 1 = real problem (do NOT invent reauth).
# Usage: powershell -File scripts\check-gh-auth.ps1
# POSIX shells must use scripts/check-gh-auth.sh instead of invoking PowerShell.

$ErrorActionPreference = "Continue"
$requiredScopes = @("repo", "project", "read:org")

Write-Host "=== gh path ==="
$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) {
    Write-Host "FAIL: gh not on PATH in this Windows environment."
    exit 1
}
Write-Host $gh.Source

Write-Host "`n=== auth status ==="
$status = gh auth status 2>&1 | Out-String
Write-Host $status
if ($LASTEXITCODE -ne 0 -or $status -notmatch 'Logged in') {
    Write-Host "FAIL: not logged in. Human must run: gh auth login"
    exit 1
}

# Scopes line looks like: - Token scopes: 'gist', 'project', 'read:org', 'repo', 'workflow'
$scopeLine = ($status -split "`n" | Where-Object { $_ -match 'Token scopes:' } | Select-Object -First 1)
if (-not $scopeLine) {
    Write-Host "WARN: could not parse scopes; attempting project API smoke test"
} else {
    Write-Host "scopes line: $scopeLine"
    foreach ($s in $requiredScopes) {
        if ($scopeLine -notmatch [regex]::Escape($s)) {
            Write-Host "FAIL: missing scope '$s'."
            Write-Host "Human must run once (interactive): gh auth refresh -s repo,project,read:org,workflow,gist"
            exit 1
        }
    }
}

Write-Host "`n=== project API smoke ==="
$proj = gh project view 1 --owner rorybot --format json 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) {
    Write-Host $proj
    Write-Host "FAIL: cannot read project #1. If scopes look fine, check network / SSO."
    exit 1
}
Write-Host "OK: project #1 readable"

Write-Host "`n=== notes for agents ==="
Write-Host "- This helper is Windows-only; POSIX shells use scripts/check-gh-auth.sh."
Write-Host "- Prefer gh CLI over GitHub MCP for Projects (MCP often lacks project permission)."
Write-Host "- Do NOT run gh auth login/refresh unless this script exits 1."
Write-Host "- Do NOT print tokens (avoid: gh auth status -t / gh auth token in logs)."
exit 0
