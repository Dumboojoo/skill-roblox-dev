# Ego-Shooter

Ich-Perspektive mit Waffe und **geraden Block-Armen ohne Animationen**. Vorbilder für den Look: `assets/referenz/` (drei Bilder: Arme als gerade Quader mit Hand-Block und Manschette, die zur Waffe zeigen). Übernommen wird die Technik, nicht Name, Waffen oder Maps eines bestimmten Spiels.

## Dateien (`assets/genres/ego-shooter/src/`)

| Datei | Inhalt |
|---|---|
| `shared/Config/Weapons.luau` | alle Waffen (Schaden, Feuerrate, Streuung, Rückstoß, Block-Modell), Startausrüstung, Aussehen der Arme |
| `shared/Shooter/WeaponModel.luau` | baut das Waffenmodell aus Blöcken oder nimmt ein eigenes aus `ReplicatedStorage.Assets.Weapons` |
| `client/Controllers/ViewmodelController.luau` | **die Ego-Ansicht**: Waffe und Arme jeden Frame setzen; Schwanken, Wippen, Rückstoß, Zielen, Ziehen, Nachladen per Feder und Sinus |
| `client/Controllers/WeaponController.luau` | Eingaben, Schuss mit Sofort-Rückmeldung, Leuchtspur, Fadenkreuz, Munition, Kill-Anzeige |
| `server/Services/WeaponService.luau` | Munition, Feuerrate, Treffer-Prüfung, Schaden, Kills, Waffe in der Hand für andere Spieler |
| `server/Admin/Commands/Shooter.luau` | `ammo`, `infammo` |
| `shared/Config/DataSections/Shooter.luau` | Kills, Tode, Kopfschüsse |

## So funktionieren die Block-Arme

- Ein `Model` „Viewmodel" hängt unter der Kamera (existiert nur auf dem eigenen Client).
- Die Waffe wird jeden Frame auf `Kamera * Versatz` gesetzt (`PivotTo`); alle Teile sind verankert, es ist keine Physik beteiligt.
- Jeder Arm besteht aus drei Quadern (Ärmel, Manschette, Hand), die als gerade Linie von einem festen **Schulterpunkt neben der Kamera** zum **Griff** der Waffe gespannt werden (`placeArm`). Bewegt sich die Waffe, folgen die Arme von allein.
- Rechte Hand → Attachment `Grip`, linke Hand → `Support`, beim Nachladen wandert sie zum `Magazine`.
- Abstimmen: `Weapons.Arms` (Breite, Farben, Schulterpunkte), je Waffe `HipOffset`; Bewegung über die Konstanten oben im `ViewmodelController`.

Neue Bewegung (Sprinten, Landen, Inspizieren): einen Versatz berechnen und in `update` auf Position oder Drehung addieren. Nie Animationen dafür erzwingen.

## Treffer und Sicherheit

Der Client meldet Start, Richtung und was er getroffen hat. Der Server prüft Feuerrate, Munition, Abstand des Startpunkts zum Kopf, Reichweite, Winkel zur Schussrichtung, ob das Ziel ungefähr dort ist, und freie Sichtlinie. Toleranzen oben im `WeaponService`. Begründung für diese Aufteilung steht im Kopfkommentar der Datei.

## Welt-Vertrag

| Was | Bedingung |
|---|---|
| `SpawnLocation`s | mindestens eine; bei Teams mit `TeamColor` |
| Trainingspuppe (optional) | Model mit `Humanoid`; nimmt Schaden wie ein Spieler |
| Eigenes Waffenmodell (optional) | `ReplicatedStorage.Assets.Weapons.<Id>`, PrimaryPart mit Attachments `Grip`, `Support`, `Muzzle`, `Sight`, `Magazine`; Waffe zeigt nach -Z. Aus Blender: Andockpunkte mit `rig.attachment` setzen, Einbau mit `assets/weltbau/modell_einbauen.luau` (`Anchored = false`, `Collision = "Keine"`), siehe `references/modelle-blender.md` |

## Was einen guten Shooter ausmacht

- **Schussgefühl zuerst:** Ton, Mündungsfeuer, Rückstoß, Leuchtspur, Treffer-Marker. Ohne Ton wirkt jede Waffe schwach.
- Waffen unterscheiden sich in der **Rolle**, nicht nur in Zahlen (nah/fern, Dauerfeuer/Einzelschuss).
- Zeit bis zum Besiegen ca. 0,4 bis 1 Sekunde bei Treffern; länger = zäh, kürzer = frustrierend.
- Karten: Deckung alle 10 bis 15 Studs, zwei Wege zu jedem Punkt, keine Sicht von Spawn zu Spawn, Spawn-Schutz.
- Spielmodus klar (Team-Deathmatch, Jeder gegen jeden, Eroberung); für Runden den Ablauf aus `runden-minispiele` übernehmen.
- Fortschritt über Freischaltungen und Kosmetik, nicht über stärkere Waffen gegen Geld.

## Erweitern

- **Neue Waffe:** Eintrag in `Weapons.List`, in `Loadout` aufnehmen.
- **Granaten, Nahkampf:** eigener Service nach demselben Muster (Client meldet, Server prüft).
- **Teams/Runden:** `WeaponService.Killed` liefert Kills an eine Rundenlogik.
- **Geräusche:** `SOUNDS` im `WeaponController`.

## Stolperfallen

- Das Viewmodel muss **nach** der Kamera aktualisiert werden (`BindToRenderStep` mit `Camera.Value + 1`), sonst zittert es.
- Kamera-Rückstoß jeden Frame als vollen Versatz aufrechnen (das Kamera-Skript setzt die Kamera jeden Frame neu).
- Raycasts des Schützen müssen den eigenen Charakter und die Kamera (Viewmodel) ausschließen.
- Schaden über `TakeDamage`, damit Spawn-Schutz und Gott-Modus greifen.
- R6-Avatare: Die Hand heißt „Right Arm"; im Spiel R15 einstellen.

## Erstprüfung in Studio

1. Spieltest: Waffe und beide Arme sichtbar, Arme enden am Griff bzw. Vorderschaft, nichts zittert.
2. Schießen, Zielen (Rechtsklick), Nachladen (`R`), Wechsel (`1`/`2`): Bildschirmfoto je Zustand.
3. Puppe (Model mit Humanoid) aufstellen: Treffer ziehen Leben ab, durch eine Wand nicht.
4. `infammo an`, Dauerfeuer: Ausgabe ohne Fehler, Bildrate stabil.
5. Zwei Spieler (Nutzer): Der andere sieht Waffe in der Hand und Leuchtspuren; Kill erscheint in der Anzeige.
