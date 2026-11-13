"""Grundlagen fuer Roblox-Modelle in Blender: Formen, Material, Ursprung, Vorschau.

Wird IN Blender ausgefuehrt (ueber die Blender-Verbindung oder `blender --python`), z. B.:

    import sys; sys.path.insert(0, r"<skill>/assets/kreativ/blender")
    import rbx_base as rb

    rb.new_scene()
    kiste = rb.box("Kiste", size=(4, 4, 3), center=(0, 0, 1.5), bevel=0.08)
    rb.paint(kiste, rb.material("Holz", (140, 96, 58)))
    rb.preview(r"<spiel>/export/kiste.vorschau.png")

Vereinbarungen (gelten fuer alle rbx_-Module):
  - 1 Blender-Einheit = 1 Stud. Der Einbau in Studio stellt die Groesse danach genau ein.
  - Oben ist +Z. Die VORDERSEITE zeigt nach -Y (Vorderansicht in Blender). Links der Figur ist +X.
  - Das Modell steht auf dem Boden (Z = 0) und mittig ueber dem Welt-Ursprung.
  - Wenige Flaechen, klare Formen: Das passt zum Block-Stil und haelt Roblox schnell.

Bewusst ohne Auswahl- und Modus-Operatoren, wo es geht: So laeuft der Code auch dann
zuverlaessig, wenn er von der Blender-Verbindung im Hintergrund aufgerufen wird.
"""

from __future__ import annotations

import math

import bmesh
import bpy
from mathutils import Matrix, Vector

AXES = {"X": Vector((1, 0, 0)), "Y": Vector((0, 1, 0)), "Z": Vector((0, 0, 1))}


# ---------------------------------------------------------------------------
# Szene
# ---------------------------------------------------------------------------


def new_scene() -> None:
    """Leert die Szene (Objekte und unbenutzte Daten). Die Blender-Verbindung bleibt bestehen."""
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for collection in (bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights, bpy.data.images):
        for block in list(collection):
            if block.users == 0:
                collection.remove(block)
    scene = bpy.context.scene
    scene.unit_settings.system = "NONE"  # reine Einheiten: 1 Einheit = 1 Stud


def remove(obj: bpy.types.Object) -> None:
    mesh = obj.data if obj.type == "MESH" else None
    bpy.data.objects.remove(obj, do_unlink=True)
    if mesh is not None and mesh.users == 0:
        bpy.data.meshes.remove(mesh)


def save(path: str) -> None:
    """Speichert die .blend-Datei (Quelle des Modells, gehoert nach <spiel>/quellen/)."""
    bpy.ops.wm.save_as_mainfile(filepath=path, check_existing=False)


# ---------------------------------------------------------------------------
# Formen
# ---------------------------------------------------------------------------


def _finish(name: str, bm: bmesh.types.BMesh, origin: Vector, smooth: bool = False) -> bpy.types.Object:
    """Macht aus einem bmesh (in Weltkoordinaten) ein Objekt, dessen Ursprung bei `origin` liegt."""
    bmesh.ops.translate(bm, verts=bm.verts, vec=-origin)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for polygon in mesh.polygons:
        polygon.use_smooth = smooth
    obj = bpy.data.objects.new(name, mesh)
    obj.location = origin
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _orient(bm: bmesh.types.BMesh, axis: str) -> None:
    """Dreht eine entlang Z gebaute Form auf die gewuenschte Achse."""
    if axis == "X":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "Y"))
    elif axis == "Y":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(-90), 3, "X"))


def _taper(bm: bmesh.types.BMesh, factor: float, half_height: float) -> None:
    """Verjuengt die Form nach oben (+Z): factor 1 = gerade, 0.5 = oben halb so breit."""
    if factor == 1.0 or half_height <= 0:
        return
    for vert in bm.verts:
        blend = (vert.co.z + half_height) / (2 * half_height)  # 0 unten, 1 oben
        scale = 1.0 + (factor - 1.0) * blend
        vert.co.x *= scale
        vert.co.y *= scale


def _bevel(bm: bmesh.types.BMesh, width: float, segments: int = 1) -> None:
    if width > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=width, segments=segments, affect="EDGES", profile=0.5)


def box(
    name: str,
    size: tuple[float, float, float],
    center: tuple[float, float, float] = (0, 0, 0),
    origin: tuple[float, float, float] | None = None,
    taper: float = 1.0,
    bevel: float = 0.0,
) -> bpy.types.Object:
    """Quader. `taper` verjuengt nach oben, `bevel` bricht die Kanten (wirkt weniger wie ein Klotz)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, verts=bm.verts, vec=size)
    _taper(bm, taper, size[2] / 2)
    _bevel(bm, bevel)
    bmesh.ops.translate(bm, verts=bm.verts, vec=center)
    return _finish(name, bm, Vector(origin if origin is not None else center))


def cylinder(
    name: str,
    radius: float,
    height: float,
    center: tuple[float, float, float] = (0, 0, 0),
    origin: tuple[float, float, float] | None = None,
    segments: int = 8,
    axis: str = "Z",
    taper: float = 1.0,
    smooth: bool = False,
) -> bpy.types.Object:
    """Zylinder mit wenigen Seiten (8 wirkt kantig-stilisiert, 12 bis 16 rund)."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius * taper, depth=height)
    _orient(bm, axis)
    bmesh.ops.translate(bm, verts=bm.verts, vec=center)
    return _finish(name, bm, Vector(origin if origin is not None else center), smooth)


def cone(
    name: str,
    radius: float,
    height: float,
    center: tuple[float, float, float] = (0, 0, 0),
    origin: tuple[float, float, float] | None = None,
    segments: int = 8,
    axis: str = "Z",
) -> bpy.types.Object:
    """Kegel (Spitze in Richtung der Achse). Fuer Hoerner, Stacheln, Zaehne, Daecher."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=0.0, depth=height)
    _orient(bm, axis)
    bmesh.ops.translate(bm, verts=bm.verts, vec=center)
    return _finish(name, bm, Vector(origin if origin is not None else center))


def sphere(
    name: str,
    radius: float,
    center: tuple[float, float, float] = (0, 0, 0),
    origin: tuple[float, float, float] | None = None,
    detail: int = 2,
    scale: tuple[float, float, float] = (1, 1, 1),
    smooth: bool = False,
) -> bpy.types.Object:
    """Kugel aus Dreiecken. detail 1 = 20 Flaechen (kristallartig), 2 = 80, 3 = 320. `scale` staucht sie."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=detail, radius=radius)
    bmesh.ops.scale(bm, verts=bm.verts, vec=scale)
    bmesh.ops.translate(bm, verts=bm.verts, vec=center)
    return _finish(name, bm, Vector(origin if origin is not None else center), smooth)


# ---------------------------------------------------------------------------
# Bearbeiten
# ---------------------------------------------------------------------------


def _children_world(obj: bpy.types.Object) -> list[tuple[bpy.types.Object, Matrix]]:
    return [(child, child.matrix_world.copy()) for child in obj.children]


def set_origin(obj: bpy.types.Object, point: tuple[float, float, float]) -> None:
    """Verlegt den Ursprung (Drehpunkt) an einen Weltpunkt. Die Form und die Kinder bleiben, wo sie sind."""
    bpy.context.view_layer.update()
    children = _children_world(obj)
    world = obj.matrix_world.copy()
    target = Vector(point)
    local_shift = world.inverted() @ target  # neuer Ursprung in bisherigen Objektkoordinaten
    obj.data.transform(Matrix.Translation(-local_shift))
    obj.matrix_world = world @ Matrix.Translation(local_shift)
    bpy.context.view_layer.update()
    for child, matrix in children:
        child.matrix_world = matrix
    bpy.context.view_layer.update()


def bounds(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    """Kleinste und groesste Ecke aller Mesh-Objekte in Weltkoordinaten."""
    bpy.context.view_layer.update()
    low = Vector((math.inf, math.inf, math.inf))
    high = Vector((-math.inf, -math.inf, -math.inf))
    for obj in objects:
        if obj.type != "MESH":
            continue
        for vert in obj.data.vertices:
            world = obj.matrix_world @ vert.co
            low = Vector((min(low.x, world.x), min(low.y, world.y), min(low.z, world.z)))
            high = Vector((max(high.x, world.x), max(high.y, world.y), max(high.z, world.z)))
    if low.x == math.inf:
        return Vector((0, 0, 0)), Vector((0, 0, 0))
    return low, high


def triangles(obj: bpy.types.Object) -> int:
    """Zahl der Dreiecke, wie Roblox sie zaehlt (Vierecke zaehlen doppelt)."""
    return sum(len(polygon.vertices) - 2 for polygon in obj.data.polygons)


def simplify(obj: bpy.types.Object, target: int) -> int:
    """Verringert die Dreiecke eines Objekts auf etwa `target`. Gibt die neue Zahl zurueck.

    Gedacht fuer fertige Modelle aus Bibliotheken oder KI-Generatoren, die viel zu dicht sind.
    Selbst gebaute Block-Formen brauchen das nicht.
    """
    current = triangles(obj)
    if current <= target or current == 0:
        return current
    modifier = obj.modifiers.new("rbx_simplify", "DECIMATE")
    modifier.ratio = max(target / current, 0.001)
    bpy.context.view_layer.update()
    evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = bpy.data.meshes.new_from_object(evaluated)
    obj.modifiers.remove(modifier)
    old = obj.data
    name = old.name
    obj.data = mesh
    if old.users == 0:
        bpy.data.meshes.remove(old)
    mesh.name = name
    return triangles(obj)


def shade(obj: bpy.types.Object, smooth: bool) -> None:
    for polygon in obj.data.polygons:
        polygon.use_smooth = smooth


def mirror_x(obj: bpy.types.Object, name: str) -> bpy.types.Object:
    """Spiegelbildliche Kopie auf der anderen Seite (links <-> rechts). Materialien werden uebernommen."""
    bpy.context.view_layer.update()
    mesh = obj.data.copy()
    mesh.name = name
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.scale(bm, verts=bm.verts, vec=(-1, 1, 1))
    bmesh.ops.reverse_faces(bm, faces=bm.faces)  # Spiegeln dreht die Flaechen um: wieder richtig herum
    bm.to_mesh(mesh)
    bm.free()
    copy = bpy.data.objects.new(name, mesh)
    world = obj.matrix_world.copy()
    location = world.to_translation()
    copy.location = (-location.x, location.y, location.z)
    bpy.context.scene.collection.objects.link(copy)
    for key in obj.keys():
        if key.startswith("rbx_"):
            copy[key] = obj[key]
    return copy


def join(objects: list[bpy.types.Object], name: str, origin: tuple[float, float, float] | None = None) -> bpy.types.Object:
    """Verschmilzt mehrere Objekte zu EINEM Teil (z. B. Kopf + Hoerner + Augen, die sich nie einzeln bewegen)."""
    bpy.context.view_layer.update()
    materials: list[bpy.types.Material] = []
    combined = bmesh.new()
    for obj in objects:
        temp = obj.data.copy()
        temp.transform(obj.matrix_world)
        index_map = {}
        for slot_index, material in enumerate(temp.materials):
            if material is None:
                continue
            if material not in materials:
                materials.append(material)
            index_map[slot_index] = materials.index(material)
        start = len(combined.faces)
        combined.from_mesh(temp)
        combined.faces.ensure_lookup_table()
        for face in combined.faces[start:]:
            face.material_index = index_map.get(face.material_index, 0)
        bpy.data.meshes.remove(temp)

    low, high = bounds(objects)
    center = (low + high) / 2
    result = _finish(name, combined, Vector(origin) if origin is not None else center)
    for material in materials:
        result.data.materials.append(material)
    for obj in objects:
        remove(obj)
    return result


# ---------------------------------------------------------------------------
# Material und UV
# ---------------------------------------------------------------------------


def material(
    name: str,
    color: tuple[int, int, int],
    roughness: float = 0.85,
    metallic: float = 0.0,
    emission: float = 0.0,
) -> bpy.types.Material:
    """Einfarbiges Material. Farbe als (R, G, B) von 0 bis 255, wie in Roblox."""
    existing = bpy.data.materials.get(name)
    mat = existing or bpy.data.materials.new(name)
    mat.use_nodes = True
    rgba = (color[0] / 255, color[1] / 255, color[2] / 255, 1.0)
    mat.diffuse_color = rgba
    mat["rbx_color"] = list(color)
    shader = mat.node_tree.nodes.get("Principled BSDF")
    if shader is not None:
        shader.inputs["Base Color"].default_value = rgba
        shader.inputs["Roughness"].default_value = roughness
        shader.inputs["Metallic"].default_value = metallic
        if emission > 0 and "Emission Color" in shader.inputs:
            shader.inputs["Emission Color"].default_value = rgba
            shader.inputs["Emission Strength"].default_value = emission
    return mat


def paint(obj: bpy.types.Object, mat: bpy.types.Material) -> None:
    """Gibt dem ganzen Objekt genau dieses eine Material (Regel: ein Material je Teil)."""
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def uv_box(obj: bpy.types.Object, studs_per_tile: float = 4.0) -> None:
    """Einfache Wuerfel-Projektion: Jede Flaeche wird von ihrer Hauptrichtung aus abgebildet.

    Gut fuer kachelbare Texturen (Stein, Holz, Metall): `studs_per_tile` Studs entsprechen
    einer Wiederholung. Fuer gebackene Texturen stattdessen rbx_texture.unwrap benutzen.
    """
    mesh = obj.data
    layer = mesh.uv_layers.active or mesh.uv_layers.new(name="UVMap")
    for polygon in mesh.polygons:
        normal = polygon.normal
        dominant = max(range(3), key=lambda index: abs(normal[index]))
        first, second = [index for index in range(3) if index != dominant]
        for loop_index in polygon.loop_indices:
            co = mesh.vertices[mesh.loops[loop_index].vertex_index].co
            layer.data[loop_index].uv = (co[first] / studs_per_tile, co[second] / studs_per_tile)


# ---------------------------------------------------------------------------
# Vorschau
# ---------------------------------------------------------------------------

VIEWS = {
    # Richtung, aus der die Kamera schaut (von der Kamera zum Modell gesehen umgekehrt)
    "schraeg": Vector((0.75, -1.0, 0.55)),
    "vorne": Vector((0.0, -1.0, 0.08)),
    "seite": Vector((1.0, 0.0, 0.08)),
    "hinten": Vector((0.0, 1.0, 0.08)),
    "oben": Vector((0.0, -0.05, 1.0)),
}


def preview(
    path: str,
    objects: list[bpy.types.Object] | None = None,
    view: str = "schraeg",
    size: int = 512,
    samples: int = 12,
) -> str:
    """Rendert ein Vorschaubild des Modells (zum Beurteilen, nicht fuers Spiel).

    Rechnet auf dem Prozessor und laeuft deshalb auch ohne Fenster. Wer ueber die
    Blender-Verbindung arbeitet, kann stattdessen deren Bildschirmfoto benutzen.
    Ansichten: schraeg, vorne, seite, hinten, oben.
    """
    scene = bpy.context.scene
    targets = [obj for obj in (objects or scene.objects) if obj.type == "MESH"]
    low, high = bounds(targets)
    center = (low + high) / 2
    radius = max((high - low).length / 2, 0.5)

    direction = VIEWS.get(view, VIEWS["schraeg"]).normalized()
    camera_data = bpy.data.cameras.new("rbx_preview_cam")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = radius * 2.25
    camera = bpy.data.objects.new("rbx_preview_cam", camera_data)
    camera.location = center + direction * radius * 6
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(camera)

    sun_data = bpy.data.lights.new("rbx_preview_sun", "SUN")
    sun_data.energy = 2.2
    sun = bpy.data.objects.new("rbx_preview_sun", sun_data)
    sun.rotation_euler = (math.radians(50), math.radians(-15), math.radians(30))
    scene.collection.objects.link(sun)

    world = bpy.data.worlds.new("rbx_preview_world")
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    if background is not None:
        background.inputs["Color"].default_value = (0.55, 0.6, 0.68, 1.0)
        background.inputs["Strength"].default_value = 0.7

    render = scene.render
    saved = {
        "engine": render.engine,
        "camera": scene.camera,
        "world": scene.world,
        "x": render.resolution_x,
        "y": render.resolution_y,
        "percentage": render.resolution_percentage,
        "path": render.filepath,
        "transparent": render.film_transparent,
        "format": render.image_settings.file_format,
        "transform": scene.view_settings.view_transform,
        "look": scene.view_settings.look,
    }
    try:
        scene.view_settings.view_transform = "Standard"  # Farben so zeigen, wie sie eingestellt sind
        scene.view_settings.look = "None"
        render.engine = "CYCLES"
        scene.cycles.device = "CPU"
        scene.cycles.samples = samples
        scene.camera = camera
        scene.world = world
        render.resolution_x = render.resolution_y = size
        render.resolution_percentage = 100
        render.film_transparent = False
        render.image_settings.file_format = "PNG"
        render.filepath = path
        bpy.ops.render.render(write_still=True)
    finally:
        render.engine = saved["engine"]
        scene.camera = saved["camera"]
        scene.world = saved["world"]
        render.resolution_x, render.resolution_y = saved["x"], saved["y"]
        render.resolution_percentage = saved["percentage"]
        render.filepath = saved["path"]
        render.film_transparent = saved["transparent"]
        render.image_settings.file_format = saved["format"]
        scene.view_settings.view_transform = saved["transform"]
        scene.view_settings.look = saved["look"]
        bpy.data.objects.remove(camera, do_unlink=True)
        bpy.data.objects.remove(sun, do_unlink=True)
        bpy.data.cameras.remove(camera_data)
        bpy.data.lights.remove(sun_data)
        bpy.data.worlds.remove(world)
    return path
