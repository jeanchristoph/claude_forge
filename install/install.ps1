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

# ── Install record ────────────────────────────────────────────────────────────
# Version installée et dépôt d'origine, lus par skills/forge/scripts/update.sh.
# Installation hors git → version et dépôt nuls : la mise à jour sera proposée au premier contrôle.
Write-Host "Install record..."

# Sortie git, ou $null si git est absent ou échoue ; « Stop » ne doit pas transformer stderr en erreur fatale.
function Read-GitValue([string[]] $arguments) {
    $ErrorActionPreference = "Continue"
    try { $value = & git -C $root @arguments 2>$null } catch { return $null }
    if ($LASTEXITCODE -ne 0 -or -not $value) { return $null }
    return "$value".Trim()
}

$installedVersion = Read-GitValue @("describe", "--tags", "--abbrev=0", "--match", "v[0-9]*")
$record = [ordered]@{
    version    = $installedVersion
    repository = Read-GitValue @("remote", "get-url", "origin")
    last_check = if ($installedVersion) { [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() } else { 0 }
    latest     = $installedVersion
}
$recordJson = ([PSCustomObject]$record | ConvertTo-Json -Compress) + "`n"
[IO.File]::WriteAllText("$claudeDir\skills\forge\install.json", $recordJson, (New-Object Text.UTF8Encoding $false))

# ── Ancien dossier de hooks ───────────────────────────────────────────────────
# Hooks livrés dans le skill (skills/forge/hooks/), copiés avec lui : l'ancien dossier ~/.claude/hooks/forge/ des
# installations précédentes est retiré — fichiers forge seulement, dossier supprimé s'il reste vide.
Write-Host "Legacy hook folder..."
$legacyHookDir = "$claudeDir\hooks\forge"
foreach ($legacyHook in @("$legacyHookDir\forge-precompact.sh", "$legacyHookDir\forge-precompact.ps1")) {
    if (Test-Path $legacyHook) { Remove-Item $legacyHook -Force }
}
if ((Test-Path $legacyHookDir) -and -not (Get-ChildItem $legacyHookDir -Force)) { Remove-Item $legacyHookDir -Force }

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
$staleRules += 'Bash(bash -c "git branch --show-current*)'
# Scripts du skill, sous les deux formes d'appel (chemin cité ou non) que SKILL.md autorise.
$scripts = "$homeFwd/.claude/skills/forge/scripts/"
$projectRules = @("Read(/.forge/**)", "Edit(/.forge/**)", "Bash(bash `"$scripts*)", "Bash(bash $scripts*)")
$s.permissions.allow = @($s.permissions.allow | Where-Object {
    $_ -notin $skillRules -and $_ -notin $staleRules -and $_ -notin $projectRules
}) + $skillRules + $projectRules

# Hook d'état forge : avant compaction, puis après compaction ou reprise de session.
# Retire toute entrée forge-precompact (bash ou ancienne ps1), puis ajoute l'entrée bash.
if (-not ($s.PSObject.Properties.Name -contains "hooks")) {
    $s | Add-Member -NotePropertyName hooks -NotePropertyValue ([PSCustomObject]@{})
}
$stateHook = [PSCustomObject]@{ type = "command"; command = "bash ~/.claude/skills/forge/hooks/forge-precompact.sh"; shell = "bash" }
$stateEvents = [ordered]@{ PreCompact = $null; SessionStart = "compact|resume" }
foreach ($stateEvent in $stateEvents.Keys) {
    if (-not ($s.hooks.PSObject.Properties.Name -contains $stateEvent)) {
        $s.hooks | Add-Member -NotePropertyName $stateEvent -NotePropertyValue @()
    }
    $groups = @($s.hooks.$stateEvent | Where-Object {
        -not (@($_.hooks) | Where-Object { $_.command -like "*forge-precompact*" })
    })
    $group = if ($stateEvents[$stateEvent]) {
        [PSCustomObject]@{ matcher = $stateEvents[$stateEvent]; hooks = @($stateHook) }
    } else {
        [PSCustomObject]@{ hooks = @($stateHook) }
    }
    $s.hooks.$stateEvent = $groups + $group
}

# Hook de mesure du temps : script bash du skill, lancé par Git Bash comme les autres scripts de forge.
# Retire toute entrée time-hook existante, puis l'ajoute à chaque événement écouté.
# Asynchrone : Claude Code ne l'attend pas ; l'heure est prise à son démarrage, l'agrégation trie le journal.
$timeHook = [PSCustomObject]@{ type = "command"; command = "bash ~/.claude/skills/forge/hooks/time-hook.sh"; shell = "bash"; async = $true }
$timeEvents = [ordered]@{
    UserPromptSubmit = $null; Stop = $null; SubagentStart = $null; SubagentStop = $null
    PreToolUse = "AskUserQuestion"; PostToolUse = "AskUserQuestion|Bash"
}
foreach ($timeEvent in $timeEvents.Keys) {
    if (-not ($s.hooks.PSObject.Properties.Name -contains $timeEvent)) {
        $s.hooks | Add-Member -NotePropertyName $timeEvent -NotePropertyValue @()
    }
    $groups = @($s.hooks.$timeEvent | Where-Object {
        -not (@($_.hooks) | Where-Object { $_.command -like "*time-hook.sh*" })
    })
    $group = if ($timeEvents[$timeEvent]) {
        [PSCustomObject]@{ matcher = $timeEvents[$timeEvent]; hooks = @($timeHook) }
    } else {
        [PSCustomObject]@{ hooks = @($timeHook) }
    }
    $s.hooks.$timeEvent = $groups + $group
}

# Hook de coche du plan : retire toute entrée plan-hook existante, puis l'ajoute après chaque écriture de fichier.
# Synchrone : il réécrit plan.md et renvoie au modèle le réel écrit ; hors plan forge, il sort aussitôt.
$planHook = [PSCustomObject]@{ type = "command"; command = "bash ~/.claude/skills/forge/hooks/plan-hook.sh"; shell = "bash" }
$planGroups = @($s.hooks.PostToolUse | Where-Object {
    -not (@($_.hooks) | Where-Object { $_.command -like "*plan-hook.sh*" })
})
$s.hooks.PostToolUse = $planGroups + [PSCustomObject]@{ matcher = "Edit|Write|MultiEdit"; hooks = @($planHook) }

# Sans BOM : install.sh et les autres lecteurs JSON le refusent.
[IO.File]::WriteAllText($sp, ($s | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding $false))
Write-Host "Done."
