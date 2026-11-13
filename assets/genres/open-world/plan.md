## Phase 1 – Kern spielbar (Open World)

- [ ] Beispielcode läuft: Gebiete werden erkannt und entdeckt, Wegpunkte aktivieren, Schnellreise, Rohstoffe sammeln, Tag/Nacht
- [ ] Position wird gespeichert: verlassen, neu beitreten, man steht wieder dort
- [ ] Was TUT man in der Welt? Kernbeschäftigung festgelegt (Kämpfen → Code aus `rpg-nahkampf`, Bauen → `survival-crafting`, Aufgaben)
- [ ] Wofür sind Rohstoffe und Münzen da? (Herstellen, Händler → Modul `inventar`)
- [ ] Alle paar Minuten etwas Neues zu entdecken (Gebiet, Wegpunkt, Geheimnis)

## Phase 2 – Welt (Open World)

- [ ] Karte grob geplant: 4 bis 6 Gebiete, jedes mit eigener Farbe, Form und Landmarke, die man von Weitem sieht
- [ ] `WorldSpawn`, `Region`-Kästen (Attribute `RegionId`, `DisplayName`), `Waypoint` je Gebiet
- [ ] `ResourceNode`s verteilt (Attribut `Resource`)
- [ ] Streaming eingeschaltet und geprüft (Workspace.StreamingEnabled, Mindest- und Zielradius), wichtige Modelle auf „Atomic" bzw. „Persistent"
- [ ] Auf Handy-Emulator getestet: Welt lädt flüssig nach, keine Löcher im Boden