# Set GitHub Project #1 Status for a paper-weight issue, then print verification.
# Requires: gh auth with project scope  ->  gh auth refresh -s project
#
# Usage:
#   powershell -File scripts\set-card-status.ps1 -Issue 5 -Status "In progress"
#   powershell -File scripts\set-card-status.ps1 -Issue 2 -Status Done -CloseIssue
#
# Status names (exact): Backlog | Ready | In progress | In review | Done

param(
    [Parameter(Mandatory = $true)]
    [int]$Issue,

    [Parameter(Mandatory = $true)]
    [ValidateSet("Backlog", "Ready", "In progress", "In review", "Done")]
    [string]$Status,

    [switch]$CloseIssue,
    [switch]$ReopenIssue
)

$ErrorActionPreference = "Stop"
$Owner = "rorybot"
$ProjectNumber = 1
$ProjectId = "PVT_kwHOAcWVcc4BdhZ_"
$StatusFieldId = "PVTSSF_lAHOAcWVcc4BdhZ_zhYCXX4"
$Repo = "rorybot/paper-weight"

$OptionIds = @{
    "Backlog"     = "f75ad846"
    "Ready"       = "61e4505c"
    "In progress" = "47fc9ee4"
    "In review"   = "df73e18b"
    "Done"        = "98236657"
}

$itemsJson = gh project item-list $ProjectNumber --owner $Owner --limit 50 --format json
if (-not $?) { throw "gh project item-list failed" }

$items = $itemsJson | ConvertFrom-Json
$item = $items.items | Where-Object { $_.content.number -eq $Issue } | Select-Object -First 1
if (-not $item) {
    throw "Issue #$Issue is not on project $ProjectNumber. Add it first: gh project item-add $ProjectNumber --owner $Owner --url https://github.com/$Repo/issues/$Issue"
}

$optionId = $OptionIds[$Status]
Write-Host "Issue #$Issue  item=$($item.id)  $($item.status) -> $Status"

gh project item-edit `
    --id $item.id `
    --project-id $ProjectId `
    --field-id $StatusFieldId `
    --single-select-option-id $optionId | Out-Null
if (-not $?) { throw "gh project item-edit failed" }

if ($CloseIssue -or $Status -eq "Done") {
    gh issue close $Issue --repo $Repo 2>$null
    Write-Host "Issue #$Issue closed (or already closed)."
}
if ($ReopenIssue) {
    gh issue reopen $Issue --repo $Repo
    Write-Host "Issue #$Issue reopened."
}

$verify = gh project item-list $ProjectNumber --owner $Owner --limit 50 --format json | ConvertFrom-Json
$v = $verify.items | Where-Object { $_.content.number -eq $Issue } | Select-Object -First 1
Write-Host "Verified: #$Issue status=$($v.status) title=$($v.title)"

if ($v.status -ne $Status) {
    throw "Status mismatch after edit (wanted '$Status', got '$($v.status)')."
}

Write-Host "OK. Now update kanban/board.md + features/*/spec.md to match."
