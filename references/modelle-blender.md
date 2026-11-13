# Eigene 3D-Modelle mit Blender

Lies das, bevor du ein Modell in Blender baust oder ein Blender-Modell in Studio einsetzt. Einrichtung der Verbindungen: `references/kreativ-einrichtung.md`.

**Inhalt:** Wann Blender · Ablauf · Maße und Richtungen · Bewegliche Modelle · Die Helfer · Prüfen · Export · Einbau in Studio · Bewegung im Spiel · Wo Modelle andocken · Fremde Modelle · Typische Fehler

## Wann Blender, wann Blöcke

Erst muss das Spiel mit Blöcken Spaß machen. Eigene Modelle kommen danach und dort, wo Spieler genau hinsehen: Gegner und Bosse, Waffen, das Auto, wichtige Gegenstände, ein Wahrzeichen der Welt. Wände, Böden, Plattformen und Deckung bleiben Blöcke aus Studio (`references/weltbau.md`): schneller gebaut, leichter geändert, billiger für das Handy.

Stil: kantig und klar, wenige Flächen, passend zur Block-Welt. Ein Monster mit 700 Dreiecken und guten Proportionen wirkt besser als eines mit 20 000 und matschigen Formen.

## Ablauf

1. **Absprechen:** Was wird es, wie groß (in Studs, zum Vergleich: Spieler = 5 hoch), was soll sich bewegen?
2. **Bauen** in Blender mit den Helfern (unten), in kleinen Schritten. Nach jedem größeren Schritt ein Bild der 3D-Ansicht ansehen.
3. **Prüfen:** Ansichten von vorn und von der Seite, bei Figuren die Gelenk-Probe (`rig.pose_test`), dann `ex.check()`.
4. **Quelle speichern:** `rb.save(r"<spiel>/quellen/<Name>.blend")`.
5. **Exportieren:** `ex.export("<Name>", r"<spiel>/export")` schreibt `<Name>.glb` und den Begleitzettel `<Name>.roblox.json`.
6. **Nutzer fragen**, dann hochladen und einfügen (`kreativ-einrichtung.md`, Abschnitt 3).
7. **Einbauen** in Studio: `assets/weltbau/rig_bauen.luau` (bewegliche Figur) oder `modell_einbauen.luau` (alles andere).
8. **Ansehen** in Studio (`screen_capture`), bei Figuren mit Gelenk-Probe. Nummer in `PLAN.md` eintragen.

## Maße und Richtungen

Diese Vereinbarungen gelten für alle `rbx_`-Module und für den Einbau. Wer sie einhält, muss in Studio nichts drehen oder skalieren.

| | In Blender | Wird in Roblox |
|---|---|---|
| Größe | 1 Einheit = 1 Stud | Größe in Studs |
| Oben | +Z | +Y |
| **Vorderseite** | zeigt nach **−Y** (Vorderansicht, Ziffernblock 1) | schaut nach −Z |
| Links der Figur | +X | −X |
| Standort | steht auf Z = 0, mittig über dem Ursprung (`ex.ground()`) | Fußpunkt |

Richtwerte: Spieler 5 Studs hoch und 2 breit. Tür mindestens 5 × 8. Kleiner Gegner 3 bis 4 hoch, normaler 5 bis 7, Boss 12 bis 25. Waffe in der Hand 2 bis 4 lang.

Dreiecke: Gegenstand 100 bis 500, Figur 500 bis 3 000, Boss oder Fahrzeug bis 8 000. `ex.check()` warnt ab 6 000 je Teil und bricht ab 20 000 ab. Viele gleiche Gegner auf einmal? Dann eher an der unteren Grenze bleiben.

## Bewegliche Modelle: jedes Teil einzeln

Alles, was sich bewegen soll, wird aus Einzelteilen gebaut: Monster, Tiere, Roboter, aber auch Türen, Truhen, Geschütze, Hebel. Kein Stück „aus einem Guss", keine Knochen, keine Verformung. So lässt sich in Roblox jedes Körperteil einzeln drehen, per Code oder im Animations-Editor.

- **Jedes bewegliche Teil ist ein eigenes Objekt:** Rumpf, Kopf, Kiefer, Ober- und Unterarm, Ober- und Unterschenkel, jedes Schwanzglied, jeder Flügel.
- **Der Ursprung liegt am Gelenk.** `joint` ist der Drehpunkt (Schulter, Hüfte, Halsansatz, Scharnier). `offset` schiebt die Form vom Gelenk weg: Ein Arm hängt *unter* der Schulter.
- **Eltern-Kette:** `Torso` → `LeftUpperArm` → `LeftLowerArm`. Genau ein Teil hat kein Eltern-Teil (die Wurzel, meist `Torso`).
- **Am Gelenk überlappen** die Teile etwas, sonst klafft beim Drehen eine Lücke.
- **Grundhaltung gerade:** Arme hängen, Beine stehen, nichts ist gedreht. Soll ein Teil schräg sein, die *Form* schräg bauen, nicht das Objekt drehen.
- **Was sich nie einzeln bewegt, verschmelzen** (`rb.join`): Hörner mit dem Kopf, Stacheln mit dem Rücken. Weniger Teile = schneller.
- **Eigenes Teil trotz Starrheit**, wenn es eine andere Farbe braucht (Augen, Bauchplatte): In Roblox hat ein Teil genau eine Farbe.
- **Andockpunkte** (`rig.attachment`) für alles, wo später etwas ansetzt: Griff, Mündung, Kopf-Oben, Effekt-Stelle.

**Namen, die der Bewegungs-Baustein von selbst erkennt** (Groß-/Kleinschreibung egal, Teilwort genügt):

| Teil | Name enthält | Beispiele |
|---|---|---|
| Rumpf | ist die Wurzel | `Torso`, `Body` |
| Kopf | `Head`, `Neck` | `Head` |
| Kiefer | `Jaw` | `Jaw` |
| Arm | `Arm`, `Hand` | `LeftUpperArm`, `LeftLowerArm`, `RightHand` |
| Bein | `Leg`, `Foot` | `LeftUpperLeg`, `LeftLowerLeg`; Vierbeiner: `FrontLeftLeg`, `BackRightLeg` |
| Schwanz | `Tail` + Nummer | `Tail1`, `Tail2`, `Tail3` |
| Flügel | `Wing` | `LeftWing`, `RightWing` |

Seite immer als `Left`/`Right`, unteres Glied als `Lower` (oder `Hand`/`Foot`). Andere Namen (`LeftEye`, `Horn`, `Shield`) sind erlaubt; solche Teile bleiben starr an ihrem Eltern-Teil. Namen nur aus Buchstaben, Ziffern und `_`.

Das vollständige Beispiel steht in `assets/kreativ/blender/beispiel_monster.py` (17 Teile, 704 Dreiecke). Als Vorlage lesen, bevor die erste eigene Figur entsteht.

## Die Helfer

Zuerst in Blender ausführen, dann stehen die Module bereit:

```python
import sys; sys.path.insert(0, r"<skill>/assets/kreativ/blender")
import rbx_base as rb, rbx_rig as rig, rbx_export as ex
```

Über die Blender-Verbindung bleibt die Szene zwischen zwei Aufrufen erhalten. Auf Python-Variablen aus einem früheren Aufruf ist dagegen kein Verlass. Jeder Aufruf beginnt deshalb mit den Imports und holt Objekte über den Namen: `torso = bpy.data.objects["Torso"]`.

| Modul | Wichtigste Funktionen |
|---|---|
| `rbx_base` | `new_scene()` · `box`, `cylinder`, `cone`, `sphere` (mit `taper`, `bevel`) · `join` · `mirror_x` · `set_origin` · `material(name, (r, g, b))` + `paint` · `uv_box` · `simplify(obj, dreiecke)` · `preview(pfad, view=…)` · `save(pfad)` |
| `rbx_rig` | `part(name, size, joint, offset, parent, mat, shape)` · `as_part(obj, joint, parent)` · `attachment(name, position, parent)` · `mirror_chain(teil, "Left", "Right")` · `pose_test(pfad)` |
| `rbx_export` | `ground()` · `check()` · `export(name, ordner)` |
| `rbx_texture` | `unwrap` · `bake_color` · `bake` · `apply` (siehe `texturen-photocraft.md`) |
| `rbx_vfx` | leuchtende Formen und Bildfolgen rendern (siehe `effekte.md`) |

Kurzform einer Figur:

```python
rb.new_scene()
haut = rb.material("Haut", (92, 150, 84))
torso = rig.part("Torso", size=(3, 1.9, 2.6), joint=(0, 0, 2.5), offset=(0, 0, 1.3), mat=haut, taper=1.15)
kopf  = rig.part("Head", size=(2, 1.9, 1.7), joint=(0, -0.1, 5.0), offset=(0, -0.2, 0.9), parent=torso, mat=haut)
arm   = rig.part("LeftUpperArm", size=(1, 1, 1.7), joint=(2, 0, 4.7), offset=(0, 0, -0.7), parent=torso, mat=haut)
unter = rig.part("LeftLowerArm", size=(1.2, 1.2, 1.8), joint=(2, 0, 3.25), offset=(0, 0, -0.8), parent=arm, mat=haut)
rig.attachment("LeftGrip", (2, -0.2, 1.7), parent=unter)
rig.mirror_chain(arm, "Left", "Right")        # rechter Arm samt Unterarm und Andockpunkt
ex.ground()
```

Eine Seite bauen, dann spiegeln. Für freie Formen (nicht nur Quader) eigene Meshes mit `bmesh` bauen und mit `rig.as_part(obj, joint, parent)` zum Teil machen. Eigene Blender-Befehle sind erlaubt; möglichst die Daten-Schnittstelle (`bpy.data`, `bmesh`) statt Auswahl-Operatoren nutzen, das läuft über die Verbindung verlässlicher.

## Prüfen, bevor exportiert wird

Bilder ansehen, nicht nur Zahlen lesen:

| Bild | Zeigt |
|---|---|
| Bild der 3D-Ansicht (Blender-Verbindung) oder `rb.preview(pfad)` | Gesamteindruck, Proportionen, Farben |
| `rb.preview(pfad, view="vorne")`, `"seite"`, `"hinten"`, `"oben"` | Symmetrie, schiefe oder schwebende Teile |
| `rig.pose_test(pfad)` | jedes Gelenk probeweise gedreht |

Bei der Gelenk-Probe achten auf: Dreht sich das Teil um das Gelenk (richtig) oder um die eigene Mitte (Ursprung falsch)? Reißt etwas ab oder klafft eine Lücke (zu wenig Überlappung)? Stößt ein Teil durch ein anderes (Form kürzen)?

`ex.check()` meldet Fehler (Export wird verweigert) und Hinweise: falsche Namen, gedrehte oder skalierte Teile, lose Meshes, mehrere Wurzeln, Gelenk abseits der Form, Teil berührt sein Eltern-Teil nicht, zu viele Dreiecke, steht nicht auf dem Boden.

## Export und Begleitzettel

`ex.export("Monster", r"<spiel>/export")` schreibt:

- `Monster.glb`: das Modell (ersatzweise `file_format="fbx"`, falls Roblox das `.glb` nicht annimmt).
- `Monster.roblox.json`: der **Begleitzettel**. Er enthält, was der Import nicht verlässlich überträgt: Größe in Studs, je Teil Farbe, Eltern-Teil, Gelenk-Position, Mitte und Größe, dazu die Andockpunkte. Alle Positionen stehen schon in Roblox-Achsen, gemessen vom Fußpunkt.

Roblox setzt Gelenke beim Import eigener Figuren oft falsch. Deshalb verlässt sich der Skill nicht darauf: Die Gelenke baut `rig_bauen.luau` aus dem Zettel.

## Einbau in Studio

Nach dem Hochladen und Einfügen (`insert_asset`) liegt das Modell irgendwo in der Welt, in irgendeiner Größe und Drehung. Die Helfer richten das.

**Bewegliche Figur: `assets/weltbau/rig_bauen.luau`**

1. Datei lesen, den Inhalt von `<Name>.roblox.json` bei `SHEET_JSON` einfügen, `OPTIONS` setzen, als ein Skript über `execute_luau` ausführen.
2. Der Bericht nennt Größe, Zahl der Gelenke und Hinweise. Bei „Teile fehlen" stimmen Zettel und Modell nicht überein, oder der Import hat Teile zusammengelegt.
3. `OPTIONS.Mode = "probe"` ausführen, `screen_capture`, ansehen. Danach `"probe_aus"`.

Wichtige Optionen: `Humanoid` (true = läuft und hat Leben; false = Gerät wie Tür oder Geschütz, fest verankert), `Parent` (Zielordner, z. B. `"ServerStorage.Assets.Enemies"`), `Name` (bei Gegnern der Schlüssel aus der Config), `Animated`, `Gait`, `Texture`, `Position`, `Turn`.

Das Ergebnis: ein `Model` mit unsichtbarer Mitte `HumanoidRootPart` (zugleich `PrimaryPart` und Kollision), allen Teilen flach darin, einem `Motor6D` je Teil (im Teil, benannt wie das Teil), Attachments und `Humanoid` oder `AnimationController`. Jedes Gelenk hat die Achsen der Figur: X rechts, Y oben, Blick nach −Z.

**Alles ohne Gelenke: `assets/weltbau/modell_einbauen.luau`**

Gleiches Vorgehen. Optionen: `Anchored` (true = steht fest; false = Teile ans Hauptteil geschweißt, für Waffen und Gegenstände), `Collision` (`"Kasten"`, `"Teile"`, `"Keine"`), `Texture` oder die Karten `ColorMap`/`NormalMap`/`RoughnessMap`/`MetalnessMap`, `Tags`, `Attributes`, `Parent`. Bei Modellen aus einem einzigen Teil kann vorn und hinten vertauscht sein: Bildschirmfoto prüfen, sonst `MeshTurn = 180`.

## Bewegung im Spiel

**Sofort, ohne Animationsdatei:** Figuren mit dem Tag `AnimatedRig` bewegt der `RigAnimationController` (Client) von selbst: Beine und Arme schwingen passend zur Laufstrecke, der Rumpf wippt und atmet, der Schwanz wedelt, Flügel schlagen. `rig_bauen.luau` setzt den Tag, wenn `Animated = true`.

| Attribut am Model | Wirkung |
|---|---|
| `Gait` | `"Zweibeiner"`, `"Vierbeiner"`, `"Schweben"`. Ohne Angabe aus den Teilen erraten. |
| `Tempo` | 1 = normal, größer = schnellere Schritte |
| `Strength` | 1 = normal, größer = ausladender, 0 = starr |
| `JawOpen` | 0 bis 1. Der Server setzt z. B. beim Angriff 1 und kurz danach 0. |

Die Rechnung steht in `src/shared/Util/RigMotion.luau` (getestet in `tests/RigMotion.spec.luau`); `RigMotion.Tuning` ändert den Charakter aller Figuren an einer Stelle. Eigene Bewegungen (Schlag, Sprung) dort als weitere Rolle oder Eingabe ergänzen und im Test absichern.

**Von Hand:** Das Rig ist ein normales Roblox-Rig. Im Animations-Editor von Studio öffnen und jedes Körperteil einzeln bewegen. Dann den Tag `AnimatedRig` weglassen, sonst überschreibt der Controller die eigene Animation.

## Wo eigene Modelle andocken

Der Code der Genres sucht eigene Modelle an festen Stellen und nimmt sonst seine Block-Version. Nichts am Code muss geändert werden.

| Genre | Ort und Name | Anforderung | Helfer |
|---|---|---|---|
| RPG | `ServerStorage.Assets.Enemies.<Schlüssel>` | Model mit Humanoid, PrimaryPart = `HumanoidRootPart` | `rig_bauen`, `Humanoid = true` |
| Horror | `ServerStorage.Assets.Chaser` | wie oben | `rig_bauen`, `Humanoid = true` |
| Ego-Shooter | `ReplicatedStorage.Assets.Weapons.<Id>` | Waffe zeigt nach −Z; am Hauptteil die Andockpunkte `Grip`, `Support`, `Muzzle`, `Sight`, `Magazine` | `modell_einbauen`, `Anchored = false`, `Collision = "Keine"` |
| Rennen | `ServerStorage.Assets.Car` | PrimaryPart `Chassis` (Quader) mit `VehicleSeat`; Zierteile masselos, ohne Kollision | Karosserie mit `modell_einbauen` (`Collision = "Keine"`, `Anchored = false`), dann an `Chassis` schweißen |
| Dungeon | `ServerStorage.Assets.DungeonRooms.<Art>` | siehe `genres/dungeon.md` | Deko mit `modell_einbauen` in den Raum |
| alle | `Workspace.Welt.<Ordner>` | Deko, Wahrzeichen | `modell_einbauen`, `Anchored = true` |

Für Waffen in Blender die Form verschmelzen (`rb.join`), mit `rig.as_part(obj, joint=<Griff>)` zu einem Teil machen und die Andockpunkte mit `rig.attachment` setzen; `modell_einbauen` legt sie ans Hauptteil.

## Fremde Modelle (Bibliothek, KI-Generator)

Poly Haven, Sketchfab und die KI-Generatoren der Community-Verbindung liefern meist **ein Stück mit sehr vielen Flächen**.

- Nur als **unbewegte Deko**. Figuren, die sich bewegen sollen, immer selbst in Einzelteilen bauen.
- **Vereinfachen:** `rb.simplify(obj, 1500)`, danach Bild ansehen. Sieht es zerfressen aus, eine höhere Zahl wählen oder selbst nachbauen.
- **Größe und Lage** an die Vereinbarungen anpassen (Skalierung in die Form übernehmen, `ex.ground()`), Namen bereinigen, dann normal `ex.check()` und `ex.export()`.
- **Lizenz:** Poly Haven ist frei (CC0). Bei Sketchfab die Lizenz jedes einzelnen Modells prüfen und dem Nutzer nennen. Nichts mit Marken oder Figuren aus anderen Spielen.
- Passt es zum Block-Stil? Ein fotorealistischer Fels neben Block-Bäumen wirkt fremd. Im Zweifel selbst bauen.

## Typische Fehler

| Zeichen | Ursache | Abhilfe |
|---|---|---|
| Teil dreht sich um seine Mitte statt ums Gelenk | `joint` fehlt oder sitzt in der Form-Mitte | `joint` an die Gelenkstelle, Form über `offset` verschieben |
| Lücke am Gelenk beim Drehen | Teile berühren sich nur knapp | Form verlängern, sodass sie ins Eltern-Teil ragt |
| `check`: „ist gedreht" | Objekt gedreht statt Form | Drehung auf 0, Form gedreht bauen |
| `check`: „Skalierung ist nicht 1" | Objekt skaliert | Größe direkt in `size` angeben |
| `rig_bauen`: „Teile fehlen" | Zettel passt nicht zum Modell, oder Import hat umbenannt | Namen im Bericht vergleichen, neu exportieren |
| `rig_bauen`: Teile „neben dem erwarteten Platz" | alter Zettel, anderer Export | Modell und Zettel aus demselben Export nehmen |
| Figur läuft rückwärts | Vorderseite in Blender nicht nach −Y gebaut | in Blender umdrehen und neu exportieren |
| Figur versinkt oder schwebt | nicht auf dem Boden gebaut | `ex.ground()` vor dem Export |
| Beine rutschen über den Boden | Schrittlänge passt nicht | Attribut `Tempo` anpassen |
| Modell in Studio grau | Farben nicht gesetzt | `Colors = true` oder Textur angeben |
