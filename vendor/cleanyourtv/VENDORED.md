# Vendored CleanYourTV files

Copied unchanged from [Gathin23/cleanyourtv](https://github.com/Gathin23/cleanyourtv) at commit
`d451b175ab3f869f9a5d66993fb2dd501c96920b` (2026-11-07), under its MIT licence (`LICENSE` in this folder).
Only the files the Chromecast 4K run needs:

| File | Used for |
|---|---|
| `tools/tv.py` | ADB client (with `TV_ADB_BINARY`, the paired Google adb) |
| `tools/recovery.py` | Records the state before the debloat and builds the restore commands |
| `tools/disable.ps1`, `tools/restore.ps1` | Apply and undo the list, with CleanYourTV's safety guards |
| `tools/requirements.txt` | Python dependencies of `tv.py` |
| `examples/google-chromecast-gtv-4k/debloat-keep-cast.txt` | The debloat list (casting and Google TV home kept) |

To update: copy the same paths from a newer CleanYourTV commit and change the hash above.
