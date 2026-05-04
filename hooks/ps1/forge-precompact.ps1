$branch = git branch --show-current 2>$null
if (-not $branch) { exit 0 }

$planPath = ".claude\branch\$branch\plan.md"
if (-not (Test-Path $planPath)) { exit 0 }

$content = Get-Content $planPath -Raw -Encoding UTF8

@{
    hookSpecificOutput = @{
        hookEventName     = "PreCompact"
        additionalContext = "[FORGE STATE]`n$content"
    }
} | ConvertTo-Json -Compress | Write-Output
