# MorePlayers (Supermarket Simulator)

BepInEx-Mod (IL2CPP) für **Supermarket Simulator** (Nokta Games):
hebt das native Co-op-Limit (Standard: 4 Spieler) auf bis zu 32 an
(empfohlen: 20–24). Inkl. Auto-Updater.

## Dateien

| Datei | Zweck |
|---|---|
| `version.txt` | Version + DLL-URL + SHA256 für den Auto-Updater (Zeile 1 = Version, Zeile 2 = DLL-URL, Zeile 3 = SHA256) |
| `MorePlayers.dll` | Aktuelle Mod-DLL (`BepInEx/plugins/`) |

## Update veröffentlichen

1. Neue DLL bauen (`Bauen.ps1` / `Alles-Installieren.ps1`)
2. SHA256 ermitteln: `Get-FileHash MorePlayers.dll -Algorithm SHA256`
3. `MorePlayers.dll` ersetzen, `version.txt` aktualisieren (Version erhöhen!)
4. Commit + Push — alle Clients ziehen das Update beim nächsten Spielstart automatisch

## Hinweis

Nur für privaten Gebrauch in der eigenen Gruppe.
