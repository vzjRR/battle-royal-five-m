# EVENT STUDIO - update a local test server from GitHub (Windows).
#
#   update_server.bat   update once
#   watch_server.bat    keep watching: every minute, apply any new change automatically
#
# What it does: pulls the latest version of the development branch into this folder (a git clone), copies
# event_studio into your server's resources folder, and, if rcon is set up, restarts the resource on the running
# server (`refresh` + `ensure event_studio`). The first run asks for your server paths and remembers them in
# update_server.settings.json next to this script (not uploaded anywhere).
#
# For test servers only. Customers get updates from the Cfx Portal, never from this script.

param(
    [switch]$Watch,          # keep checking for new versions
    [int]$Every = 60,        # seconds between checks in watch mode
    [switch]$KeepConfig,     # do not overwrite the server's config folder (keep your own config edits)
    [switch]$Setup           # ask for the settings again
)

$ErrorActionPreference = 'Continue'   # git prints progress on stderr; exit codes are checked instead
$Branch = 'claude/event-studio-fivem-x11r93'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $Here '..\..')).Path
$SettingsFile = Join-Path $Here 'update_server.settings.json'

function Say($text, $color = 'Gray') { Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $text) -ForegroundColor $color }

function Test-Git {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Say 'Git is not installed. Install "Git for Windows" from https://git-scm.com/download/win and run this again.' 'Red'
        exit 1
    }
    if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot '.git'))) {
        Say "This script must run from a git clone of the project (expected one at $RepoRoot). See tools\windows\README.md." 'Red'
        exit 1
    }
}

function Get-Settings {
    if ((Test-Path -LiteralPath $SettingsFile) -and -not $Setup) {
        return Get-Content -LiteralPath $SettingsFile -Raw | ConvertFrom-Json
    }
    Write-Host ''
    Write-Host 'First run: tell me where your server keeps Event Studio.' -ForegroundColor Cyan
    Write-Host 'Example: C:\FiveMServer\txData\QBCore_7D4232.base\resources\[local]\event_studio'
    $target = Read-Host 'Full path of the event_studio folder on your server'
    $target = $target.Trim('"', ' ')
    Write-Host ''
    Write-Host 'Optional: automatic restart of the resource on the running server.' -ForegroundColor Cyan
    Write-Host 'Add this line to server.cfg (pick your own password) and restart the server once:'
    Write-Host '    rcon_password "choose-a-long-password"' -ForegroundColor Yellow
    $rcon = Read-Host 'rcon password (leave empty to restart the resource yourself)'
    $port = Read-Host 'Server port (Enter = 30120)'
    if (-not $port) { $port = '30120' }
    $s = [pscustomobject]@{ target = $target; rconPassword = $rcon; port = [int]$port }
    $s | ConvertTo-Json | Set-Content -LiteralPath $SettingsFile -Encoding UTF8
    Say "Settings saved in $SettingsFile" 'Green'
    return $s
}

function Send-Rcon($settings, $command) {
    if (-not $settings.rconPassword) { return $false }
    $udp = New-Object System.Net.Sockets.UdpClient
    try {
        $udp.Client.ReceiveTimeout = 3000
        [byte[]]$payload = [byte[]](0xFF, 0xFF, 0xFF, 0xFF) + [System.Text.Encoding]::ASCII.GetBytes("rcon $($settings.rconPassword) $command")
        [void]$udp.Send($payload, $payload.Length, '127.0.0.1', [int]$settings.port)
        $ep = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
        $reply = $udp.Receive([ref]$ep)
        $text = [System.Text.Encoding]::ASCII.GetString($reply, 4, $reply.Length - 4)
        if ($text -match 'Invalid password') { Say 'rcon: wrong password (check rcon_password in server.cfg).' 'Red'; return $false }
        return $true
    } catch {
        Say "rcon: no answer from the server on port $($settings.port) (is it running, and is rcon_password set?)." 'Yellow'
        return $false
    } finally {
        $udp.Close()
    }
}

function Update-Source {
    git -C $RepoRoot fetch --quiet origin $Branch
    if ($LASTEXITCODE -ne 0) { throw 'could not reach GitHub (internet, or sign in to GitHub when Git asks)' }
    $local = (git -C $RepoRoot rev-parse HEAD).Trim()
    $remote = (git -C $RepoRoot rev-parse "origin/$Branch").Trim()
    if ($local -ne $remote) {
        # the clone is only a mirror: always take GitHub's version
        git -C $RepoRoot checkout --quiet --force -B $Branch "origin/$Branch"
        if ($LASTEXITCODE -ne 0) { throw 'could not switch to the new version' }
    }
    return @{ changed = ($local -ne $remote); commit = $remote; subject = (git -C $RepoRoot log -1 --format=%s).Trim() }
}

function Deploy($settings) {
    $source = Join-Path $RepoRoot 'event_studio'
    $target = $settings.target
    # -LiteralPath everywhere: folder names like [local] are not wildcards
    if (-not (Test-Path -LiteralPath (Split-Path -Parent $target))) {
        Say "The folder above $target does not exist. Run update_server.bat -Setup to fix the path." 'Red'
        exit 1
    }
    $copyArgs = @($source, $target, '/MIR', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/R:2', '/W:1')
    if ($KeepConfig -and (Test-Path -LiteralPath (Join-Path $target 'config'))) { $copyArgs += @('/XD', (Join-Path $target 'config')) }
    & robocopy @copyArgs | Out-Null
    if ($LASTEXITCODE -ge 8) { Say "Copy failed (robocopy code $LASTEXITCODE). Is a file open or locked?" 'Red'; exit 1 }
    Say "Copied to $target" 'Green'

    if ((Send-Rcon $settings 'refresh') -and (Send-Rcon $settings 'ensure event_studio')) {
        Say 'Resource restarted on the server (ensure event_studio). Reconnect in game if the UI looks stale.' 'Green'
    } else {
        Say 'Now type  ensure event_studio  in the txAdmin live console (or restart the server).' 'Yellow'
    }
}

Test-Git
$settings = Get-Settings

if (-not $Watch) {
    try { $r = Update-Source } catch { Say "Update failed: $($_.Exception.Message)" 'Red'; exit 1 }
    Say ("Version: {0} ({1})" -f $r.commit.Substring(0, 7), $r.subject) 'Cyan'
    Deploy $settings
    exit 0
}

Say "Watching $Branch every $Every s. Leave this window open; press Ctrl+C to stop." 'Cyan'
$first = $true
while ($true) {
    try {
        $r = Update-Source
        if ($r.changed -or $first) {
            Say ("New version: {0} ({1})" -f $r.commit.Substring(0, 7), $r.subject) 'Cyan'
            Deploy $settings
        }
        $first = $false
    } catch {
        Say "Check failed: $($_.Exception.Message). Trying again later." 'Yellow'
    }
    Start-Sleep -Seconds $Every
}
