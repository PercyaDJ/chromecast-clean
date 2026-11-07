# chromecast-clean.ps1 - Chromecast with Google TV 4K: CleanYourTV + ad-free YouTube (TizenTube Cobalt)
# Started by "Install - Installer.cmd" (double-click). Undo: "Restore - Restaurer.cmd".
# Messages follow the Windows display language (French or English). Force one with -Lang fr / -Lang en.
#
# Does on its own: Windows prerequisites, backup, debloat (cast and Google TV home kept),
# TizenTube Cobalt + Key Mapper (YouTube button), then turns debugging off.
# You only type the address and the 6-digit code shown on the TV.

param([switch]$Restore, [string]$Lang = '', [string]$Dir = (Join-Path $PSScriptRoot 'vendor\cleanyourtv'))
# Continue: under PowerShell 5.1, Stop turns any adb stderr output into a fatal error.
$ErrorActionPreference = 'Continue'
$OutputEncoding = New-Object System.Text.UTF8Encoding $false
if (-not $Lang) { $Lang = if ((Get-UICulture).Name -like 'fr*') { 'fr' } else { 'en' } }
$FR = $Lang -eq 'fr'
function T($fr, $en) { if ($FR) { $fr } else { $en } }

$List = 'examples\google-chromecast-gtv-4k\debloat-keep-cast.txt'
$StockHome = 'com.google.android.apps.tv.launcherx'
$SmartTube = 'com.teamsmart.videomanager.tv'
$TizenTube = 'io.gh.reisxd.tizentube.cobalt'
$KeyMapper = 'io.github.sds100.keymapper'
$KeyMapperSvc = 'io.github.sds100.keymapper/io.github.sds100.keymapper.system.accessibility.MyAccessibilityService'
$Issues = 'https://github.com/PercyaDJ/chromecast-clean/issues'
$Launcher = if ($Restore) { 'Restore - Restaurer.cmd' } else { 'Install - Installer.cmd' }

function Step($t) { Write-Host "`n=== $t" -ForegroundColor Cyan }
function Tv($c) { & $py -I tools\tv.py $c }
function RefreshPath { $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User') }
function Need($cmd, $id) {
    if (Get-Command $cmd -ErrorAction SilentlyContinue) { return }
    Write-Host (T "Installation de $id..." "Installing $id...")
    winget install -e --id $id --accept-source-agreements --accept-package-agreements | Out-Host
    RefreshPath
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        throw (T "$cmd introuvable apres installation : ferme cette fenetre et relance `"$Launcher`"." "$cmd not found after install: close this window and run `"$Launcher`" again.")
    }
}
function Mdns($type) {
    $o = (& $adb mdns services 2>$null) -join "`n"
    [regex]::Matches($o, "$type\S*\s+(\d+\.\d+\.\d+\.\d+:\d+)") | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
}
function Connected($h) { (& $adb connect $h 2>$null) -match 'connected' -and ((& $adb -s $h get-state 2>$null) -eq 'device') }

try {
    Step (T '1/6 Preparation du PC (automatique)' '1/6 Preparing the PC (automatic)')
    Need py  'Python.Python.3.12'
    # CleanYourTV's files ship in vendor\cleanyourtv (see VENDORED.md): nothing is cloned at run time.
    if (-not (Test-Path (Join-Path $Dir $List))) { throw (T "Fichiers CleanYourTV absents de $Dir : retelecharge le projet en entier." "CleanYourTV files missing from ${Dir}: download the whole project again.") }
    Set-Location $Dir
    $py = Join-Path $Dir 'tools\venv\Scripts\python.exe'
    if (-not (Test-Path $py)) { py -3 -m venv tools\venv }
    & $py -m pip install -q --disable-pip-version-check -r tools\requirements.txt
    if ($LASTEXITCODE -ne 0) { throw (T 'Installation des dependances Python echouee.' 'Installing the Python dependencies failed.') }
    # Google's current adb in the project folder: an older adb already on PATH may not know "pair".
    $adb = Join-Path $Dir 'platform-tools\adb.exe'
    if (-not (Test-Path $adb)) {
        Write-Host (T 'Telechargement de adb (Google platform-tools)...' 'Downloading adb (Google platform-tools)...')
        $zip = Join-Path $env:TEMP 'platform-tools.zip'
        Invoke-WebRequest -ErrorAction Stop 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip' -OutFile $zip
        Expand-Archive -Force $zip $Dir
    }
    if (-not (Test-Path $adb)) { throw (T 'adb introuvable apres telechargement.' 'adb not found after download.') }
    # Through cmd and nul: piped from PowerShell, the adb daemon inherits the pipe and the script never returns.
    cmd /c "taskkill /F /IM adb.exe >nul 2>&1"
    cmd /c "`"$adb`" start-server >nul 2>&1"

    Step (T '2/6 Connexion au Chromecast' '2/6 Connecting to the Chromecast')
    $tvHost = $null
    foreach ($h in (Mdns '_adb-tls-connect\._tcp')) { if (Connected $h) { $tvHost = $h; break } }
    if (-not $tvHost) {
        Write-Host ''
        Write-Host (T 'SUR LA TV : Options pour les developpeurs > Debogage sans fil >' 'ON THE TV: Developer options > Wireless debugging >') -ForegroundColor Yellow
        Write-Host (T '            "Associer un appareil avec un code d''association"' '           "Pair device with pairing code"') -ForegroundColor Yellow
        Write-Host (T 'La TV affiche un code a 6 chiffres et, juste dessous, une adresse du type 192.168.1.42:37123' 'The TV shows a 6-digit code and, right below it, an address like 192.168.1.42:37123')
        Write-Host ''
        $pair = (Read-Host (T 'Adresse affichee SOUS LE CODE (IP:port)' 'Address shown BELOW THE CODE (IP:port)')).Trim()
        $code = (Read-Host (T 'Code a 6 chiffres' '6-digit code')).Trim()
        $out = (& $adb pair $pair $code 2>&1) -join ' '
        Write-Host $out
        if ($out -notmatch 'Successfully paired') {
            throw (T "Appairage refuse ($out). Verifie l'adresse et le code (le code change a chaque ouverture de la fenetre), puis relance `"$Launcher`"." "Pairing refused ($out). Check the address and the code (the code changes every time the window opens), then run `"$Launcher`" again.")
        }
        Write-Host (T 'Appairage OK.' 'Paired.') -ForegroundColor Green
        $ip = $pair.Split(':')[0]
        foreach ($h in (Mdns '_adb-tls-connect\._tcp')) { if ($h.StartsWith("${ip}:") -and (Connected $h)) { $tvHost = $h } }
        if (-not $tvHost) {
            Write-Host ''
            Write-Host (T 'SUR LA TV : ferme la fenetre du code (Retour). L''ecran "Debogage sans fil" affiche' 'ON THE TV: close the code window (Back). The "Wireless debugging" screen shows') -ForegroundColor Yellow
            Write-Host (T '            "Adresse IP et port" avec un AUTRE port, du type 192.168.1.42:41567' '           "IP address & Port" with a DIFFERENT port, like 192.168.1.42:41567') -ForegroundColor Yellow
            $port = (Read-Host (T "Tape seulement ce nouveau port (le nombre apres ${ip}:)" "Type only this new port (the number after ${ip}:)")).Trim()
            $tvHost = "${ip}:$port"
            if (-not (Connected $tvHost)) {
                throw (T "Connexion impossible a $tvHost. Verifie le port sur l'ecran Debogage sans fil et relance `"$Launcher`"." "Cannot connect to $tvHost. Check the port on the Wireless debugging screen and run `"$Launcher`" again.")
            }
        }
    }
    $env:TV_ADB_BINARY = $adb
    $env:TV_HOST = $tvHost
    $probe = (& $py -I tools\tv.py --probe) -join "`n"
    if ($probe -notmatch 'sabrina') {
        Write-Host $probe
        throw (T 'Ce n''est pas un Chromecast with Google TV 4K (sabrina) : arret, rien n''a ete modifie.' 'This is not a Chromecast with Google TV 4K (sabrina): stopped, nothing was changed.')
    }
    Write-Host (T "Chromecast 4K trouve : $tvHost" "Chromecast 4K found: $tvHost") -ForegroundColor Green

    if ($Restore) {
        Step (T 'Annulation' 'Restore')
        & powershell -ExecutionPolicy Bypass -File tools\restore.ps1 $List -Stock $StockHome
        Tv "settings put secure enabled_accessibility_services ''" | Out-Null
        foreach ($p in @($KeyMapper, $TizenTube, $SmartTube)) { & $adb -s $tvHost uninstall $p 2>$null | Out-Null }
    } else {
        Step (T '3/6 Sauvegarde du Chromecast (automatique)' '3/6 Backing up the Chromecast (automatic)')
        $bk = Join-Path $Dir ('backup\chromecast-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        New-Item -ItemType Directory -Force $bk | Out-Null
        Tv 'pm list packages'    | Set-Content (Join-Path $bk 'packages.txt')
        Tv 'pm list packages -d' | Set-Content (Join-Path $bk 'disabled.txt')
        Tv 'getprop'             | Set-Content (Join-Path $bk 'getprop.txt')
        foreach ($ns in 'secure','global','system') { Tv "settings list $ns" | Set-Content (Join-Path $bk "settings-$ns.txt") }
        Write-Host $bk

        Step (T '4/6 Suppression des pubs et de la telemetrie Google TV (automatique)' '4/6 Disabling Google TV ads and telemetry (automatic)')
        & powershell -ExecutionPolicy Bypass -File tools\disable.ps1 $List
        if ($LASTEXITCODE -ne 0) { throw (T 'Le debloat a signale une erreur (voir ci-dessus).' 'The debloat reported an error (see above).') }

        Step (T '5/6 Installation de TizenTube Cobalt (YouTube sans pub) et Key Mapper (automatique)' '5/6 Installing TizenTube Cobalt (ad-free YouTube) and Key Mapper (automatic)')
        $h = @{ 'User-Agent' = 'chromecast-clean' }
        $abi = ((Tv 'getprop ro.product.cpu.abi') -join '').Trim()
        $want = if ($abi -like 'arm64*') { 'cobalt-arm64.apk' } else { 'cobalt-arm.apk' }
        $tt = (Invoke-RestMethod -ErrorAction Stop -Headers $h 'https://api.github.com/repos/reisxd/TizenTubeCobalt/releases/latest').assets |
              Where-Object { $_.name -eq $want } | Select-Object -First 1
        $km = (Invoke-RestMethod -ErrorAction Stop -Headers $h 'https://api.github.com/repos/keymapperorg/KeyMapper/releases/latest').assets |
              Where-Object { $_.name -like '*.apk' -and $_.name -notlike '*debug*' } |
              Sort-Object { if ($_.name -like '*foss*') { 0 } else { 1 } } | Select-Object -First 1
        if (-not $tt) { throw (T "APK TizenTube Cobalt ($want) introuvable sur le GitHub officiel." "TizenTube Cobalt APK ($want) not found on its official GitHub.") }
        if (-not $km) { throw (T 'APK Key Mapper introuvable sur le GitHub officiel.' 'Key Mapper APK not found on its official GitHub.') }
        foreach ($a in @($tt, $km)) {
            $apk = Join-Path $Dir "backup\$($a.name)"
            Write-Host (T "Telechargement $($a.name)" "Downloading $($a.name)")
            Invoke-WebRequest -ErrorAction Stop -Headers $h $a.browser_download_url -OutFile $apk
            Write-Host (T "Installation $($a.name)" "Installing $($a.name)")
            & $adb -s $tvHost install -r $apk | Out-Host
            if ($LASTEXITCODE -ne 0) { throw (T "Installation de $($a.name) echouee." "Installing $($a.name) failed.") }
        }
        Tv "pm grant $KeyMapper android.permission.WRITE_SECURE_SETTINGS" | Out-Null
        $cur = ((Tv 'settings get secure enabled_accessibility_services') -join '').Trim()
        if (-not $cur -or $cur -eq 'null') { $new = $KeyMapperSvc } elseif ($cur -notlike "*$KeyMapperSvc*") { $new = "${cur}:$KeyMapperSvc" } else { $new = $cur }
        Tv "settings put secure enabled_accessibility_services $new" | Out-Null
        Tv 'settings put secure accessibility_enabled 1' | Out-Null
        Tv "monkey -p $KeyMapper -c android.intent.category.LEANBACK_LAUNCHER 1" | Out-Null
    }

    Step (T '6/6 Fermeture du debogage (automatique)' '6/6 Turning debugging off (automatic)')
    Tv 'settings put global adb_wifi_enabled 0; settings put global adb_enabled 0' | Out-Null
    Write-Host (T "`nTermine. Le debogage est coupe sur le Chromecast." "`nDone. Debugging is off on the Chromecast.") -ForegroundColor Green
    if (-not $Restore) {
        Write-Host (T "`nDERNIERE ETAPE, sur la TV (Key Mapper vient de s'ouvrir) :" "`nLAST STEP, on the TV (Key Mapper just opened):") -ForegroundColor Yellow
        Write-Host (T '  1. Bouton + (nouveau mapping) > Enregistrer le declencheur' '  1. + button (new mapping) > Record trigger')
        Write-Host (T '  2. Appuie UNE fois sur le bouton YouTube de la telecommande (pas les fleches)' '  2. Press the remote''s YouTube button ONCE (not the arrows)')
        Write-Host (T '  3. Actions > Ajouter une action > Lancer une app > TizenTube' '  3. Actions > Add action > Launch app > TizenTube')
        Write-Host (T '  4. Enregistrer, puis Accueil et teste le bouton YouTube' '  4. Save, go Home and try the YouTube button')
        Write-Host (T 'Pour tout annuler un jour : double-clic sur "Restore - Restaurer.cmd".' 'To undo everything later: double-click "Restore - Restaurer.cmd".')
    }
} catch {
    Write-Host (T "`nERREUR : $($_.Exception.Message)" "`nERROR: $($_.Exception.Message)") -ForegroundColor Red
    Write-Host (T "Rien d'autre n'a ete modifie. Signale-le ici : $Issues" "Nothing else was changed. Report it here: $Issues")
}
Read-Host (T "`nAppuie sur Entree pour fermer" "`nPress Enter to close")
