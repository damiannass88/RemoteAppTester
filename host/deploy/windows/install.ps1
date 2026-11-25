<#
.SYNOPSIS
  Instalator RemoteAppTester na Windows 10/11 (bez uprawnień administratora).

.DESCRIPTION
  Instaluje dla bieżącego użytkownika:
    - aplikację okienkową: %LOCALAPPDATA%\Programs\RemoteAppTester\RemoteAppTester.exe
      (projekty, budowanie w tle, telefony, zasobnik systemowy)
    - narzędzie terminala dla agentów AI: "rt" / "remoteapptester" (w PATH użytkownika)
    - skróty w menu Start i na pulpicie, autostart przy logowaniu (schowana w zasobniku)
    - opcjonalnie regułę zapory (wymaga zgody administratora — okno UAC)
  Dane (zaszyfrowana baza projektów, sparowane telefony, logi): %LOCALAPPDATA%\RemoteAppTester.
  Ponowne uruchomienie = aktualizacja (dane zostają).

  Bezpieczeństwo (docs/SECURITY.md): sumy SHA-256 plików programu sprawdzane przed
  instalacją; serwer dla telefonów nasłuchuje wyłącznie na adresie Tailscale; reguła zapory
  dotyczy tylko RemoteAppTester.exe, tego portu i adresów tailnetu (100.64.0.0/10); sekrety
  i klucz bazy w Windows DPAPI.

.EXAMPLE
  .\install.cmd
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall [-Purge]
#>
[CmdletBinding()]
param(
    [int]$Port = 47051,     # poza zakresem 49152–65535, który Windows rezerwuje przy starcie
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Programs\RemoteAppTester'),
    [string]$DataDir = (Join-Path $env:LOCALAPPDATA 'RemoteAppTester'),
    [string]$Source = '',
    [switch]$NoAutostart,
    [switch]$NoPath,        # bez PATH i bez zmiennej REMOTEAPPTESTER_HOME
    [switch]$NoShortcuts,
    [switch]$NoFirewall,
    [switch]$NoLaunch,
    [switch]$Uninstall,
    [switch]$Purge
)

$ErrorActionPreference = 'Stop'
$HostVersion = '0.6.6'
$LegacyTaskName = 'RemoteTester'
$LegacyInstallDir = Join-Path $env:LOCALAPPDATA 'Programs\RemoteTester'
$LegacyDataDir = Join-Path $env:LOCALAPPDATA 'RemoteTester'
$RunKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$FirewallRuleName = 'RemoteAppTester (Tailscale only)'
# Podgląd aplikacji web z telefonu (preview_port … +preview_port_count-1 w host-config.yaml).
$PreviewPorts = '47100-47109'
$CliDir = Join-Path $InstallDir 'cli\bin'
$AppExe = Join-Path $InstallDir 'RemoteAppTester.exe'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

function Step($text) { Write-Host ''; Write-Host "==> $text" -ForegroundColor White }
function Ok($text) { Write-Host "  [OK] $text" -ForegroundColor Green }
function Warn($text) { Write-Host "  [!]  $text" -ForegroundColor Yellow }
function Fail($text) { Write-Host "  [X]  $text" -ForegroundColor Red; exit 1 }

function Ask-Yes($question) {
    if (-not [Environment]::UserInteractive) { return $false }
    try { $answer = Read-Host "  $question [T/n]" } catch { return $false }
    return -not ($answer -match '^(n|nie|no)$')
}

# PATH użytkownika czytany i zapisywany bezpośrednio w rejestrze, BEZ rozwijania zmiennych
# i jako REG_EXPAND_SZ — [Environment]::SetEnvironmentVariable zapisałby REG_SZ i wpisy
# typu %USERPROFILE%\bin przestałyby działać.
function Get-UserPath {
    $key = Get-Item 'HKCU:\Environment'
    $value = $key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    if ($null -eq $value) { return '' }
    return [string]$value
}

function Set-UserPath($value) {
    New-ItemProperty -Path 'HKCU:\Environment' -Name 'Path' -Value $value -PropertyType ExpandString -Force | Out-Null
    # Powiadomienie Eksploratora, żeby nowe okna terminala widziały zmianę bez wylogowania.
    $sig = '[DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, UIntPtr w, string l, uint f, uint t, out UIntPtr r);'
    try {
        $native = Add-Type -MemberDefinition $sig -Name 'RtEnvNotify' -Namespace 'RemoteAppTester' -PassThru
        $result = [UIntPtr]::Zero
        [void]$native::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$result)
    } catch { }
}

function Remove-FromUserPath($dir) {
    $userPath = Get-UserPath
    $parts = @($userPath -split ';' | Where-Object { $_ -and ($_.TrimEnd('\') -ine $dir.TrimEnd('\')) })
    if (($parts -join ';') -ne $userPath.Trim(';')) { Set-UserPath ($parts -join ';'); return $true }
    return $false
}

function Stop-RemoteAppTester {
    # Starsza wersja (0.3) startowała przez Harmonogram zadań — usuwamy to zadanie, ale
    # tylko jeśli uruchamia program z TEGO katalogu instalacji.
    $legacy = Get-ScheduledTask -TaskName $LegacyTaskName -ErrorAction SilentlyContinue
    if ($legacy -and (($legacy.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join ' ') -like "*$InstallDir*") {
        Stop-ScheduledTask -TaskName $LegacyTaskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $LegacyTaskName -Confirm:$false
    }
    $root = $InstallDir.TrimEnd('\') + '\'
    Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -and $_.Path.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) } |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
}

# Wersje sprzed zmiany nazwy (RemoteTester): usuwa program, autostart i skróty, dane przenosi.
function Remove-LegacyInstall {
    Get-Process -Name 'RemoteTester','remotetester' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
    # 0.3 startowała z Harmonogramu zadań (pętla co 10 s) — bez programu sypie błędami po każdym logowaniu.
    $task = Get-ScheduledTask -TaskName $LegacyTaskName -ErrorAction SilentlyContinue
    if ($task -and (($task.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join ' ') -like "*$LegacyInstallDir\*") {
        Stop-ScheduledTask -TaskName $LegacyTaskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $LegacyTaskName -Confirm:$false
        Ok 'Usunięto zadanie autostartu poprzedniej wersji (Harmonogram zadań).'
    }
    $run = (Get-ItemProperty -Path $RunKey -ErrorAction SilentlyContinue).RemoteTester
    if ($run) { Remove-ItemProperty -Path $RunKey -Name 'RemoteTester' -ErrorAction SilentlyContinue; Ok 'Usunięto autostart poprzedniej wersji.' }
    $shell = New-Object -ComObject WScript.Shell
    foreach ($link in @((Join-Path ([Environment]::GetFolderPath('Programs')) 'RemoteTester.lnk'), (Join-Path ([Environment]::GetFolderPath('Desktop')) 'RemoteTester.lnk'))) {
        if ((Test-Path $link) -and $shell.CreateShortcut($link).TargetPath -like "$LegacyInstallDir*") { Remove-Item -Force $link }
    }
    if (Test-Path $LegacyInstallDir) {
        Remove-FromUserPath (Join-Path $LegacyInstallDir 'cli\bin')
        Remove-FromUserPath (Join-Path $LegacyInstallDir 'cli')
        Remove-Item -Recurse -Force $LegacyInstallDir -ErrorAction SilentlyContinue
        Ok "Usunięto poprzednią wersję ($LegacyInstallDir)."
    }
    if ([Environment]::GetEnvironmentVariable('REMOTETESTER_HOME', 'User') -eq $LegacyDataDir) { [Environment]::SetEnvironmentVariable('REMOTETESTER_HOME', $null, 'User') }
    if ((Test-Path $LegacyDataDir) -and -not (Test-Path $DataDir)) {
        Rename-Item -Path $LegacyDataDir -NewName (Split-Path $DataDir -Leaf)
        Ok "Dane przeniesione do $DataDir (projekty i sparowania zostają)."
    }
}

function Find-Tailscale {
    $cmd = Get-Command tailscale.exe -ErrorAction SilentlyContinue
    if ($null -ne $cmd) { return $cmd.Source }
    $default = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
    if (Test-Path $default) { return $default }
    return $null
}

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function New-Shortcut($path, $target, $arguments) {
    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut($path)
    $link.TargetPath = $target
    $link.Arguments = $arguments
    $link.WorkingDirectory = Split-Path $target
    $link.Description = 'RemoteAppTester — buduje aplikacje i instaluje je na telefonie testowym'
    $link.Save()
}

$StartMenuLink = Join-Path ([Environment]::GetFolderPath('Programs')) 'RemoteAppTester.lnk'
$DesktopLink = Join-Path ([Environment]::GetFolderPath('Desktop')) 'RemoteAppTester.lnk'

# ------------------------------------------------------------------ deinstalacja
if ($Uninstall) {
    Step 'Usuwanie RemoteAppTester'
    Stop-RemoteAppTester
    # Autostart i skróty usuwamy tylko, jeśli wskazują na TEN katalog instalacji.
    $run = (Get-ItemProperty -Path $RunKey -ErrorAction SilentlyContinue).RemoteAppTester
    if ($run -and $run -like "*$InstallDir*") { Remove-ItemProperty -Path $RunKey -Name 'RemoteAppTester'; Ok 'Usunięto autostart.' }
    $shell = New-Object -ComObject WScript.Shell
    foreach ($link in @($StartMenuLink, $DesktopLink)) {
        if ((Test-Path $link) -and $shell.CreateShortcut($link).TargetPath -like "$InstallDir*") { Remove-Item -Force $link; Ok "Usunięto skrót $link" }
    }
    if (Test-Path $InstallDir) { Remove-Item -Recurse -Force $InstallDir; Ok "Usunięto $InstallDir" }
    if (Remove-FromUserPath $CliDir) { Ok 'Usunięto "rt" z PATH.' }
    if ([Environment]::GetEnvironmentVariable('REMOTEAPPTESTER_HOME', 'User') -ieq $DataDir) {
        [Environment]::SetEnvironmentVariable('REMOTEAPPTESTER_HOME', $null, 'User')
    }
    if ($Purge) {
        if (Test-Path $DataDir) { Remove-Item -Recurse -Force $DataDir; Ok "Usunięto dane, projekty RemoteAppTester i sparowania ($DataDir)." }
    } else {
        Warn "Dane (baza projektów, sparowane telefony) zostały w $DataDir (usuń je: -Uninstall -Purge)."
    }
    if (Get-NetFirewallRule -DisplayName $FirewallRuleName -ErrorAction SilentlyContinue) {
        Warn "Reguła zapory '$FirewallRuleName' została. Usuń ją jako administrator:"
        Warn "  Remove-NetFirewallRule -DisplayName '$FirewallRuleName'"
    }
    Warn 'Foldery projektów i pliki REMOTEAPPTESTER.md zostają nietknięte. Tailscale to osobny program.'
    exit 0
}

# ------------------------------------------------------------------ system
Step "RemoteAppTester $HostVersion — instalacja dla użytkownika $env:USERNAME"
if (-not [Environment]::Is64BitOperatingSystem) { Fail 'Wymagany 64-bitowy Windows.' }
if ([Environment]::OSVersion.Version.Major -lt 10) { Fail 'Wymagany Windows 10 lub 11.' }
Ok "Windows $([Environment]::OSVersion.Version)"
if (Test-Admin) {
    Warn 'Uruchomiono jako administrator — program i tak zostanie zainstalowany dla bieżącego użytkownika (nigdy jako usługa SYSTEM).'
}

# ------------------------------------------------------------------ pliki programu
Step 'Program'
if (-not $Source) { $Source = Join-Path $PSScriptRoot 'RemoteAppTester' }
if (-not (Test-Path (Join-Path $Source 'RemoteAppTester.exe'))) { Fail "Nie znaleziono programu w $Source (rozpakuj całe archiwum ZIP)." }
$manifest = Join-Path (Split-Path $Source) 'SHA256SUMS'
if (Test-Path $manifest) {
    $bad = @()
    foreach ($line in Get-Content $manifest) {
        if ($line -notmatch '^([0-9a-f]{64})\s+\*?(.+)$') { continue }
        $file = Join-Path (Split-Path $Source) $Matches[2]
        if (-not (Test-Path $file) -or (Get-FileHash -Algorithm SHA256 $file).Hash.ToLowerInvariant() -ne $Matches[1]) {
            $bad += $Matches[2]
        }
    }
    if ($bad.Count -gt 0) { Fail "Sumy SHA-256 się nie zgadzają ($($bad -join ', ')) — przerywam (pliki mogły zostać podmienione)." }
    Ok 'Sumy kontrolne zgodne.'
} else {
    Warn 'Brak pliku SHA256SUMS — pomijam weryfikację (tylko do testów).'
}

Stop-RemoteAppTester
# Tylko przy instalacji w domyślne miejsca: katalogi podane ręcznie (np. test) nie ruszają starej wersji.
if (($InstallDir -eq (Join-Path $env:LOCALAPPDATA 'Programs\RemoteAppTester')) -and ($DataDir -eq (Join-Path $env:LOCALAPPDATA 'RemoteAppTester'))) { Remove-LegacyInstall }
if (Test-Path $InstallDir) { Remove-Item -Recurse -Force $InstallDir }
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item -Recurse -Force (Join-Path $Source '*') $InstallDir
# Pliki z internetu (Mark of the Web) — inaczej SmartScreen blokuje każde uruchomienie.
Get-ChildItem -Recurse -File $InstallDir | Unblock-File -ErrorAction SilentlyContinue
Ok "Zainstalowano: $AppExe (+ rt w $CliDir)"

New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
if (-not $NoPath) {
    [Environment]::SetEnvironmentVariable('REMOTEAPPTESTER_HOME', $DataDir, 'User')
    $userPath = Get-UserPath
    $present = ($userPath -split ';') | Where-Object { $_.TrimEnd('\') -ieq $CliDir.TrimEnd('\') }
    if (-not $present) {
        # Starsza wersja dodawała katalog programu — zamieniamy go na katalog rt.
        Remove-FromUserPath $InstallDir | Out-Null
        $userPath = Get-UserPath
        $newPath = if ($userPath) { "$($userPath.TrimEnd(';'));$CliDir" } else { $CliDir }
        Set-UserPath $newPath
        Ok 'Dodano "rt" i "remoteapptester" do PATH (działa w nowych oknach terminala).'
    } else {
        Ok 'PATH już zawiera RemoteAppTester.'
    }
}

# ------------------------------------------------------------------ konfiguracja
Step 'Konfiguracja'
$env:REMOTEAPPTESTER_HOME = $DataDir
$rt = Join-Path $CliDir 'rt.exe'
& $rt --home $DataDir init --projects-root (Join-Path $env:USERPROFILE 'RemoteAppTesterProjects') --port $Port
if ($LASTEXITCODE -ne 0) { Fail 'Nie udało się utworzyć konfiguracji.' }
Ok "Dane: $DataDir"

# ------------------------------------------------------------------ skróty i autostart
if (-not $NoShortcuts) {
    New-Shortcut $StartMenuLink $AppExe ''
    New-Shortcut $DesktopLink $AppExe ''
    Ok 'Skróty: menu Start i pulpit.'
}
if (-not $NoAutostart) {
    New-ItemProperty -Path $RunKey -Name 'RemoteAppTester' -Value "`"$AppExe`" --minimized" -PropertyType String -Force | Out-Null
    Ok 'Autostart przy logowaniu (schowany w zasobniku). Wyłączysz go w aplikacji: Ustawienia.'
}

# ------------------------------------------------------------------ narzędzia
Step 'Narzędzia'
$tailscale = Find-Tailscale
if ($null -eq $tailscale) {
    Warn 'Brak Tailscale — bez niego telefon nie połączy się z komputerem.'
    if ((Get-Command winget -ErrorAction SilentlyContinue) -and (Ask-Yes 'Zainstalować Tailscale teraz (winget)?')) {
        winget install --id Tailscale.Tailscale -e --accept-source-agreements --accept-package-agreements
    } else {
        Warn 'Pobierz: https://tailscale.com/download/windows i zaloguj się tym samym kontem co na telefonie.'
    }
} else {
    $ip = & $tailscale ip -4 2>$null | Select-Object -First 1
    if ($LASTEXITCODE -eq 0 -and $ip) { Ok "Tailscale połączony: $ip" }
    else { Warn 'Tailscale zainstalowany, ale niepołączony — zaloguj się w aplikacji Tailscale (ikona w zasobniku).' }
}
if (Get-Command flutter -ErrorAction SilentlyContinue) { Ok 'Flutter dostępny.' }
else { Warn 'Brak Fluttera w PATH — projekty Flutter nie zbudują się (https://docs.flutter.dev/get-started/install/windows).' }

# ------------------------------------------------------------------ zapora
if (-not $NoFirewall) {
    Step 'Zapora Windows'
    $existing = Get-NetFirewallRule -DisplayName $FirewallRuleName -ErrorAction SilentlyContinue
    $ruleCmd = "Remove-NetFirewallRule -DisplayName '$FirewallRuleName' -ErrorAction SilentlyContinue; " +
        "New-NetFirewallRule -DisplayName '$FirewallRuleName' -Direction Inbound -Protocol TCP " +
        "-LocalPort $Port,$PreviewPorts -RemoteAddress 100.64.0.0/10 -Program '$AppExe' -Action Allow -Profile Any -Enabled True"
    $current = $null; $currentPort = $null
    if ($null -ne $existing) {
        $current = ($existing | Get-NetFirewallApplicationFilter).Program
        $currentPort = ($existing | Get-NetFirewallPortFilter).LocalPort
    }
    # Reguła wersji 0.3 (RemoteTester) wskazuje nieistniejący już program — nieszkodliwa, ale zbędna.
    $legacyRule = 'RemoteTester (Tailscale only)'
    $hasLegacyRule = $null -ne (Get-NetFirewallRule -DisplayName $legacyRule -ErrorAction SilentlyContinue)
    $legacyCmd = "Remove-NetFirewallRule -DisplayName '$legacyRule' -ErrorAction SilentlyContinue"
    if ($hasLegacyRule) { $ruleCmd = "$legacyCmd; $ruleCmd" }
    if (($current -ieq $AppExe) -and ("$currentPort" -eq "$Port $PreviewPorts")) {
        Ok 'Reguła już istnieje.'
        if ($hasLegacyRule) {
            Warn "Została zbędna reguła poprzedniej wersji „$legacyRule” (wskazuje nieistniejący program)."
            if (Test-Admin) {
                Invoke-Expression $legacyCmd | Out-Null
                Ok 'Usunięto starą regułę zapory.'
            } elseif (Ask-Yes 'Usunąć ją teraz (Windows poprosi o zgodę administratora)?') {
                $p = Start-Process powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList '-NoProfile', '-Command', $legacyCmd
                if ($p.ExitCode -eq 0) { Ok 'Usunięto starą regułę zapory.' } else { Warn 'Nie udało się usunąć starej reguły.' }
            } else {
                Warn "Usuniesz ją później w PowerShell jako administrator: $legacyCmd"
            }
        }
    } else {
        Warn 'Windows domyślnie blokuje połączenia od telefonu. Potrzebna reguła — tylko RemoteAppTester.exe, ten port i adresy Tailscale.'
        if (Test-Admin) {
            Invoke-Expression $ruleCmd | Out-Null
            Ok 'Dodano regułę zapory.'
        } elseif (Ask-Yes 'Dodać regułę teraz (Windows poprosi o zgodę administratora)?') {
            $p = Start-Process powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList '-NoProfile', '-Command', $ruleCmd
            if ($p.ExitCode -eq 0) { Ok 'Dodano regułę zapory.' } else { Warn 'Nie udało się dodać reguły.' }
        } else {
            Warn 'Dodaj ją później w PowerShell jako administrator:'
            Warn "  $ruleCmd"
        }
    }
}

# ------------------------------------------------------------------ start
Step 'Gotowe'
if (-not $NoLaunch) {
    Start-Process -FilePath $AppExe
    Ok 'Uruchomiono RemoteAppTester. Telefon sparujesz w aplikacji: Telefony → Sparuj telefon.'
}
Write-Host '  Projekty dodajesz w aplikacji (przycisk „+”) albo z telefonu („Nowy projekt”). Agenci AI w folderze projektu: rt sg -m "co zmieniono" --build'
Write-Host '  Telefon nie łączy się? Ustaw na nim „Bez ograniczeń” baterii dla RemoteAppTester i Tailscale; reguły Tailscale: Telefony → Generuj JSON dla Tailscale.'
Write-Host "  Odinstalowanie: uninstall.cmd (dane zostają) albo uninstall.cmd -Purge"
