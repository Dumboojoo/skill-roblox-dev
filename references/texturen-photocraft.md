# Texturen: backen in Blender, bearbeiten in PhotoCraft

Lies das, wenn ein Modell mehr als eine glatte Farbe je Teil bekommen soll, wenn eine Oberfläche in der Welt eine eigene Textur braucht oder wenn ein Bild in PhotoCraft bearbeitet wird. Einrichtung: `references/kreativ-einrichtung.md`.

## Erst fragen: Braucht es überhaupt eine Textur?

| Wunsch | Bester Weg | Aufwand |
|---|---|---|
| Einfarbige Teile im Block-Stil | **keine Textur**: Farbe je Teil aus dem Begleitzettel, Material in Studio (`SmoothPlastic`, `Metal`, `Neon` …) | keiner |
| Stein, Holz, Gras, Metall in der Welt | Roblox-Materialien, bei Bedarf `MaterialVariant` | gering |
| Plastische Schattierung, Muster, mehrere Farben auf einem Teil | **Textur backen** (dieser Text) | ein Upload |
| Schmutz, Kratzer, Verlauf, Schrift, Leuchtränder | gebackene Textur in **PhotoCraft** veredeln | ein Upload |
| Glanz, Rillen, Metall-Wirkung | Karten für `SurfaceAppearance` (Farbe, Normal, Rauheit, Metall) | bis zu vier Uploads |

Jede Textur kostet Speicher auf dem Handy und einen Upload, der geprüft wird. Im Zweifel die einfachere Stufe nehmen.

## Regeln für Bilder in Roblox

- **Größe:** Kantenlängen 64, 128, 256, 512 oder 1024. Größeres verkleinert Roblox auf 1024. Normalfall 512; 256 für Kleines; 1024 nur für große, wichtige Modelle.
- **Format:** PNG. Modell-Texturen ohne Durchsicht (voll deckend), sonst entstehen helle Ränder.
- **Eine Textur für das ganze Modell.** Alle Teile teilen sich ein Bild (ein gemeinsamer Abwickel-Plan). Das ist ein Upload statt siebzehn.
- **Abstand zwischen den Flächen im Bild** lassen (`margin`), sonst laufen Farben ineinander, sobald Roblox das Bild für die Ferne verkleinert.
- **Kachelbare Texturen** (Boden, Wand) müssen an allen vier Rändern nahtlos anschließen.

## Textur backen in Blender

```python
import sys; sys.path.insert(0, r"<skill>/assets/kreativ/blender")
import rbx_base as rb, rbx_rig as rig, rbx_texture as tex

teile = rig.parts()                                       # oder eine eigene Liste von Objekten
tex.unwrap(teile)                                         # alle Teile in EIN gemeinsames Bild legen
tex.bake_color(teile, r"<spiel>/export/Monster_Farbe.png", size=512, shade=0.5)
tex.apply(teile, r"<spiel>/export/Monster_Farbe.png")     # zur Kontrolle in Blender anzeigen
rb.preview(r"<spiel>/export/Monster.textur.png")
```

| Funktion | Zweck |
|---|---|
| `tex.unwrap(objekte, margin=0.03)` | wickelt alle Objekte in ein gemeinsames Bild ab |
| `tex.bake_color(objekte, pfad, size, shade)` | Farbe der Materialien plus Schattierung in Ecken und Fugen. `shade` 0 = nur Farbe, 1 = stark |
| `tex.bake(objekte, pfad, size, kind=…)` | einzelne Karte: `"color"`, `"ao"` (Schattierung), `"normal"`, `"rough"` |
| `tex.apply(objekte, pfad)` | gibt allen Objekten das Bild als Material (Kontrolle) |

Hinweise:

- **Reihenfolge:** erst die Form fertig bauen und prüfen, dann abwickeln und backen. Nach jeder Formänderung neu abwickeln.
- **`shade` bei beweglichen Figuren** eher 0.3 bis 0.5. Wo sich Teile am Gelenk überdecken, wird es dunkel, und diese Stelle kann beim Bewegen sichtbar werden.
- Die Ausgabe nennt, wie viel Fläche des Bildes genutzt ist. Unter 35 % ist Platz verschenkt: kleineres Bild wählen.
- Nach `tex.apply` steckt das Bild auch im `.glb`. Ob der Import es mitnimmt, zeigt sich in Studio; verlässlich ist, das PNG einzeln hochzuladen und über `OPTIONS.Texture` zu setzen.
- Das Backen rechnet auf dem Prozessor. 512 dauert Sekunden, 1024 deutlich länger.
- Mit Textur in Studio `Colors = false` setzen: Die Farbe kommt dann aus dem Bild.

**Bibliothek statt selbst backen:** Mit der Community-Verbindung liefert Poly Haven fertige, freie Texturen (Stein, Holz, Metall, Stoff) samt Normal- und Rauheits-Karte. Auf 512 oder 1024 verkleinern. Für kachelnde Flächen in Blender `rb.uv_box(obj, studs_per_tile=4)` verwenden: Eine Kachel entspricht dann 4 Studs.

## Veredeln in PhotoCraft

PhotoCraft ist ein freies Bildprogramm im Stil von Photoshop mit eingebauter Verbindung zu Claude (`kreativ-einrichtung.md`, Abschnitt 2). Claude kann damit Ebenen anlegen, Formen und Pinselstriche aus Punktlisten zeichnen, auswählen, füllen, Filter und Farbkorrekturen anwenden, das Ergebnis ansehen (`doc_render_preview`) und exportieren. Für Modell-Texturen ist es vor allem die Nachbearbeitung; wie man damit Effekte zeichnet, steht in `effekte.md`.

Befehle nie raten: mit `command_list {filter: "…"}` den genauen Namen und die Parameter holen, mit `command_run` ausführen, vor Versuchen `image.duplicate` (Arbeit auf einer Kopie). Die Tabelle unten nennt die Arbeitsschritte, nicht die genauen Befehlsnamen.

**Grundablauf**

1. Bild aus `<spiel>/export/` öffnen (`doc_open`).
2. **Nie die Ausgangsebene zerstören:** duplizieren und auf der Kopie arbeiten, oder Einstellungsebenen benutzen.
3. Schritte anwenden (Tabelle unten).
4. Zwischendurch ansehen (`doc_render_preview`) und mit `doc_inspect` prüfen, was wirklich passiert ist.
5. Als Dokument mit Ebenen speichern (`doc_save`, `.pcraft` oder `.psd`), zum späteren Weiterarbeiten.
6. Als PNG exportieren (`doc_export`), **Größe und Durchsicht prüfen**. Geschrieben wird nur in den freigegebenen Schreib-Ordner; liegt der auf `export/`, die Arbeitsdatei danach nach `quellen/` verschieben.

**Was sich gut machen lässt**

| Ziel | Vorgehen |
|---|---|
| Farbe treffen | Farbton/Sättigung, Helligkeit/Kontrast, Gradationskurve |
| Plastischer | Kontrast leicht erhöhen; Kopie der Ebene weichzeichnen und mit „Multiplizieren" oder „Weiches Licht" darüberlegen |
| Leuchtrand, Glühen | Kopie weichzeichnen (Gaußscher Weichzeichner), Ebenenmodus „Negativ multiplizieren" oder „Aufhellen" |
| Verlauf (unten dunkler, oben heller) | Verlaufsebene mit „Weiches Licht" und geringer Deckkraft |
| Schmutz, Körnung | Rausch-Filter auf einer grauen Ebene, Modus „Überlagern", Deckkraft 10 bis 25 % |
| Schärfe für kleine Bilder | Unscharf maskieren, sparsam |
| Kachelbar machen | Verschieben-Filter um die halbe Bildbreite, sichtbare Naht ausbessern, zurückschieben |
| Rauheits- oder Metall-Karte ableiten | Farbkarte entsättigen, Kontrast anpassen, als eigenes PNG exportieren |
| Zuschnitt, Größe | auf 256/512/1024 skalieren, Rand frei lassen |

**Regeln**

- **Effekt-Bilder bleiben weiß mit Durchsicht.** In PhotoCraft nur Form und Weichheit ändern, nicht einfärben; die Farbe kommt in Roblox (`effekte.md`).
- **Modell-Texturen: Flächen nicht verschieben.** Die Lage der Flächen im Bild gehört zum Modell. Erlaubt ist alles, was an Ort und Stelle wirkt (Farbe, Kontrast, Körnung). Verzerren, Drehen und Zuschneiden zerstören die Zuordnung.
- **Filter über Flächengrenzen** (starker Weichzeichner) lassen Farben in Nachbarflächen laufen. Schwach dosieren.
- Nach jedem Export prüfen: Kantenlänge noch eine Zweierpotenz? Durchsicht erhalten (Effekte) bzw. keine Durchsicht (Modelle)?

**Ohne PhotoCraft** (nicht installiert, Verbindung streikt): Die gebackene Textur und die Effekt-Bilder sind auch unbearbeitet brauchbar. Farbe und Schattierung lassen sich schon beim Backen einstellen (Materialfarben, `shade`), Glühen bei Effekten über `glow` in `rbx_vfx` bzw. über `LightEmission` in Roblox. Dem Nutzer sagen, dass die Veredelung entfällt, und weitermachen.

## Hochladen und in Studio setzen

Vorher den Nutzer fragen (`kreativ-einrichtung.md`, Abschnitt 3). Dann `store_image` → `upload_image`, Nummer notieren.

| Ziel | So wird gesetzt |
|---|---|
| Ganze Figur | `rig_bauen.luau`: `OPTIONS.Texture = "rbxassetid://…"`, `Colors = false` |
| Modell ohne Gelenke, einfache Textur | `modell_einbauen.luau`: `OPTIONS.Texture` |
| Modell mit Glanz und Rillen | `modell_einbauen.luau`: `ColorMap`, `NormalMap`, `RoughnessMap`, `MetalnessMap` (erzeugt je Teil eine `SurfaceAppearance`) |
| Fläche in der Welt (Schild, Bodenmuster) | `Decal` (einmal) oder `Texture` (gekachelt, `StudsPerTileU/V`) auf dem Part |
| Bild in der Oberfläche | `ImageLabel.Image`; Nummer in `AssetIds.Images` |

Nummern für Bilder, die der Code benutzt, gehören nach `src/shared/Config/AssetIds.luau` (`Textures`, `Images`); alle Uploads zusätzlich in die Tabelle „Eigene Assets" in `PLAN.md`.

**Karten für `SurfaceAppearance`**

| Karte | Inhalt | Aus Blender |
|---|---|---|
| `ColorMap` | Farbe | `tex.bake_color` |
| `NormalMap` | Rillen und Kanten als Licht-Trick (OpenGL-Art) | `tex.bake(kind="normal")` |
| `RoughnessMap` | weiß = matt, schwarz = spiegelnd | `tex.bake(kind="rough")` |
| `MetalnessMap` | weiß = Metall, schwarz = kein Metall | in PhotoCraft aus der Farbkarte ableiten |

Normal-Karten lohnen sich nur, wenn im Material wirklich Struktur steckt (Bibliotheks-Material, Relief). Bei glatten Block-Formen ist die Karte einfarbig und überflüssig.

Nach dem Setzen: `screen_capture` in Studio. Sitzt die Textur richtig, ist sie scharf genug, passt die Helligkeit zur Welt? Dunkle Texturen wirken in Roblox oft dunkler als in Blender: eher etwas heller backen.
