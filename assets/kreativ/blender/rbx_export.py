"""Pruefen und Exportieren fuer Roblox: .glb plus Begleitzettel (<name>.roblox.json).

    import rbx_export as ex

    ex.ground()                                   # Modell auf den Boden und in die Mitte stellen
    bericht = ex.check()                          # nur pruefen
    ex.export("Monster", r"<spiel>/export")       # prueft, exportiert, schreibt den Begleitzettel

Der Begleitzettel sagt dem Einbau in Studio alles, was der Import nicht zuverlaessig
uebertraegt: Groesse in Studs, Farbe je Teil, welches Teil an welchem haengt, wo die
Gelenke und Andockpunkte liegen. Alle Positionen stehen dort schon in Roblox-Achsen
(X rechts, Y oben, Vorderseite -Z), gemessen vom Fusspunkt des Modells.

`assets/weltbau/rig_bauen.luau` bzw. `modell_einbauen.luau` lesen diesen Zettel.
"""

from __future__ import annotations

import json
import os
import re

import bpy
from mathutils import Vector

import rbx_base as rb
import rbx_rig as rig

# Roblox lehnt sehr dichte Meshes ab. Die genaue Grenze nennt die Studio-Anleitung
# "rbx-import-asset"; diese Werte sind bewusst vorsichtig. Block-Stil braucht viel weniger.
TRIANGLES_WARN = 6000
TRIANGLES_ERROR = 20000
TOTAL_TRIANGLES_WARN = 30000
NAME_PATTERN = re.compile(r"^[A-Za-z][A-Za-z0-9_]*$")
TOLERANCE = 0.02


def to_roblox(vector: Vector) -> list[float]:
    """Blender (X, Y, Z; oben Z; vorne -Y) -> Roblox (X, Y, Z; oben Y; vorne -Z), in Studs."""
    return [round(-vector.x, 4), round(vector.z, 4), round(vector.y, 4)]


def size_roblox(vector: Vector) -> list[float]:
    return [round(abs(vector.x), 4), round(abs(vector.z), 4), round(abs(vector.y), 4)]


def _meshes(objects: list[bpy.types.Object] | None) -> list[bpy.types.Object]:
    source = objects if objects is not None else list(bpy.context.scene.objects)
    return [obj for obj in source if obj.type == "MESH" and not obj.name.startswith("rbx_preview")]


def _color(obj: bpy.types.Object) -> list[int]:
    for material in obj.data.materials:
        if material is None:
            continue
        stored = material.get("rbx_color")
        if stored is not None:
            return [int(value) for value in stored]
        return [int(round(channel * 255)) for channel in material.diffuse_color[:3]]
    return [163, 162, 165]


def _inside(point: Vector, low: Vector, high: Vector, margin: float) -> bool:
    return all(low[i] - margin <= point[i] <= high[i] + margin for i in range(3))


def ground(objects: list[bpy.types.Object] | None = None) -> None:
    """Stellt das Modell auf Z = 0 und mittig ueber den Ursprung (verschiebt nur die Wurzel-Objekte)."""
    meshes = _meshes(objects)
    low, high = rb.bounds(meshes)
    shift = Vector((-(low.x + high.x) / 2, -(low.y + high.y) / 2, -low.z))
    everything = objects if objects is not None else list(bpy.context.scene.objects)
    for obj in everything:
        if obj.parent is None:
            obj.location = Vector(obj.location) + shift
    bpy.context.view_layer.update()


def check(objects: list[bpy.types.Object] | None = None, quiet: bool = False) -> dict:
    """Prueft das Modell. Gibt {"errors": [...], "warnings": [...], "info": [...]} zurueck."""
    bpy.context.view_layer.update()
    meshes = _meshes(objects)
    errors: list[str] = []
    warnings: list[str] = []
    info: list[str] = []

    if not meshes:
        errors.append("Kein Mesh-Objekt in der Szene.")
        return {"errors": errors, "warnings": warnings, "info": info}

    # Namen
    seen: dict[str, int] = {}
    for obj in meshes:
        seen[obj.name] = seen.get(obj.name, 0) + 1
        if not NAME_PATTERN.match(obj.name):
            errors.append(f'"{obj.name}": Name darf nur Buchstaben, Ziffern und _ enthalten und muss mit einem Buchstaben beginnen.')
        if re.search(r"\.\d{3}$", obj.name):
            errors.append(f'"{obj.name}": sieht nach einer versehentlichen Kopie aus (Endung .001). Umbenennen oder loeschen.')

    # Groesse, Lage
    low, high = rb.bounds(meshes)
    extent = high - low
    info.append(f"Groesse in Studs (Breite x Hoehe x Tiefe): {abs(extent.x):.2f} x {abs(extent.z):.2f} x {abs(extent.y):.2f}")
    if abs(low.z) > TOLERANCE:
        warnings.append(f"Das Modell steht nicht auf dem Boden (Unterkante bei Z = {low.z:.2f}). rbx_export.ground() aufrufen.")
    if abs(low.x + high.x) / 2 > 0.05 or abs(low.y + high.y) / 2 > 0.05:
        warnings.append("Das Modell steht nicht mittig ueber dem Ursprung. rbx_export.ground() aufrufen.")
    if extent.z < 0.2 or extent.z > 400:
        warnings.append(f"Ungewoehnliche Hoehe ({extent.z:.2f} Studs). Zum Vergleich: Eine Roblox-Figur ist etwa 5 Studs hoch.")

    # Je Teil
    total = 0
    for obj in meshes:
        count = rb.triangles(obj)
        total += count
        if count == 0:
            errors.append(f'"{obj.name}": hat keine Flaechen.')
        elif count > TRIANGLES_ERROR:
            errors.append(f'"{obj.name}": {count} Dreiecke sind zu viele fuer Roblox. Vereinfachen oder aufteilen.')
        elif count > TRIANGLES_WARN:
            warnings.append(f'"{obj.name}": {count} Dreiecke sind viel. Fuer den Block-Stil reichen meist wenige Hundert.')
        scale = obj.matrix_world.to_scale()
        if any(abs(value - 1.0) > 0.001 for value in scale):
            errors.append(f'"{obj.name}": Skalierung ist nicht 1 ({scale.x:.2f}, {scale.y:.2f}, {scale.z:.2f}). Groesse in die Form uebernehmen.')
        if len([material for material in obj.data.materials if material is not None]) > 1:
            warnings.append(f'"{obj.name}": mehrere Materialien. In Roblox bekommt ein Teil EINE Farbe bzw. Textur; sonst Teil aufteilen.')
    info.append(f"Dreiecke gesamt: {total} in {len(meshes)} Teil(en)")
    if total > TOTAL_TRIANGLES_WARN:
        warnings.append(f"{total} Dreiecke insgesamt sind viel fuer ein einzelnes Modell (Handy!).")

    # Figur aus Einzelteilen
    rig_parts = [obj for obj in rig.parts(meshes)]
    if rig_parts:
        roots = [obj for obj in rig_parts if obj.parent is None or not obj.parent.get(rig.PART_FLAG)]
        if len(roots) != 1:
            names = ", ".join(obj.name for obj in roots) or "keins"
            errors.append(f"Eine Figur braucht genau EIN Wurzel-Teil ohne Eltern-Teil (gefunden: {names}).")
        loose = [obj for obj in meshes if not obj.get(rig.PART_FLAG)]
        for obj in loose:
            errors.append(f'"{obj.name}": gehoert zu keinem beweglichen Teil. Mit rb.join an ein Teil schmelzen oder mit rig.as_part selbst zum Teil machen.')
        for obj in rig_parts:
            rotation = obj.matrix_world.to_euler()
            if any(abs(value) > 0.001 for value in rotation):
                errors.append(f'"{obj.name}": ist gedreht. In der Grundhaltung muessen alle Drehungen 0 sein (Form stattdessen gedreht bauen).')
            if obj in roots:
                continue
            joint = obj.matrix_world.to_translation()
            own_low, own_high = rb.bounds([obj])
            parent_low, parent_high = rb.bounds([obj.parent])
            reach = max((own_high - own_low).length * 0.15, 0.15)
            if not _inside(joint, own_low, own_high, reach):
                warnings.append(f'"{obj.name}": Das Gelenk liegt weit ausserhalb der eigenen Form. Dreht es sich wirklich um diesen Punkt?')
            if not _inside(joint, parent_low, parent_high, reach):
                warnings.append(f'"{obj.name}": Das Gelenk liegt nicht am Eltern-Teil "{obj.parent.name}". Beim Drehen entsteht dort eine Luecke.')
            touching = all(own_low[i] <= parent_high[i] + TOLERANCE and parent_low[i] <= own_high[i] + TOLERANCE for i in range(3))
            if not touching:
                warnings.append(f'"{obj.name}": beruehrt das Eltern-Teil "{obj.parent.name}" nicht. Teile sollen am Gelenk leicht ueberlappen.')
        info.append(f"Figur: {len(rig_parts)} bewegliche Teile, Wurzel: {roots[0].name if roots else '?'}")
        for empty in rig.attachments():
            if empty.parent is None or not empty.parent.get(rig.PART_FLAG):
                errors.append(f'Andockpunkt "{empty.name}": haengt an keinem beweglichen Teil.')

    if not quiet:
        print(report_text({"errors": errors, "warnings": warnings, "info": info}))
    return {"errors": errors, "warnings": warnings, "info": info}


def report_text(report: dict) -> str:
    lines = []
    for text in report["info"]:
        lines.append(f"  [INFO]    {text}")
    for text in report["warnings"]:
        lines.append(f"  [HINWEIS] {text}")
    for text in report["errors"]:
        lines.append(f"  [FEHLER]  {text}")
    if not report["errors"] and not report["warnings"]:
        lines.append("  [OK]      Modell ist bereit fuer Roblox.")
    return "\n".join(lines)


def describe(name: str, objects: list[bpy.types.Object] | None = None) -> dict:
    """Der Inhalt des Begleitzettels."""
    bpy.context.view_layer.update()
    meshes = _meshes(objects)
    low, high = rb.bounds(meshes)
    rig_parts = rig.parts(meshes)
    is_rig = len(rig_parts) > 1  # ein einzelnes Teil mit Andockpunkten (Waffe) ist kein Rig
    ordered = rig_parts if rig_parts else sorted(meshes, key=lambda obj: obj.name)

    entries = []
    for obj in ordered:
        own_low, own_high = rb.bounds([obj])
        parent = obj.parent.name if obj.parent is not None and obj.parent.get(rig.PART_FLAG) else None
        entries.append(
            {
                "Name": obj.name,
                "Parent": parent,
                "Joint": to_roblox(obj.matrix_world.to_translation()),
                "Center": to_roblox((own_low + own_high) / 2),
                "Size": size_roblox(own_high - own_low),
                "Color": _color(obj),
                "Triangles": rb.triangles(obj),
            }
        )

    points = []
    for empty in rig.attachments():
        points.append(
            {
                "Name": empty.name,
                "Part": empty.parent.name if empty.parent is not None else None,
                "Position": to_roblox(empty.matrix_world.to_translation()),
            }
        )

    return {
        "Format": 1,
        "Name": name,
        "Kind": "Rig" if is_rig else "Static",
        "SizeStuds": size_roblox(high - low),
        "CenterStuds": to_roblox((low + high) / 2),
        "Root": ordered[0].name if rig_parts else None,
        "Triangles": sum(entry["Triangles"] for entry in entries),
        "Parts": entries,
        "Attachments": points,
    }


def export(
    name: str,
    folder: str,
    objects: list[bpy.types.Object] | None = None,
    file_format: str = "glb",
    force: bool = False,
) -> dict:
    """Prueft, exportiert <name>.glb (oder .fbx) und schreibt <name>.roblox.json in `folder`.

    Bei Fehlern wird nichts geschrieben (ausser mit force=True). Rueckgabe: Pfade und Bericht.
    """
    if not NAME_PATTERN.match(name):
        raise ValueError(f'Name "{name}" darf nur Buchstaben, Ziffern und _ enthalten.')
    report = check(objects)
    if report["errors"] and not force:
        raise RuntimeError("Export abgebrochen, erst die Fehler beheben:\n" + report_text(report))

    os.makedirs(folder, exist_ok=True)
    meshes = _meshes(objects)

    # Auswahl setzen: Die Export-Operatoren arbeiten auf der Auswahl.
    for obj in bpy.context.scene.objects:
        obj.select_set(False)
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]

    model_path = os.path.join(folder, f"{name}.{file_format}")
    if file_format == "glb":
        bpy.ops.export_scene.gltf(
            filepath=model_path,
            export_format="GLB",
            use_selection=True,
            export_apply=True,
            export_yup=True,
            export_animations=False,
        )
    elif file_format == "fbx":
        bpy.ops.export_scene.fbx(
            filepath=model_path,
            use_selection=True,
            object_types={"MESH"},
            apply_scale_options="FBX_SCALE_ALL",
            bake_anim=False,
            mesh_smooth_type="FACE",
        )
    else:
        raise ValueError('file_format muss "glb" oder "fbx" sein.')

    sheet_path = os.path.join(folder, f"{name}.roblox.json")
    sheet = describe(name, objects)
    with open(sheet_path, "w", encoding="utf-8") as handle:
        json.dump(sheet, handle, indent=2, ensure_ascii=False)

    print(f"Exportiert: {model_path}")
    print(f"Begleitzettel: {sheet_path}  ({sheet['Kind']}, {len(sheet['Parts'])} Teil(e), {sheet['Triangles']} Dreiecke)")
    return {"model": model_path, "sheet": sheet_path, "report": report, "data": sheet}
