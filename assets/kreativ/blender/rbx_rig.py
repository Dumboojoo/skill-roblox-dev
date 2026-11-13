"""Figuren aus Einzelteilen: Alles, was sich bewegen soll, ist ein eigenes Teil mit dem Drehpunkt am Gelenk.

So entsteht in Roblox ein Rig, dessen Koerperteile sich einzeln bewegen lassen (im
Animations-Editor oder per Code), ohne Knochen und ohne Verformung.

    import rbx_base as rb, rbx_rig as rig

    rb.new_scene()
    haut = rb.material("Haut", (96, 168, 92))
    torso = rig.part("Torso", size=(3, 2, 3), joint=(0, 0, 4.5), mat=haut)             # Wurzel
    kopf  = rig.part("Head", size=(2.4, 2.2, 2.2), joint=(0, 0, 6), offset=(0, -0.2, 1.1), parent=torso, mat=haut)
    arm   = rig.part("LeftUpperArm", size=(1, 1, 2), joint=(2, 0, 5.6), offset=(0, 0, -0.9), parent=torso, mat=haut)
    hand  = rig.part("LeftLowerArm", size=(0.9, 0.9, 2), joint=(2, 0, 3.8), offset=(0, 0, -0.9), parent=arm, mat=haut)
    rig.mirror_chain(arm, "Left", "Right")                                             # rechter Arm
    rig.attachment("HeadTop", (0, 0, 8.3), parent=kopf)
    rig.pose_test(r"<spiel>/export/monster.pose.png")                                  # sitzen die Gelenke richtig?

Regeln, damit sich die Figur gut bewegt:
  - `joint` ist der Drehpunkt in der Welt (Schulter, Huefte, Halsansatz, Scharnier).
  - `offset` schiebt die Form vom Gelenk weg: Ein Arm haengt UNTER der Schulter (negatives Z).
  - Jedes Teil haengt an genau einem Eltern-Teil; genau ein Teil (meist "Torso") hat keins.
  - Teile ueberlappen am Gelenk etwas, damit beim Drehen keine Luecke aufgeht.
  - Grundhaltung neutral und gerade: Arme haengen, Beine stehen. Drehungen bleiben auf null.
  - Namen ohne Leerzeichen und Umlaute. Links/rechts als "Left"/"Right" im Namen.
  - Gaengige Namen, die der Bewegungs-Baustein im Spiel von selbst erkennt:
      Torso, Head, Jaw, Tail1..TailN,
      LeftUpperArm/LeftLowerArm, LeftUpperLeg/LeftLowerLeg (ebenso Right…),
      Vierbeiner: FrontLeftLeg, FrontRightLeg, BackLeftLeg, BackRightLeg,
      LeftWing, RightWing
"""

from __future__ import annotations

import math

import bpy
from mathutils import Vector

import rbx_base as rb

PART_FLAG = "rbx_part"
ATTACHMENT_FLAG = "rbx_attachment"


def _attach(child: bpy.types.Object, parent: bpy.types.Object | None) -> None:
    """Haengt `child` an `parent`, ohne dass es sich in der Welt bewegt."""
    if parent is None:
        return
    bpy.context.view_layer.update()
    world = child.matrix_world.copy()
    child.parent = parent
    child.matrix_parent_inverse = parent.matrix_world.inverted()
    child.matrix_world = world
    bpy.context.view_layer.update()


def part(
    name: str,
    size: tuple[float, float, float] = (1, 1, 1),
    joint: tuple[float, float, float] = (0, 0, 0),
    offset: tuple[float, float, float] = (0, 0, 0),
    parent: bpy.types.Object | None = None,
    mat: bpy.types.Material | None = None,
    shape: str = "box",
    taper: float = 1.0,
    bevel: float = 0.06,
    segments: int = 8,
    axis: str = "Z",
) -> bpy.types.Object:
    """Ein bewegliches Teil. Der Ursprung liegt am Gelenk, die Form bei Gelenk + offset.

    shape: "box" (size = Breite X, Tiefe Y, Hoehe Z), "cylinder" (size = Durchmesser, -, Laenge
    entlang `axis`), "sphere" (size = Durchmesser je Achse) oder "cone" (wie cylinder, spitz).
    """
    center = tuple(Vector(joint) + Vector(offset))
    if shape == "box":
        obj = rb.box(name, size, center, origin=joint, taper=taper, bevel=bevel)
    elif shape == "cylinder":
        obj = rb.cylinder(name, size[0] / 2, size[2], center, origin=joint, segments=segments, axis=axis, taper=taper)
    elif shape == "cone":
        obj = rb.cone(name, size[0] / 2, size[2], center, origin=joint, segments=segments, axis=axis)
    elif shape == "sphere":
        scale = (1.0, size[1] / size[0], size[2] / size[0])
        obj = rb.sphere(name, size[0] / 2, center, origin=joint, detail=2, scale=scale)
    else:
        raise ValueError(f'Unbekannte Form "{shape}". Erlaubt: box, cylinder, cone, sphere.')
    obj[PART_FLAG] = True
    if mat is not None:
        rb.paint(obj, mat)
    _attach(obj, parent)
    return obj


def as_part(obj: bpy.types.Object, joint: tuple[float, float, float], parent: bpy.types.Object | None = None) -> bpy.types.Object:
    """Macht ein beliebiges Mesh-Objekt (z. B. mit rb.join verschmolzen) zu einem beweglichen Teil."""
    rb.set_origin(obj, joint)
    obj[PART_FLAG] = True
    _attach(obj, parent)
    return obj


def attachment(name: str, position: tuple[float, float, float], parent: bpy.types.Object) -> bpy.types.Object:
    """Andockpunkt (wird in Roblox ein Attachment): Griff, Muendung, Kopf-Oben, Effekt-Stelle."""
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_type = "PLAIN_AXES"
    empty.empty_display_size = 0.3
    empty.location = position
    empty[ATTACHMENT_FLAG] = True
    bpy.context.scene.collection.objects.link(empty)
    _attach(empty, parent)
    return empty


def parts(scene_objects: list[bpy.types.Object] | None = None) -> list[bpy.types.Object]:
    """Alle beweglichen Teile, Eltern vor Kindern."""
    candidates = [obj for obj in (scene_objects or bpy.context.scene.objects) if obj.get(PART_FLAG)]
    ordered: list[bpy.types.Object] = []

    def visit(obj: bpy.types.Object) -> None:
        ordered.append(obj)
        for child in sorted(obj.children, key=lambda item: item.name):
            if child in candidates:
                visit(child)

    for root in sorted((obj for obj in candidates if obj.parent not in candidates), key=lambda item: item.name):
        visit(root)
    return ordered


def attachments(scene_objects: list[bpy.types.Object] | None = None) -> list[bpy.types.Object]:
    return [obj for obj in (scene_objects or bpy.context.scene.objects) if obj.get(ATTACHMENT_FLAG)]


def mirror_chain(root: bpy.types.Object, old: str = "Left", new: str = "Right") -> bpy.types.Object:
    """Spiegelt ein Teil samt allem, was daran haengt, auf die andere Seite und benennt es um.

    Aus LeftUpperArm -> LeftLowerArm -> LeftHand wird RightUpperArm -> RightLowerArm -> RightHand.
    """

    def copy(obj: bpy.types.Object, parent: bpy.types.Object | None) -> bpy.types.Object:
        if old not in obj.name:
            raise ValueError(f'"{obj.name}" enthaelt nicht "{old}" und kann nicht umbenannt werden.')
        name = obj.name.replace(old, new)
        if obj.type == "MESH":
            twin = rb.mirror_x(obj, name)
        else:
            bpy.context.view_layer.update()
            location = obj.matrix_world.to_translation()
            twin = bpy.data.objects.new(name, None)
            twin.empty_display_type = obj.empty_display_type
            twin.empty_display_size = obj.empty_display_size
            twin.location = (-location.x, location.y, location.z)
            bpy.context.scene.collection.objects.link(twin)
            for key in obj.keys():
                if key.startswith("rbx_"):
                    twin[key] = obj[key]
        _attach(twin, parent)
        for child in list(obj.children):
            copy(child, twin)
        return twin

    return copy(root, root.parent)


def pose_test(path: str, angle: float = 35.0, view: str = "schraeg", size: int = 512) -> str:
    """Dreht jedes Gelenk probeweise und rendert ein Bild. Danach steht alles wieder gerade.

    Daran sieht man sofort, ob ein Drehpunkt falsch sitzt (Teil reisst ab oder dreht sich um
    die eigene Mitte statt um das Gelenk) und ob an den Gelenken Luecken aufgehen.
    Linke und rechte Teile werden gegengleich gedreht, wie beim Gehen.
    """
    moved: list[tuple[bpy.types.Object, tuple[float, float, float]]] = []
    for obj in parts():
        if obj.parent is None or not obj.parent.get(PART_FLAG):
            continue
        moved.append((obj, tuple(obj.rotation_euler)))
        sign = -1.0 if ("Right" in obj.name or "Back" in obj.name) else 1.0
        if "Lower" in obj.name:
            sign = 1.0  # Knie und Ellbogen beugen immer in dieselbe Richtung
        obj.rotation_euler = (math.radians(angle) * sign, 0.0, 0.0)
    bpy.context.view_layer.update()
    try:
        rb.preview(path, view=view, size=size)
    finally:
        for obj, rotation in moved:
            obj.rotation_euler = rotation
        bpy.context.view_layer.update()
    return path
