$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$homeDir  = $env:USERPROFILE
$claudeDir = "$homeDir\.claude"

# ── Skill ─────────────────────────────────────────────────────────────────────
Write-Host "Skill..."
$skillDir = "$claudeDir\skills\forge"
New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
Copy-Item "$root\skill\*" $skillDir -Recurse -Force

# ── Hooks ─────────────────────────────────────────────────────────────────────
Write-Host "Hooks..."
New-Item -ItemType Directory -Path "$claudeDir\hooks" -Force | Out-Null
Copy-Item "$root\hooks\*" "$claudeDir\hooks\" -Force

# ── Settings (merge idempotent) ───────────────────────────────────────────────
Write-Host "Settings..."
$sp = "$claudeDir\settings.json"
$s = if (Test-Path $sp) { Get-Content $sp -Raw -Encoding UTF8 | ConvertFrom-Json } else { [PSCustomObject]@{} }

# permissions.allow
if (-not ($s.PSObject.Properties.Name -contains "permissions")) {
    $s | Add-Member -NotePropertyName permissions -NotePropertyValue ([PSCustomObject]@{ allow = @() })
}
if (-not ($s.permissions.PSObject.Properties.Name -contains "allow")) {
    $s.permissions | Add-Member -NotePropertyName allow -NotePropertyValue @()
}
$rule = "Read($homeDir\.claude\skills\forge)"
$s.permissions.allow = @($s.permissions.allow | Where-Object { $_ -ne $rule }) + $rule

# hooks.PreCompact
if (-not ($s.PSObject.Properties.Name -contains "hooks")) {
    $s | Add-Member -NotePropertyName hooks -NotePropertyValue ([PSCustomObject]@{})
}
if (-not ($s.hooks.PSObject.Properties.Name -contains "PreCompact")) {
    $s.hooks | Add-Member -NotePropertyName PreCompact -NotePropertyValue @()
}

$entries = @(
    @{ cmd = "bash ~/.claude/hooks/forge-precompact.sh";                          shell = "bash" },
    @{ cmd = "powershell -File $homeDir\.claude\hooks\forge-precompact.ps1"; shell = "powershell" }
)
foreach ($e in $entries) {
    $s.hooks.PreCompact = @($s.hooks.PreCompact | Where-Object {
        -not (@($_.hooks) | Where-Object { $_.command -eq $e.cmd })
    }) + [PSCustomObject]@{
        hooks = @([PSCustomObject]@{ type = "command"; command = $e.cmd; shell = $e.shell })
    }
}

$s | ConvertTo-Json -Depth 10 | Set-Content $sp -Encoding UTF8
Write-Host "Done."
