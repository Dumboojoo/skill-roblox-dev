"""Beispiel: ein Monster aus Einzelteilen, fertig fuer Roblox.

Zeigt den ganzen Ablauf: Teile mit Gelenken bauen, spiegeln, pruefen, Vorschau, Gelenk-Probe,
Export. Als Vorlage fuer eigene Figuren gedacht (Tiere, Roboter, Bosse).

Ohne Fenster ausfuehren:
    blender -b --factory-startup --python beispiel_monster.py -- <ausgabeordner>

Ueber die Blender-Verbindung: den Inhalt von `build()` Schritt fuer Schritt ausfuehren und
zwischendurch per Bildschirmfoto pruefen.
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import rbx_base as rb  # noqa: E402
import rbx_export as ex  # noqa: E402
import rbx_rig as rig  # noqa: E402


def build() -> None:
    rb.new_scene()

    skin = rb.material("Haut", (92, 150, 84))
    belly = rb.material("Bauch", (176, 190, 120))
    dark = rb.material("Dunkel", (52, 70, 56))
    bone = rb.material("Horn", (232, 222, 196))
    glow = rb.material("Auge", (255, 208, 64), emission=2.0)

    # Rumpf: die Wurzel. Der Ursprung liegt an der Huefte; nach oben breiter (kraeftige Schultern).
    torso = rig.part("Torso", size=(3.0, 1.9, 2.6), joint=(0, 0, 2.5), offset=(0, 0, 1.3), mat=skin, taper=1.15, bevel=0.12)

    # Kopf mit Hoernern: Die Hoerner bewegen sich nie einzeln, also verschmelzen sie mit dem Kopf.
    head_shape = rb.box("HeadShape", (2.0, 1.9, 1.7), center=(0, -0.3, 5.8), bevel=0.1)
    rb.paint(head_shape, skin)
    horn_left = rb.cone("HornLeft", 0.28, 0.9, center=(0.75, -0.2, 6.95), segments=6)
    horn_right = rb.cone("HornRight", 0.28, 0.9, center=(-0.75, -0.2, 6.95), segments=6)
    rb.paint(horn_left, skin)
    rb.paint(horn_right, skin)
    head = rig.as_part(rb.join([head_shape, horn_left, horn_right], "Head"), joint=(0, -0.1, 5.0), parent=torso)

    # Augen und Kiefer haengen am Kopf. Eigene Teile, weil sie eine eigene Farbe haben bzw. sich bewegen.
    eye = rig.part("LeftEye", size=(0.42, 0.14, 0.3), joint=(0.48, -1.26, 6.05), parent=head, mat=glow, bevel=0.0)
    rig.mirror_chain(eye, "Left", "Right")
    rig.part("Jaw", size=(1.8, 1.5, 0.5), joint=(0, 0.2, 5.1), offset=(0, -0.62, -0.18), parent=head, mat=dark, bevel=0.08)

    # Bauchplatte: Deko, die fest zum Rumpf gehoert, aber eine andere Farbe braucht.
    rig.part("Belly", size=(1.9, 0.3, 1.7), joint=(0, -0.9, 3.5), parent=torso, mat=belly, bevel=0.08)

    # Linker Arm: Schulter -> Ellbogen. Die Form haengt UNTER dem Gelenk (offset nach -Z).
    upper_arm = rig.part("LeftUpperArm", size=(1.0, 1.0, 1.7), joint=(2.0, 0, 4.7), offset=(0, 0, -0.7), parent=torso, mat=skin)
    lower_arm = rig.part("LeftLowerArm", size=(1.2, 1.2, 1.8), joint=(2.0, 0, 3.25), offset=(0, 0, -0.8), parent=upper_arm, mat=dark, taper=0.85)
    rig.attachment("LeftGrip", (2.0, -0.2, 1.7), parent=lower_arm)
    rig.mirror_chain(upper_arm, "Left", "Right")

    # Linkes Bein: Huefte -> Knie.
    upper_leg = rig.part("LeftUpperLeg", size=(1.15, 1.25, 1.5), joint=(0.8, 0, 2.6), offset=(0, 0, -0.65), parent=torso, mat=skin)
    rig.part("LeftLowerLeg", size=(1.05, 1.5, 1.4), joint=(0.8, 0, 1.3), offset=(0, -0.12, -0.6), parent=upper_leg, mat=dark)
    rig.mirror_chain(upper_leg, "Left", "Right")

    # Schwanz aus drei Gliedern, jedes haengt am vorigen: So kann er wedeln.
    tail1 = rig.part("Tail1", size=(0.9, 1.2, 0.9), joint=(0, 0.85, 2.95), offset=(0, 0.5, 0), parent=torso, mat=skin)
    tail2 = rig.part("Tail2", size=(0.7, 1.1, 0.7), joint=(0, 1.9, 2.95), offset=(0, 0.45, 0), parent=tail1, mat=skin)
    rig.part("Tail3", size=(0.5, 1.0, 0.5), joint=(0, 2.85, 2.95), offset=(0, 0.4, 0), parent=tail2, mat=bone, taper=1.0)

    rig.attachment("HeadTop", (0, -0.3, 7.5), parent=head)
    ex.ground()


def main() -> None:
    arguments = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    folder = arguments[0] if arguments else os.path.join(os.getcwd(), "export")
    os.makedirs(folder, exist_ok=True)

    build()
    rb.preview(os.path.join(folder, "Monster.vorschau.png"))
    rb.preview(os.path.join(folder, "Monster.vorne.png"), view="vorne")
    rig.pose_test(os.path.join(folder, "Monster.pose.png"))
    ex.export("Monster", folder)


if __name__ == "__main__":
    main()
