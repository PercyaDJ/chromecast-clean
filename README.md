# chromecast-clean

One double-click to clean a **Chromecast with Google TV 4K** from a Windows PC, using the
[CleanYourTV](https://github.com/Gathin23/cleanyourtv) debloat list, and to get **ad-free YouTube with the
YouTube TV interface** on the remote's YouTube button.

[Version française plus bas.](#français)

## What it does

| Step | What happens |
|---|---|
| PC setup | Installs Python with winget if missing and downloads Google's current platform-tools (`adb`) into the project folder. CleanYourTV's files ship in [`vendor/cleanyourtv`](vendor/cleanyourtv/VENDORED.md), pinned to one commit: nothing else is fetched from it. |
| Connect | Pairs over Wireless debugging: you type the address and the 6-digit code shown on the TV. |
| Backup | Saves the package list, disabled packages, `getprop` and all settings to `backup\`. |
| Debloat | Runs the vendored CleanYourTV `tools\disable.ps1` with `examples/google-chromecast-gtv-4k/debloat-keep-cast.txt`: telemetry, ad services and preloads disabled with `pm disable-user`, nothing uninstalled. The Google TV home and phone casting are kept. |
| YouTube | Installs the latest [TizenTube Cobalt](https://github.com/reisxd/TizenTubeCobalt) (YouTube TV interface, ad blocking, SponsorBlock) and [Key Mapper](https://github.com/keymapperorg/KeyMapper) from their official GitHub releases, and enables Key Mapper's accessibility service. |
| Close | Turns Wireless debugging and USB debugging off on the stick. |

One step stays manual, because Key Mapper only records a real button press: map the remote's
YouTube button (Button 3) to TizenTube Cobalt.

## Use

1. On the Chromecast: Settings > System > About, press **Build** 7 times. Then Developer options >
   **Wireless debugging** on > **Pair device with pairing code**.
2. On a Windows PC on the same network: download this repo (Code > Download ZIP, then extract it),
   double-click **`Install - Installer.cmd`**, type the address and the code shown on the TV.
3. When Key Mapper opens on the TV: **+** > record trigger > press the YouTube button once > action
   "Launch app" > TizenTube.

**Undo everything:** turn Wireless debugging back on, double-click **`Restore - Restaurer.cmd`**. It runs
CleanYourTV's `tools\restore.ps1` and uninstalls Key Mapper and TizenTube Cobalt.

Messages follow the Windows display language (French or English).

## Limits

- Tested on one Chromecast with Google TV 4K (sabrina) from a Windows PC. The script stops if the
  device is not a `sabrina`.
- The Google TV home still shows its promoted content: only replacing Home removes it, and on this model that
  costs phone casting after every reboot (see the CleanYourTV list's notes).
- TizenTube Cobalt and Key Mapper are third-party apps installed from prebuilt APKs. Read their READMEs first.
- Auto-discovery (`adb mdns`) may find nothing when the PC is on Ethernet and the stick on Wi-Fi; the script
  asks for the address instead.

Not affiliated with CleanYourTV, Google, TizenTube or Key Mapper. MIT licence.

---

## Français

Un double-clic depuis un PC Windows pour nettoyer un **Chromecast avec Google TV 4K** avec la liste
[CleanYourTV](https://github.com/Gathin23/cleanyourtv), et avoir **YouTube sans pub avec l'interface YouTube TV**
sur le bouton YouTube de la télécommande.

1. Sur le Chromecast : Paramètres > Système > À propos, appuie 7 fois sur **Build**. Puis Options pour les
   développeurs > **Débogage sans fil** > **Associer un appareil avec un code d'association**.
2. Sur le PC : télécharge le projet (Code > Download ZIP, puis extrais-le), double-clic sur
   **`Install - Installer.cmd`**, tape l'adresse et le code affichés sur la TV.
3. Dans Key Mapper sur la TV : **+** > enregistrer le déclencheur > appuie une fois sur le bouton YouTube >
   action "Lancer une app" > TizenTube.

**Tout annuler :** réactive le Débogage sans fil, puis double-clic sur **`Restore - Restaurer.cmd`**.

Les messages s'affichent dans la langue de Windows (français ou anglais). Les fichiers CleanYourTV sont inclus
dans `vendor/cleanyourtv`, figés sur une version : le script ne dépend pas d'un téléchargement externe.

Rien n'est désinstallé côté système (`pm disable-user`), le cast et l'accueil Google TV sont conservés.
