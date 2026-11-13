"""Beispiel: Effekt-Bilder in Blender rendern (ein Einzelbild und eine Bildfolge).

Ohne Fenster ausfuehren:
    blender -b --factory-startup --python beispiel_effekt.py -- <ausgabeordner>

Erzeugt:
    Splitter.png          Strahlenkranz mit Ring, als einzelnes Partikel-Bild
    Einschlag_Folge.png   16 Bilder (4x4): Zacken schiessen heraus, Ring dehnt sich, alles verblasst
    Blitz.png             gezackter Blitz, z. B. fuer einen Strahl (Beam)
    *.vorschau.png        eingefaerbt auf dunklem Grund, nur zum Ansehen
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import rbx_base as rb  # noqa: E402
import rbx_vfx as vfx  # noqa: E402


def einzelbild(folder: str) -> None:
    rb.new_scene()
    vfx.spikes("Zacken", count=9, length=0.85, width=0.07, seed=3)
    vfx.ring("Ring", radius=0.4, thickness=0.05)
    path = os.path.join(folder, "Splitter.png")
    vfx.render(path, size=256, glow=0.5)
    vfx.preview(os.path.join(folder, "Splitter.vorschau.png"), path)


def bildfolge(folder: str) -> None:
    rb.new_scene()
    kern = vfx.orb("Kern", radius=0.35)
    zacken = vfx.spikes("Zacken", count=11, length=0.85, width=0.06, seed=7, mat=vfx.glow_material("ZackenLicht"))
    welle = vfx.ring("Welle", radius=0.8, thickness=0.07, mat=vfx.glow_material("WellenLicht"))
    splitter = vfx.shards("Splitter", count=14, spread=0.8, size=0.07, seed=5, mat=vfx.glow_material("SplitterLicht"))

    def schritt(t: float) -> None:
        # Am Anfang schnell, dann auslaufend: so wirkt ein Schlag kraeftig.
        out = 1.0 - (1.0 - t) ** 3
        kern.scale = (0.4 + out * 0.9,) * 3
        vfx.set_strength(kern, max(0.0, 1.0 - t * 2.2))
        zacken.scale = (0.25 + out * 0.8, 1.0, 0.25 + out * 0.8)
        vfx.set_strength(zacken, max(0.0, 1.0 - t * 1.4))
        welle.scale = (0.15 + out * 0.95, 1.0, 0.15 + out * 0.95)
        vfx.set_strength(welle, max(0.0, 0.9 - t))
        splitter.scale = (0.2 + out * 0.95, 1.0, 0.2 + out * 0.95)
        splitter.rotation_euler = (0.0, t * 0.6, 0.0)
        vfx.set_strength(splitter, max(0.0, 1.0 - t * 1.1))

    path = os.path.join(folder, "Einschlag_Folge.png")
    vfx.render_sequence(path, schritt, grid=4, size=128, glow=0.45)
    vfx.preview(os.path.join(folder, "Einschlag_Folge.vorschau.png"), path)


def blitz(folder: str) -> None:
    rb.new_scene()
    vfx.bolt("Blitz", start=(0.0, 0.9), end=(0.05, -0.9), width=0.06, kinks=8, seed=4)
    vfx.bolt("Ast", start=(0.05, 0.15), end=(0.55, -0.45), width=0.03, kinks=5, wobble=0.12, seed=9)
    path = os.path.join(folder, "Blitz.png")
    vfx.render(path, size=256, glow=0.7, glow_radius=0.04)
    vfx.preview(os.path.join(folder, "Blitz.vorschau.png"), path, color=(140, 190, 255))


def main() -> None:
    arguments = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    folder = arguments[0] if arguments else os.path.join(os.getcwd(), "export", "effekte")
    os.makedirs(folder, exist_ok=True)
    einzelbild(folder)
    bildfolge(folder)
    blitz(folder)


if __name__ == "__main__":
    main()
