<#
.SYNOPSIS
  Buduje paczkę instalacyjną RemoteAppTester dla Windows (i opcjonalnie APK na telefon).

.DESCRIPTION
  Wynik w host\build\release\:
    RemoteAppTester-windows-x64-<wersja>.zip   <- rozpakuj i uruchom install.cmd
    windows\                                <- to samo rozpakowane:
      install.cmd, uninstall.cmd, install.ps1, README.md, README.pl.md, SHA256SUMS
      RemoteAppTester\                          <- aplikacja okienkowa (RemoteAppTester.exe)
        cli\bin\rt.exe, remoteapptester.exe     <- narzędzie terminala dla agentów AI
      RemoteAppTester-android-<wersja>.apk      <- z -WithAndroid
  Wymaga: Flutter (Windows desktop), Visual Studio C++ i trybu dewelopera Windows
  (dowiązania symboliczne wtyczek) — tylko na komputerze, który buduje paczkę.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tool\build_release.ps1 -WithAndroid
#>
[CmdletBinding()]
param(
    [switch]$WithAndroid
)
$ErrorActionPreference = 'Stop'
$hostDir = Split-Path $PSScriptRoot -Parent
$repoDir = Split-Path $hostDir -Parent
$desktopDir = Join-Path $repoDir 'desktop_app'

function Invoke-Checked($what, [scriptblock]$block) {
    & $block
    if ($LASTEXITCODE -ne 0) { throw "$what nie powiodło się (kod $LASTEXITCODE)." }
}

Push-Location $hostDir
try {
    $version = [regex]::Match((Get-Content 'lib\version.dart' -Raw), "hostVersion = '([^']+)'").Groups[1].Value
    $installerVersion = [regex]::Match((Get-Content 'deploy\windows\install.ps1' -Raw), "HostVersion = '([^']+)'").Groups[1].Value
    if (-not $version -or $version -ne $installerVersion) {
        throw "Wersja hosta ($version) różni się od HostVersion w install.ps1 ($installerVersion)."
    }
    # Aplikacje pokazują wersję w „O aplikacji”, a Android także przy instalacji — muszą się zgadzać.
    $versions = @{
        'desktop_app\pubspec.yaml' = [regex]::Match((Get-Content (Join-Path $desktopDir 'pubspec.yaml') -Raw), '(?m)^version:\s*([^+\s]+)').Groups[1].Value
        'android_app\pubspec.yaml' = [regex]::Match((Get-Content (Join-Path $repoDir 'android_app\pubspec.yaml') -Raw), '(?m)^version:\s*([^+\s]+)').Groups[1].Value
        'android_app\lib\app_version.dart' = [regex]::Match((Get-Content (Join-Path $repoDir 'android_app\lib\app_version.dart') -Raw), "appVersion = '([^']+)'").Groups[1].Value
    }
    foreach ($file in $versions.Keys) {
        if ($versions[$file] -ne $version) { throw "Wersja w $file ($($versions[$file])) różni się od wersji hosta ($version)." }
    }

    $release = Join-Path $hostDir 'build\release'
    $out = Join-Path $release 'windows'
    $app = Join-Path $out 'RemoteAppTester'
    if (Test-Path $out) { Remove-Item -Recurse -Force $out }
    New-Item -ItemType Directory -Force -Path $app | Out-Null

    Write-Host "1/3 Narzędzie terminala rt $version (z biblioteką SQLite)..."
    Invoke-Checked 'dart pub get' { dart pub get | Out-Null }
    $cliBuild = Join-Path $hostDir 'build\cli'
    if (Test-Path $cliBuild) { Remove-Item -Recurse -Force $cliBuild }
    Invoke-Checked 'Budowanie rt' { dart build cli -t bin\rt.dart -o $cliBuild | Out-Null }
    Copy-Item -Recurse (Join-Path $cliBuild 'bundle') (Join-Path $app 'cli')
    Copy-Item (Join-Path $app 'cli\bin\rt.exe') (Join-Path $app 'cli\bin\remoteapptester.exe')

    Write-Host '2/3 Aplikacja okienkowa RemoteAppTester.exe...'
    Push-Location $desktopDir
    try {
        Invoke-Checked 'flutter pub get' { flutter pub get | Out-Null }
        # Czysty katalog wyjściowy — bez bibliotek pozostałych po wcześniejszych buildach.
        $releaseDir = Join-Path $desktopDir 'build\windows\x64\runner\Release'
        if (Test-Path $releaseDir) { Remove-Item -Recurse -Force $releaseDir }
        flutter build windows --release
        if ($LASTEXITCODE -ne 0) {
            throw 'Budowanie aplikacji okienkowej nie powiodło się. Jeśli komunikat mówi o "symlink support", ' +
                'włącz tryb dewelopera Windows (Ustawienia → System → Dla deweloperów) i uruchom ponownie.'
        }
    } finally { Pop-Location }
    Copy-Item -Recurse (Join-Path $desktopDir 'build\windows\x64\runner\Release\*') $app

    if ($WithAndroid) {
        Write-Host '3/3 Aplikacja Android (release, klucz debug — wyłącznie do testów)...'
        Push-Location (Join-Path $repoDir 'android_app')
        try {
            Invoke-Checked 'Budowanie APK' { flutter build apk --release --target-platform android-arm64 }
        } finally { Pop-Location }
        Copy-Item (Join-Path $repoDir 'android_app\build\app\outputs\flutter-apk\app-release.apk') (Join-Path $out "RemoteAppTester-android-$version.apk")
    }

    Copy-Item deploy\windows\install.ps1, deploy\windows\install.cmd, deploy\windows\uninstall.cmd, deploy\windows\README.md, deploy\windows\README.pl.md $out

    # SHA256SUMS w formacie sha256sum — install.ps1 sprawdza każdy plik programu.
    $sums = Get-ChildItem -Recurse -File $app | ForEach-Object {
        $rel = $_.FullName.Substring($out.Length + 1).Replace('\', '/')
        "$((Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLowerInvariant())  $rel"
    }
    Get-ChildItem $out -File -Filter *.apk | ForEach-Object {
        $sums += "$((Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLowerInvariant())  $($_.Name)"
    }
    Set-Content -Path (Join-Path $out 'SHA256SUMS') -Value $sums -Encoding Ascii

    $zip = Join-Path $release "RemoteAppTester-windows-x64-$version.zip"
    if (Test-Path $zip) { Remove-Item -Force $zip }
    Compress-Archive -Path (Join-Path $out '*') -DestinationPath $zip
    $zipHash = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLowerInvariant()
    Set-Content -Path "$zip.sha256" -Value "$zipHash  $(Split-Path $zip -Leaf)" -Encoding Ascii

    Write-Host ''
    Write-Host "Gotowe: $zip ($([math]::Round((Get-Item $zip).Length / 1MB, 1)) MB)"
    Write-Host 'Instalacja: rozpakuj ZIP i uruchom install.cmd (bez uprawnień administratora).'
} finally {
    Pop-Location
}
