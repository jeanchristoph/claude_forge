$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$homeDir  = $env:USERPROFILE
$claudeDir = "$homeDir\.claude"

# ── Skills ────────────────────────────────────────────────────────────────────
# Un dossier sous skills/ = un skill installé, sous son propre nom.
# Ajouter un skill n'exige aucune modification de ce script.
Write-Host "Skills..."
$skillNames = @()
foreach ($d in Get-ChildItem "$root\skills" -Directory) {
    $skillNames += $d.Name
    $dest = "$claudeDir\skills\$($d.Name)"
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    Copy-Item "$($d.FullName)\*" $dest -Recurse -Force
    Write-Host "  $($d.Name)"
}

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
$drive   = $homeDir[0].ToString().ToLower()
$rest    = $homeDir.Substring(2).Replace('\', '/')
$homeFwd = $homeDir.Replace('\', '/')

# Une règle POSIX par skill. Les autres formes de chemin sont purgées à chaque install.
$skillRules = @()
$staleRules = @()
foreach ($n in $skillNames) {
    $skillRules += "Read(//$drive$rest/.claude/skills/$n/**)"
    $staleRules += "Read($homeDir\.claude\skills\$n\**)"
    $staleRules += "Read($homeFwd/.claude/skills/$n/**)"
    $staleRules += "Read($homeDir\.claude\skills\$n)"
}
$projectRules = @("Read(/.forge/**)", "Edit(/.forge/**)",'Bash(bash -c "git branch --show-current*)')
$s.permissions.allow = @($s.permissions.allow | Where-Object {
    $_ -notin $skillRules -and $_ -notin $staleRules -and $_ -notin $projectRules
}) + $skillRules + $projectRules

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
