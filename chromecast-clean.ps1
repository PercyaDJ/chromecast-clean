# chromecast-clean.ps1 - Chromecast with Google TV 4K : CleanYourTV + YouTube sans pub (SmartTube)
# Lance par LANCER.cmd (double-clic). Annuler : ANNULER.cmd
#
# Fait tout seul : prerequis Windows, CleanYourTV, detection du Chromecast sur le Wi-Fi, sauvegarde,
# debloat (cast et accueil Google TV gardes), TizenTube Cobalt (interface YouTube TV sans pub) + Key Mapper
# (bouton YouTube), puis coupe le debogage.
# Toi : tu tapes uniquement le code a 6 chiffres affiche sur la TV.

param([switch]$Restore, [string]$Dir = (Join-Path $HOME 'cleanyourtv'))
# Continue : sous PowerShell 5.1, Stop transforme toute sortie stderr d'adb en erreur fatale.
$ErrorActionPreference = 'Continue'
$OutputEncoding = New-Object System.Text.UTF8Encoding $false
$List = 'examples\google-chromecast-gtv-4k\debloat-keep-cast.txt'
$StockHome = 'com.google.android.apps.tv.launcherx'
$SmartTube = 'com.teamsmart.videomanager.tv'
$TizenTube = 'io.gh.reisxd.tizentube.cobalt'
$KeyMapper = 'io.github.sds100.keymapper'
$KeyMapperSvc = 'io.github.sds100.keymapper/io.github.sds100.keymapper.system.accessibility.MyAccessibilityService'

function Step($t) { Write-Host "`n=== $t" -ForegroundColor Cyan }
function RefreshPath { $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User') }
function Need($cmd, $id) {
    if (Get-Command $cmd -ErrorAction SilentlyContinue) { return }
    Write-Host "Installation de $id..."
    winget install -e --id $id --accept-source-agreements --accept-package-agreements | Out-Host
    RefreshPath
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { throw "$cmd introuvable apres installation : ferme cette fenetre et relance LANCER.cmd." }
}
function Tv($c) { & $py -I tools\tv.py $c }
function Mdns($type) {
    $o = (& $adb mdns services 2>$null) -join "`n"
    [regex]::Matches($o, "$type\S*\s+(\d+\.\d+\.\d+\.\d+:\d+)") | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
}
function Connected($h) { (& $adb connect $h 2>$null) -match 'connected' -and ((& $adb -s $h get-state 2>$null) -eq 'device') }

try {
    Step '1/6 Preparation du PC (automatique)'
    Need git 'Git.Git'
    Need py  'Python.Python.3.12'
    if (Test-Path (Join-Path $Dir '.git')) { git -C $Dir pull -q --ff-only } else { git clone -q https://github.com/Gathin23/cleanyourtv $Dir }
    if (-not (Test-Path (Join-Path $Dir $List))) { throw 'Telechargement de CleanYourTV echoue (connexion Internet ?).' }
    Set-Location $Dir
    $py = Join-Path $Dir 'tools\venv\Scripts\python.exe'
    if (-not (Test-Path $py)) { py -3 -m venv tools\venv }
    & $py -m pip install -q -r tools\requirements.txt
    if ($LASTEXITCODE -ne 0) { throw 'Installation des dependances Python echouee.' }
    # cmd + nul : sous Windows, le daemon adb herite du pipe PowerShell et bloque le script indefiniment
    # adb officiel de Google dans le dossier du projet : un vieil adb deja installe ne connait pas "pair"
    $adb = Join-Path $Dir 'platform-tools\adb.exe'
    if (-not (Test-Path $adb)) {
        Write-Host 'Telechargement de adb (Google platform-tools)...'
        $zip = Join-Path $env:TEMP 'platform-tools.zip'
        Invoke-WebRequest -ErrorAction Stop 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip' -OutFile $zip
        Expand-Archive -Force $zip $Dir
    }
    if (-not (Test-Path $adb)) { throw 'adb introuvable apres telechargement.' }
    cmd /c "taskkill /F /IM adb.exe >nul 2>&1"
    cmd /c "`"$adb`" start-server >nul 2>&1\"

    Step '2/6 Connexion au Chromecast'
    $tvHost = $null
    foreach ($h in (Mdns '_adb-tls-connect\._tcp')) { if (Connected $h) { $tvHost = $h; break } }
    if (-not $tvHost) {
        Write-Host ''
        Write-Host 'SUR LA TV : Options pour les developpeurs > Debogage sans fil >' -ForegroundColor Yellow
        Write-Host '            "Associer un appareil avec un code d''association"' -ForegroundColor Yellow
        Write-Host 'La TV affiche un code a 6 chiffres et, juste dessous, une adresse du type 192.168.1.42:37123'
        Write-Host ''
        $pair = (Read-Host 'Adresse affichee SOUS LE CODE (IP:port)').Trim()
        $code = (Read-Host 'Code a 6 chiffres').Trim()
        $out = (& $adb pair $pair $code 2>&1) -join ' '
        Write-Host $out
        if ($out -notmatch 'Successfully paired') { throw "Appairage refuse ($out). Verifie l'adresse et le code (le code change a chaque ouverture de la fenetre), puis relance LANCER.cmd." }
        Write-Host 'Appairage OK.' -ForegroundColor Green
        $ip = $pair.Split(':')[0]
        foreach ($h in (Mdns '_adb-tls-connect\._tcp')) { if ($h.StartsWith("${ip}:") -and (Connected $h)) { $tvHost = $h } }
        if (-not $tvHost) {
            Write-Host ''
            Write-Host 'SUR LA TV : ferme la fenetre du code (Retour). L''ecran "Debogage sans fil" affiche' -ForegroundColor Yellow
            Write-Host '            "Adresse IP et port" avec un AUTRE port, du type 192.168.1.42:41567' -ForegroundColor Yellow
            $port = (Read-Host "Tape seulement ce nouveau port (le chiffre apres ${ip}:)").Trim()
            $tvHost = "${ip}:$port"
            if (-not (Connected $tvHost)) { throw "Connexion impossible a $tvHost. Verifie le port sur l'ecran Debogage sans fil et relance LANCER.cmd." }
        }
    }
    $env:TV_ADB_BINARY = $adb
    $env:TV_HOST = $tvHost
    $probe = (& $py -I tools\tv.py --probe) -join "`n"
    if ($probe -notmatch 'sabrina') { Write-Host $probe; throw 'Ce n''est pas un Chromecast with Google TV 4K (sabrina) : arret, rien n''a ete modifie.' }
    Write-Host "Chromecast 4K trouve : $tvHost" -ForegroundColor Green

    if ($Restore) {
        Step 'Annulation'
        & powershell -ExecutionPolicy Bypass -File tools\restore.ps1 $List -Stock $StockHome
        Tv "settings put secure enabled_accessibility_services ''" | Out-Null
        foreach ($p in @($KeyMapper, $SmartTube, $TizenTube)) { & $adb -s $tvHost uninstall $p 2>$null | Out-Host }
    } else {
        Step '3/6 Sauvegarde du Chromecast (automatique)'
        $bk = Join-Path $Dir ('backup\chromecast-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        New-Item -ItemType Directory -Force $bk | Out-Null
        Tv 'pm list packages'    | Set-Content (Join-Path $bk 'packages.txt')
        Tv 'pm list packages -d' | Set-Content (Join-Path $bk 'disabled.txt')
        Tv 'getprop'             | Set-Content (Join-Path $bk 'getprop.txt')
        foreach ($ns in 'secure','global','system') { Tv "settings list $ns" | Set-Content (Join-Path $bk "settings-$ns.txt") }

        Step '4/6 Suppression des pubs et de la telemetrie Google TV (automatique)'
        & powershell -ExecutionPolicy Bypass -File tools\disable.ps1 $List
        if ($LASTEXITCODE -ne 0) { throw 'Le debloat a signale une erreur (voir ci-dessus).' }

        Step '5/6 Installation de TizenTube Cobalt (YouTube sans pub) et Key Mapper (automatique)'
        $h = @{ 'User-Agent' = 'chromecast-clean' }
        $abi = ((Tv 'getprop ro.product.cpu.abi') -join '').Trim()
        $want = if ($abi -like 'arm64*') { 'cobalt-arm64.apk' } else { 'cobalt-arm.apk' }
        $tt = (Invoke-RestMethod -ErrorAction Stop -Headers $h 'https://api.github.com/repos/reisxd/TizenTubeCobalt/releases/latest').assets |
              Where-Object { $_.name -eq $want } | Select-Object -First 1
        $km = (Invoke-RestMethod -ErrorAction Stop -Headers $h 'https://api.github.com/repos/keymapperorg/KeyMapper/releases/latest').assets |
              Where-Object { $_.name -like '*.apk' -and $_.name -notlike '*debug*' } |
              Sort-Object { if ($_.name -like '*foss*') { 0 } else { 1 } } | Select-Object -First 1
        if (-not $tt) { throw "APK TizenTube Cobalt ($want) introuvable sur le GitHub officiel." }
        if (-not $km) { throw 'APK Key Mapper introuvable sur le GitHub officiel.' }
        foreach ($a in @($tt, $km)) {
            $apk = Join-Path $Dir "backup\$($a.name)"
            Write-Host "Telechargement $($a.name)"
            Invoke-WebRequest -ErrorAction Stop -Headers $h $a.browser_download_url -OutFile $apk
            Write-Host "Installation $($a.name)"
            & $adb -s $tvHost install -r $apk | Out-Host
            if ($LASTEXITCODE -ne 0) { throw "Installation de $($a.name) echouee." }
        }
        if ((Tv "pm list packages $SmartTube") -match $SmartTube) {
            Write-Host 'Desinstallation de SmartTube (remplace par TizenTube Cobalt)'
            & $adb -s $tvHost uninstall $SmartTube | Out-Host
        }
        Tv "pm grant $KeyMapper android.permission.WRITE_SECURE_SETTINGS" | Out-Null
        $cur = ((Tv 'settings get secure enabled_accessibility_services') -join '').Trim()
        if (-not $cur -or $cur -eq 'null') { $new = $KeyMapperSvc } elseif ($cur -notlike "*$KeyMapperSvc*") { $new = "${cur}:$KeyMapperSvc" } else { $new = $cur }
        Tv "settings put secure enabled_accessibility_services $new" | Out-Null
        Tv 'settings put secure accessibility_enabled 1' | Out-Null
        Tv "monkey -p $KeyMapper -c android.intent.category.LEANBACK_LAUNCHER 1" | Out-Null
    }

    Step '6/6 Fermeture du debogage (automatique)'
    Tv 'settings put global adb_wifi_enabled 0; settings put global adb_enabled 0' | Out-Null
    Write-Host "`nTermine. Le debogage est coupe sur le Chromecast." -ForegroundColor Green
    if (-not $Restore) {
        Write-Host "`nDERNIERE ETAPE, sur la TV (Key Mapper vient de s'ouvrir) :" -ForegroundColor Yellow
        Write-Host '  Si un mapping vers SmartTube existe deja : ouvre-le, supprime l''action et remplace-la par TizenTube (etape 3).'
        Write-Host '  1. Bouton + (nouveau mapping) > Enregistrer le declencheur'
        Write-Host '  2. Appuie UNE fois sur le bouton YouTube de la telecommande (pas les fleches)'
        Write-Host '  3. Actions > Ajouter une action > Lancer une app > TizenTube (ou Cobalt)'
        Write-Host '  4. Enregistrer (disquette), puis Accueil et teste le bouton YouTube'
        Write-Host 'Pour annuler un jour : double-clic sur ANNULER.cmd.'
    }
} catch {
    Write-Host "`nERREUR : $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Copie ce message a Claude.'
}
Read-Host "`nAppuie sur Entree pour fermer"
