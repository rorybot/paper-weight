# LEGACY: originally created *draft* project items from kanban/board.md.
# Board cards are now real repo issues (rorybot/paper-weight#1–#20) on project #1.
# Prefer: gh issue create --repo rorybot/paper-weight ... then
#   gh project item-add 1 --owner rorybot --url <issue-url>
# Requires: gh auth with 'project' scope  ->  gh auth refresh -s project
# Usage: powershell -File scripts\push-cards.ps1 [-DryRun] [-Only P1,N2,...]
# WARNING: still creates drafts if run; do not re-run for existing cards.
param(
    [switch]$DryRun,
    [string[]]$Only
)

$boardPath = Join-Path $PSScriptRoot "..\kanban\board.md"
$lines = Get-Content $boardPath -Encoding UTF8
# Make sure non-ASCII (em-dashes, arrows) survives the trip into gh's argv
$OutputEncoding = [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

# Parse "### <ID> [epic] Title" sections; body = lines until the next heading.
$cards = @()
$current = $null
foreach ($line in $lines) {
    if ($line -match '^### (.+)$') {
        if ($null -ne $current) { $cards += $current }
        $current = @{ Title = $Matches[1].Trim(); Body = @() }
    } elseif ($line -match '^## ' -and $null -ne $current) {
        $cards += $current
        $current = $null
    } elseif ($null -ne $current) {
        $current.Body += $line
    }
}
if ($null -ne $current) { $cards += $current }

foreach ($card in $cards) {
    $id = ($card.Title -split ' ')[0]
    if ($Only -and ($Only -notcontains $id)) { continue }
    $body = (($card.Body -join "`n").Trim()) + "`n`nSpec: docs/design/carthing-context.md - Workflow: PROJECT_INSTRUCTIONS.md"
    if ($DryRun) {
        Write-Host "WOULD CREATE: $($card.Title)"
    } else {
        # PS 5.1 doesn't escape embedded double quotes for native argv — do it by hand
        $bodyArg = $body -replace '"', '\"'
        gh project item-create 1 --owner rorybot --title $card.Title --body $bodyArg | Out-Null
        if ($?) { Write-Host "created: $($card.Title)" } else { Write-Warning "FAILED: $($card.Title)"; exit 1 }
    }
}
Write-Host "done ($($cards.Count) cards parsed)"
