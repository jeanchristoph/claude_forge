$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$homeDir  = $env:USERPROFILE
$claudeDir = "$homeDir\.claude"

# ── Skill ─────────────────────────────────────────────────────────────────────
Write-Host "Skill..."
$skillDir = "$claudeDir\skills\forge"
New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
Copy-Item "$root\skill\*" $skillDir -Recurse -Force

# ── Hook ──────────────────────────────────────────────────────────────────────
Write-Host "Hook..."
$hookDir = "$claudeDir\hooks\forge"
New-Item -ItemType Directory -Path $hookDir -Force | Out-Null
Copy-Item "$root\hooks\ps1\forge-precompact.ps1" "$hookDir\" -Force

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
$drive          = $homeDir[0].ToString().ToLower()
$rest           = $homeDir.Substring(2).Replace('\', '/')
$rulePosix      = "Read(//$drive$rest/.claude/skills/forge/**)"
$ruleBackslash  = "Read($homeDir\.claude\skills\forge\**)"
$ruleFwdSlash   = "Read($($homeDir.Replace('\','/'))/.claude/skills/forge/**)"
$oldRule        = "Read($homeDir\.claude\skills\forge)"
$projectRules = @("Read(/.claude/**)", "Edit(/.claude/**)", "Write(/.claude/**)", "Bash(git branch:*)", "PowerShell(Get-ChildItem:*)")
$s.permissions.allow = @($s.permissions.allow | Where-Object {
    $_ -ne $rulePosix -and $_ -ne $ruleBackslash -and $_ -ne $ruleFwdSlash -and $_ -ne $oldRule -and $_ -notin $projectRules
}) + $rulePosix + $projectRules

# hooks.PreCompact — retire toutes les entrées forge (bash + ps1), ajoute uniquement ps1
if (-not ($s.PSObject.Properties.Name -contains "hooks")) {
    $s | Add-Member -NotePropertyName hooks -NotePropertyValue ([PSCustomObject]@{})
}
if (-not ($s.hooks.PSObject.Properties.Name -contains "PreCompact")) {
    $s.hooks | Add-Member -NotePropertyName PreCompact -NotePropertyValue @()
}

$forgePattern = "forge-precompact"
$s.hooks.PreCompact = @($s.hooks.PreCompact | Where-Object {
    -not (@($_.hooks) | Where-Object { $_.command -like "*$forgePattern*" })
})

$cmd = "powershell -File $homeDir\.claude\hooks\forge\forge-precompact.ps1"
$s.hooks.PreCompact = $s.hooks.PreCompact + [PSCustomObject]@{
    hooks = @([PSCustomObject]@{ type = "command"; command = $cmd; shell = "powershell" })
}

$s | ConvertTo-Json -Depth 10 | Set-Content $sp -Encoding UTF8
Write-Host "Done."
