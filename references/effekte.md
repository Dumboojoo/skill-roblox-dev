# Effekte: Partikel, Strahlen, Spuren und ihre Bilder

Lies das, wenn eine Aktion im Spiel sichtbar werden soll (Treffer, Schuss, Explosion, Aufsammeln, Heilung, Fähigkeit) oder wenn ein Effekt-Bild gezeichnet wird.

**Inhalt:** Bausteine von Roblox · Einmalige Effekte (`EffectController`, gestapelte Schichten) · Dauerhafte Effekte · Gestaltungsregeln · Bilder machen (Zeichen-Skript, Blender, PhotoCraft) · Vom Bild ins Spiel · Typische Fehler

## Die vier Bausteine von Roblox

| Baustein | Wofür | Bild |
|---|---|---|
| `ParticleEmitter` | alles, was aufblitzt, sprüht, raucht, glitzert | ein Partikel-Bild oder eine Bildfolge |
| `Beam` | Verbindung zwischen zwei Punkten: Laser, Blitz, Seil, Zielhilfe | ein Band, das sich entlang des Strahls wiederholt |
| `Trail` | Schweif hinter etwas Bewegtem: Schwert, Geschoss, Füße | ein Band, das nach hinten ausläuft |
| Bildfolge (Flipbook) | ein Partikel, das sich über seine Lebensdauer verändert: Explosion, Druckwelle, Hieb | Raster 2×2, 4×4 oder 8×8 |

## Einmalige Effekte: `EffectController`

Kurze Effekte stehen als Tabelle in `src/shared/Config/Effects.luau` und werden über den Namen gespielt. Der Server rechnet nichts; jeder Client lässt weg, was zu weit entfernt ist.

```lua
-- Client
EffectController:Play("Hit", position)
EffectController:Play("Shot", position, richtung)       -- mit Richtung (Lauf, Wand-Normale)
EffectController:Play("Explosion", position, nil, 1.5)  -- 1.5-mal so groß
EffectController:PlayOn("Heal", teilOderAttachment)     -- bewegt sich mit

-- Server (alle in der Nähe sehen es)
Net.FireNear("Effect.Play", position, 150, "Explosion", position)
```

Vorhanden: `Hit`, `Slash`, `Shot`, `Impact`, `Explosion`, `Collect`, `Heal`, `Dust`, `Celebrate`. Neuer Effekt = neuer Eintrag in `Effects.List`. Der Test `tests/Effekt.spec.luau` findet vertippte Namen und unsinnige Werte.

Ein Effekt besteht aus **Schichten**, die zusammen wirken. Bewährt sind drei:

1. **Blitz:** ein großes, sehr kurzes Bild (0.1 bis 0.25 s), oft eine Bildfolge. Macht den Moment.
2. **Teilchen:** viele kleine Funken oder Splitter, die wegfliegen (0.2 bis 0.6 s). Machen die Richtung.
3. **Nachklang:** Rauch oder Staub, langsam und blass (0.5 bis 1.5 s). Macht das Gewicht.

Die Felder einer Schicht (`Texture`, `Flipbook`, `Count`, `Lifetime`, `Size`, `Speed`, `Spread`, `Color`, `ColorEnd`, `Fade`, `Glow`, `Gravity`, `Drag`, `Rotation`, `Spin`, `Stretch`) sind im Kopf von `Effects.luau` erklärt.

**Gestapelte Schichten: ein Bild je Farbe.** Die schönsten Effekte bestehen aus mehreren weißen Bildern derselben Form, die genau übereinander liegen und einzeln eingefärbt werden: außen ein weicher Schein, darüber der Körper, ein heller Rand, innen ein fast weißer heißer Kern. Ein einziges Bild kann nur eine Farbe tragen und wirkt wie ein Aufkleber.

```lua
-- Ein Hieb in vier Schichten (vier Bildfolgen 4x4, alle gleich groß gezeichnet)
Slash = {
	Layers = {
		{ Texture = "SlashGlow", Flipbook = 4, Count = 1, Lifetime = { 0.25, 0.25 }, Size = { 7, 7 }, Rotation = { 0, 0 }, Color = { 60, 120, 255 }, Front = 0 },
		{ Texture = "SlashBody", Flipbook = 4, Count = 1, Lifetime = { 0.25, 0.25 }, Size = { 7, 7 }, Rotation = { 0, 0 }, Color = { 90, 170, 255 }, Front = 1 },
		{ Texture = "SlashRim", Flipbook = 4, Count = 1, Lifetime = { 0.25, 0.25 }, Size = { 7, 7 }, Rotation = { 0, 0 }, Color = { 190, 225, 255 }, Front = 2 },
		{ Texture = "SlashCore", Flipbook = 4, Count = 1, Lifetime = { 0.25, 0.25 }, Size = { 7, 7 }, Rotation = { 0, 0 }, Color = { 255, 255, 255 }, Front = 3 },
	},
},
```

Damit die Schichten deckungsgleich bleiben: `Count = 1`, gleiche `Lifetime`, gleiche `Size`, kein `Speed`, feste `Rotation`, aufsteigendes `Front`. Ein anderes Element ist dann nur eine andere Farbtabelle (Feuer: Rot-Orange-Gelb-Weiß; Gift: Dunkelgrün bis Hellgelb; Eis: Blau bis Weiß): dieselben vier Bilder, kein neuer Upload. Die Schlüssel (`SlashGlow` …) in `AssetIds.Effects` ergänzen.

**Ohne eigenes Bild** erscheint das Standard-Partikel von Roblox. Effekte sind also sofort sichtbar und werden schöner, sobald Bilder hochgeladen sind. Erst das Zeitgefühl mit Standard-Partikeln einstellen, dann Bilder machen.

## Dauerhafte Effekte: direkt in Studio

Fackel, Aura, Wasserfall, Schweif am Schwert gehören nicht in den `EffectController`. Sie werden in Studio am Teil gebaut (`execute_luau`): `ParticleEmitter` mit `Rate`, `Beam` zwischen zwei Attachments, `Trail` zwischen zwei Attachments an der Klinge. Ein- und ausschalten per Code über `Enabled`.

| Eigenschaft | Merksatz |
|---|---|
| `Beam.TextureSpeed`, `TextureLength` | lässt das Bild den Strahl entlanglaufen: wirkt wie fließende Energie |
| `Beam.Width0/Width1`, `CurveSize0/1` | Breite an beiden Enden, Bogen |
| `Trail.Lifetime` | Länge des Schweifs in Sekunden (0.15 bis 0.4 für Waffen) |
| `Trail.WidthScale` | läuft mit einer `NumberSequence` nach hinten spitz zu |
| `LightEmission` 1 | leuchtet additiv (Magie, Feuer); 0 für Rauch und Staub |
| `LightInfluence` 0 | Farbe bleibt auch im Dunkeln |
| `Brightness` | über 1 für Kräftiges; mit `Bloom` im Licht-Aufbau strahlt es |

## Gestaltungsregeln

- **Weiß zeichnen, in Roblox einfärben.** Alle Effekt-Bilder sind weiß mit Durchsicht. Ein Bild dient so vielen Effekten, und die Farbe lässt sich im Spiel anpassen.
- **Kurz und kräftig.** Ein Treffer dauert 0.15 bis 0.3 Sekunden. Was länger steht, verdeckt das Spiel.
- **Am Anfang schnell, dann auslaufend.** Größe und Geschwindigkeit starten hoch und bremsen ab (`Drag`); so wirkt ein Schlag wuchtig.
- **Größe am Spieler messen:** Treffer 3 bis 5 Studs, Explosion 10 bis 20, Aufsammeln 2 bis 3.
- **Farbe trägt Bedeutung** und bleibt im ganzen Spiel gleich: z. B. Schaden gelb-weiß, Heilung grün, Gegner-Angriff rot, Belohnung gold.
- **Lesbar bleiben:** Der Spieler muss Gegner und Boden noch sehen. Lieber ein klarer Blitz als eine Wolke.
- **Rand frei:** Die Form darf den Bildrand nie berühren, sonst sieht man im Spiel die Kante des Vierecks.
- **Handy-Budget:** je Effekt höchstens etwa 40 Partikel, große Flächen sparsam (jede Überlagerung kostet), `Effects.MaxActive` begrenzt gleichzeitige Effekte. Bild-Größe 256 für Einzelbilder, 512 für Bildfolgen.
- **Form mit Richtung statt Symmetrie.** Ein Hieb ist kein gleichmäßiger Mond (sieht aus wie eine Banane): dicker Kopf, langer dünner Schweif, beide Enden laufen spitz aus. Ausgefranst wird **entlang der Bewegung** (lange Risse und Fasern in Flussrichtung), nie mit eckigen Stufen quer dazu. Kleine Risse im Inneren lassen es schnell wirken.
- **Bildfolgen haben drei Phasen:** hineinwachsen, stehen, zerfallen. In **jedem** Bild laufen die Enden spitz aus; eine Form, die an einer Bildgrenze abgeschnitten ist, sieht man sofort. Das letzte Bild ist fast leer.
- **Kein Rot, das wie Blut aussieht.** Rote Tropfen oder Spritzer an einem roten Hieb können bei Roblox zu einer Verwarnung des Kontos führen. Rot gibt es nur als Glühen, Flamme oder Rauch.
- **Claude hat keinen Geschmack.** Eine Form kann alle Regeln erfüllen und trotzdem billig aussehen. Zeig dem Nutzer die Vorschau und frag nach seinem Urteil, bevor etwas hochgeladen wird. Sagt er „sieht aus wie ein altes Videospiel", neu zeichnen statt verteidigen.
- **Ton dazu:** Ein Effekt ohne Ton wirkt halb. An derselben Stelle `SoundController:PlayAt` aufrufen.

## Bilder machen

### Weg 1: das Zeichen-Skript (geht immer)

`scripts/effekt_textur.py` braucht nur Python.

```
python <skill>/scripts/effekt_textur.py --liste
python <skill>/scripts/effekt_textur.py funkenstoss --ziel <spiel>/export/effekte --vorschau
python <skill>/scripts/effekt_textur.py alle --ziel <spiel>/export/effekte
```

Einzelbilder: `leuchtpunkt`, `scheibe`, `ring`, `druckwelle`, `funke`, `stern`, `rauch`, `flamme`, `schlagbogen`, `kratzer`, `strahl` (für Beam), `spur` (für Trail), `linie`. Bildfolgen: `ring_waechst`, `verpuffen`, `explosion`, `funkenstoss`, `schlag_wischt`. Schalter: `--groesse`, `--raster 2|4|8`, `--saat` (andere Zufallsform), `--name`, `--vorschau` (eingefärbt auf dunklem Grund, nur zum Ansehen).

Welche Form zu welchem Schlüssel in `AssetIds.Effects` passt, steht dort als Kommentar.

### Weg 2: Blender (Formen mit Tiefe)

Für Splitter, Kristalle, Blitze, Wirbel und alles, was sich im Raum dreht: `assets/kreativ/blender/rbx_vfx.py`. Beispiel: `beispiel_effekt.py`.

```python
import rbx_base as rb, rbx_vfx as vfx
rb.new_scene()
zacken = vfx.spikes("Zacken", count=11, length=0.85, width=0.06, seed=7, mat=vfx.glow_material("ZackenLicht"))
welle  = vfx.ring("Welle", radius=0.8, thickness=0.07, mat=vfx.glow_material("WellenLicht"))

def schritt(t):                      # t läuft von 0 bis 1
    aus = 1 - (1 - t) ** 3           # schnell los, dann auslaufend
    zacken.scale = (0.25 + aus * 0.8, 1, 0.25 + aus * 0.8)
    vfx.set_strength(zacken, max(0, 1 - t * 1.4))
    welle.scale = (0.15 + aus * 0.95, 1, 0.15 + aus * 0.95)
    vfx.set_strength(welle, max(0, 0.9 - t))

vfx.render_sequence(r"<spiel>/export/effekte/Einschlag.png", schritt, grid=4, size=128, glow=0.45)
vfx.preview(r"<spiel>/export/effekte/Einschlag.vorschau.png", r"<spiel>/export/effekte/Einschlag.png")
```

| Funktion | Zweck |
|---|---|
| `vfx.spikes`, `ring`, `orb`, `shards`, `bolt` | fertige leuchtende Formen |
| `vfx.glow_material(name, strength, fade)` | Leuchtmaterial; `fade` `"z"`, `"radial"` (flache Formen), `"soft"` (Kugeln) |
| `vfx.set_strength(obj, wert)` | Helligkeit = Deckkraft, zum Ausblenden |
| `vfx.render(pfad, size, glow)` | Einzelbild |
| `vfx.render_sequence(pfad, schritt, grid, size)` | Bildfolge; `size` = Kante eines Bildes, gesamt höchstens 1024 |
| `vfx.preview(pfad, quelle, color)` | eingefärbt auf dunklem Grund, nur zum Ansehen |

Die Kamera schaut von vorn auf das Quadrat von −1 bis +1 (X und Z). Formen um den Ursprung bauen und innerhalb von 0.9 bleiben. Jede Form braucht ein eigenes Material, wenn sie einzeln ausgeblendet werden soll. Eigene Formen: beliebiges Mesh bauen und ein `glow_material` geben.

### Weg 3: PhotoCraft (Effekte in Schichten zeichnen)

Der Weg für handgemacht wirkende Effekte: Hiebe, Auren, Explosionen, Blitze, Bodenmarken. Claude zeichnet nicht mit der Maus, sondern schreibt den **Umriss als Liste von Punkten**, PhotoCraft füllt ihn. Ein Bildgenerator taugt dafür nicht: Er liefert ein flaches, fertig gefärbtes Bild ohne Schichten und ohne Bewegung.

Einrichtung und Werkzeuge: `kreativ-einrichtung.md`, Abschnitt 2. Befehlsnamen immer mit `command_list` nachschlagen.

**Ablauf für eine Form**

1. `doc_new`: quadratisch, **durchsichtiger** Hintergrund. Zum Arbeiten eine dunkle Hilfsebene ganz unten anlegen (weiß auf durchsichtig erkennt man in der Vorschau schlecht) und vor dem Export ausblenden.
2. **Je Schicht eine eigene Ebene**, sprechend benannt, alles in Weiß:

   | Ebene | Inhalt |
   |---|---|
   | `Glow` | die Form stark weichgezeichnet und etwas größer: der Schein |
   | `Body` | die volle Form |
   | `Rim` | nur die Außenkante, schmal |
   | `Core` | ein schmaler Streifen in der Mitte bzw. an der Vorderkante: der heiße Kern |

3. Die Form als Punktliste anlegen (Vieleck-Auswahl oder Form-Befehl, dann füllen), nach den Gestaltungsregeln oben: Kopf dick, Schweif dünn, Enden spitz, nichts symmetrisch.
4. Ausfransen entlang der Flussrichtung: schmale, lange Keile aus dem Rand herausschneiden, dazu einige dünne Risse im Inneren.
5. `doc_render_preview` ansehen. Sieht es nach Banane, Mond oder angebissen aus: verwerfen (`edit.undo`) und anders ansetzen, nicht weiter verzieren.
6. Dokument mit allen Ebenen nach `quellen/` speichern (`doc_save`, `.pcraft` oder `.psd`).
7. Jede Schicht einzeln als PNG nach `export/effekte/` (`doc_export_layers`, oder Ebenen einzeln einblenden und `doc_export`). Hilfsebene dabei aus.
8. Prüfen: `python <skill>/scripts/effekt_textur.py --pruefen export/effekte/Slash*.png --einzelbild`.

**Bildfolge (4×4, 16 Bilder)**

Ein Hieb ist kein einzelnes Bild. Dokument 512 × 512 mit Hilfslinien alle 128 Bildpunkte; in jede Kachel kommt ein Bild, von links oben zeilenweise nach rechts unten. Verlauf: Bilder 1 bis 4 wachsen hinein, 5 bis 10 stehen und wandern, 11 bis 16 zerfallen in Fasern und verschwinden. Jede Form bleibt mindestens 4 Bildpunkte von ihrem Kachelrand weg und läuft in jedem Bild an beiden Enden spitz aus. Jede Schicht ergibt eine eigene Bildfolge mit denselben Positionen.

Am saubersten: die Punktlisten aller 16 Bilder vorab berechnen (ein Fortschritt t von 0 bis 1 steuert Länge, Dicke und Zerfall) und in einem `command_batch` je Schicht zeichnen. So bleiben die Schichten deckungsgleich.

Prüfen: `python <skill>/scripts/effekt_textur.py --pruefen export/effekte/SlashBody.png --raster 4`

**Bild veredeln statt neu zeichnen:** Ein Bild aus dem Zeichen-Skript oder aus Blender öffnen, Kopie der Ebene weichzeichnen (`filter.blur.gaussianBlur`) für mehr Schein, Kanten nachschärfen, zuschneiden. Bleibt weiß mit Durchsicht.

**Der Prüfer** (`--pruefen`) meldet: Farbe näher als 4 Bildpunkte am Rand (Fehler), fehlende Durchsicht (Fehler), falsche Größe (Fehler), nicht-weiße Flächen, rote Flächen, eine Bildfolge, die nicht leer endet (Hinweise). Für Bänder (Beam, Trail), die links und rechts anschließen sollen: `--nahtlos`.

### Immer: ansehen

Jedes Bild vor dem Hochladen ansehen (die `.vorschau.png` lesen bzw. `doc_render_preview`) und durch den Prüfer schicken (`--pruefen`). Form erkennbar? Rand frei? Bei Bildfolgen: Läuft die Bewegung von Bild zu Bild gleichmäßig, und ist das letzte Bild fast leer? Dann dem Nutzer zeigen und sein Urteil abwarten.

## Vom Bild ins Spiel

1. Bild liegt in `<spiel>/export/effekte/`.
2. **Nutzer fragen**, dann `store_image` → `upload_image` (`kreativ-einrichtung.md`).
3. Nummer in `src/shared/Config/AssetIds.luau` unter `Effects` eintragen (`"rbxassetid://123456"`), in `PLAN.md` unter „Eigene Assets" vermerken.
4. In `Effects.luau` verweist `Texture = "<Schlüssel>"` darauf; bei Bildfolgen `Flipbook = 4` (bzw. 2, 8).
5. **Ansehen in Studio:** `assets/weltbau/effekt_vorschau.luau` zeigt den Effekt dauernd laufend neben einer Vergleichsfigur. `screen_capture`, Zahlen ändern, wiederholen. Einmalige Effekte sind auf einem Bildschirmfoto sonst nie zu sehen.
6. Im Spieltest an der echten Stelle prüfen (Tempo und Ton lassen sich nur dort beurteilen; der Nutzer sieht das besser als ein Standbild).

Bildfolgen laufen mit `FlipbookMode = OneShot` genau einmal über die Lebensdauer des Partikels: `Lifetime` bestimmt also das Tempo.

## Typische Fehler

| Zeichen | Ursache | Abhilfe |
|---|---|---|
| Effekt erscheint gar nicht | Name vertippt, zu weit weg, `MaxActive` erreicht | Ausgabe in Studio lesen (Warnung), Test `Effekt.spec` |
| Graues Quadrat statt Bild | Bild noch in Prüfung oder abgelehnt | einige Minuten warten; sonst anderes Bild |
| Viereckige Kante sichtbar | Form berührt den Bildrand | Form kleiner, 4 Bildpunkte Rand frei lassen; `--pruefen` findet es vorher |
| Schichten liegen versetzt | unterschiedliche `Size`, `Lifetime` oder zufällige `Rotation` | bei allen Schichten gleich setzen, `Rotation = { 0, 0 }` |
| Effekt wirkt wie ein Aufkleber | ein einziges, einfarbiges Bild | in Schichten zeichnen und einzeln einfärben |
| Bildfolge zeigt alle Bilder auf einmal | `Flipbook` fehlt oder falsches Raster | `Flipbook = 4` passend zum Bild |
| Zu grell, alles weiß | zu viele überlagerte, additive Partikel | `Count` senken, `Glow` unter 1, `Fade` früher |
| Im Hellen unsichtbar | additiv auf hellem Grund | `Glow = 0` und kräftigere Farbe |
| Ruckelt auf dem Handy | zu viele oder zu große Partikel | `Count` und `Size` senken, `MaxActive` prüfen |
