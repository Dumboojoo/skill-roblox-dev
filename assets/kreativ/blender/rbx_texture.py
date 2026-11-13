"""Texturen fuer Roblox: abwickeln, backen, ansehen.

Aus den Farben und Materialien eines Modells wird EIN Bild, das alle Teile gemeinsam
benutzen. In Roblox ist das eine einzige Textur (ein Upload) fuer das ganze Modell.

    import rbx_base as rb, rbx_rig as rig, rbx_texture as tex

    teile = rig.parts()                                     # oder eine eigene Liste von Objekten
    tex.unwrap(teile)                                       # alle Teile in ein gemeinsames Bild legen
    tex.bake_color(teile, r"<spiel>/export/Monster_Farbe.png", size=512, shade=0.6)
    tex.apply(teile, r"<spiel>/export/Monster_Farbe.png")   # in Blender ansehen
    rb.preview(r"<spiel>/export/Monster.textur.png")

Danach das PNG bei Bedarf in PhotoCraft veredeln (Kratzer, Verlauf, Schaerfe), hochladen
und in Studio als Textur setzen (assets/weltbau/modell_einbauen.luau).

Wann lohnt sich das? Einfarbige Block-Modelle brauchen KEINE Textur: Die Farbe je Teil
steht im Begleitzettel und wird in Studio gesetzt. Backen lohnt sich, wenn Schattierung,
Muster oder mehrere Farben auf einem Teil gewuenscht sind.

Groessen: 256 fuer kleine Dinge, 512 als Normalfall, 1024 nur fuer grosse, wichtige Modelle.
Roblox verkleinert alles ueber 1024.
"""

from __future__ import annotations

import math
import os

import bpy
import numpy as np

IMAGE_NODE = "rbx_bake_target"


def _select(objects: list[bpy.types.Object]) -> None:
    for obj in bpy.context.scene.objects:
        obj.select_set(False)
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]


def _meshes(objects: list[bpy.types.Object] | None) -> list[bpy.types.Object]:
    source = objects if objects is not None else list(bpy.context.scene.objects)
    result = [obj for obj in source if obj.type == "MESH"]
    if not result:
        raise ValueError("Keine Mesh-Objekte zum Bearbeiten.")
    return result


def unwrap(objects: list[bpy.types.Object] | None = None, margin: float = 0.03, angle: float = 66.0) -> None:
    """Wickelt alle Objekte in EIN gemeinsames Bild ab (jede Flaechengruppe bekommt ihren Platz).

    `margin` ist der Abstand zwischen den Inseln (Anteil der Bildbreite). Zu klein = Farben
    laufen ineinander, wenn Roblox das Bild verkleinert.
    """
    meshes = _meshes(objects)
    for obj in meshes:
        if not obj.data.uv_layers:
            obj.data.uv_layers.new(name="UVMap")
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    _select(meshes)
    bpy.ops.object.mode_set(mode="EDIT")
    try:
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(angle), island_margin=margin, scale_to_bounds=False)
        bpy.ops.uv.pack_islands(margin=margin)
    finally:
        bpy.ops.object.mode_set(mode="OBJECT")


def _target_image(name: str, size: int, color: tuple[float, float, float, float], data: bool) -> bpy.types.Image:
    existing = bpy.data.images.get(name)
    if existing is not None:
        bpy.data.images.remove(existing)
    image = bpy.data.images.new(name, size, size, alpha=True)
    image.generated_color = color
    if data:
        image.colorspace_settings.name = "Non-Color"
    return image


def _add_targets(meshes: list[bpy.types.Object], image: bpy.types.Image) -> list[tuple[bpy.types.Material, bpy.types.Node | None]]:
    """Setzt in jedes Material einen Bild-Knoten als Back-Ziel. Gibt zurueck, was vorher aktiv war."""
    touched: list[tuple[bpy.types.Material, bpy.types.Node | None]] = []
    seen: set[str] = set()
    for obj in meshes:
        if not [slot for slot in obj.material_slots if slot.material is not None]:
            raise ValueError(f'"{obj.name}" hat kein Material. Erst rb.paint(obj, rb.material(...)) aufrufen.')
        for slot in obj.material_slots:
            mat = slot.material
            if mat is None or mat.name in seen:
                continue
            seen.add(mat.name)
            mat.use_nodes = True
            nodes = mat.node_tree.nodes
            previous = nodes.active
            node = nodes.get(IMAGE_NODE) or nodes.new("ShaderNodeTexImage")
            node.name = IMAGE_NODE
            node.image = image
            node.select = True
            nodes.active = node
            touched.append((mat, previous))
    return touched


def _remove_targets(touched: list[tuple[bpy.types.Material, bpy.types.Node | None]]) -> None:
    for mat, previous in touched:
        nodes = mat.node_tree.nodes
        node = nodes.get(IMAGE_NODE)
        if node is not None:
            nodes.remove(node)
        if previous is not None:
            nodes.active = previous


def _pixels(image: bpy.types.Image) -> np.ndarray:
    flat = np.empty(image.size[0] * image.size[1] * 4, dtype=np.float32)
    image.pixels.foreach_get(flat)
    return flat.reshape(image.size[1], image.size[0], 4)


def _save(image: bpy.types.Image, path: str) -> None:
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()


def bake(
    objects: list[bpy.types.Object] | None,
    path: str,
    size: int = 512,
    kind: str = "color",
    samples: int = 16,
    margin: int = 6,
) -> str:
    """Backt eine Karte fuer alle Objekte in ein gemeinsames PNG.

    kind: "color"  = reine Farbe der Materialien (ohne Licht)
          "ao"     = Schattierung in Ecken und Fugen (weiss = frei, dunkel = verdeckt)
          "normal" = Normal-Karte (OpenGL-Art, so wie Roblox sie erwartet)
          "rough"  = Rauheit (weiss = matt, schwarz = spiegelnd)
    Vorher `unwrap` aufrufen. Rechnet auf dem Prozessor (dauert bei 1024 etwas).
    """
    kinds = {
        "color": ("DIFFUSE", (0.0, 0.0, 0.0, 0.0), False),
        "ao": ("AO", (1.0, 1.0, 1.0, 1.0), True),
        "normal": ("NORMAL", (0.5, 0.5, 1.0, 1.0), True),
        "rough": ("ROUGHNESS", (0.8, 0.8, 0.8, 1.0), True),
    }
    if kind not in kinds:
        raise ValueError(f'Unbekannte Karte "{kind}". Erlaubt: {", ".join(kinds)}.')
    if size not in (64, 128, 256, 512, 1024):
        raise ValueError("size muss 64, 128, 256, 512 oder 1024 sein.")
    bake_type, background, is_data = kinds[kind]

    meshes = _meshes(objects)
    for obj in meshes:
        if not obj.data.uv_layers:
            raise ValueError(f'"{obj.name}" ist nicht abgewickelt. Erst rbx_texture.unwrap(...) aufrufen.')

    scene = bpy.context.scene
    saved_engine = scene.render.engine
    image = _target_image(f"rbx_bake_{kind}", size, background, is_data)
    touched = _add_targets(meshes, image)
    try:
        scene.render.engine = "CYCLES"
        scene.cycles.device = "CPU"
        scene.cycles.samples = samples if kind == "ao" else max(1, min(samples, 4))
        _select(meshes)
        if bake_type == "DIFFUSE":
            bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, margin=margin, use_clear=True)
        else:
            bpy.ops.object.bake(type=bake_type, margin=margin, use_clear=True)
        _save(image, path)
    finally:
        _remove_targets(touched)
        scene.render.engine = saved_engine
    bpy.data.images.remove(image)
    return path


def bake_color(
    objects: list[bpy.types.Object] | None,
    path: str,
    size: int = 512,
    shade: float = 0.5,
    samples: int = 48,
) -> str:
    """Farbe mit eingerechneter Schattierung: Das wirkt plastisch, auch ohne Licht im Spiel.

    shade 0 = nur Farbe, 1 = volle Schattierung in Ecken und Fugen. 0.4 bis 0.7 sieht meist gut aus.
    Bei Figuren aus Einzelteilen eher 0.3 bis 0.5: Wo sich Teile am Gelenk ueberdecken, wird es
    dunkel, und diese Stelle kann beim Bewegen sichtbar werden.
    """
    bake(objects, path, size=size, kind="color")
    shadow_path = os.path.splitext(path)[0] + ".schatten.tmp.png"
    color_image = bpy.data.images.load(path, check_existing=False)
    shadow_image = None
    try:
        color = _pixels(color_image)
        used = float((color[:, :, 3] > 0.01).mean())
        if shade > 0:
            bake(objects, shadow_path, size=size, kind="ao", samples=samples)
            shadow_image = bpy.data.images.load(shadow_path, check_existing=False)
            shadow = _pixels(shadow_image)[:, :, :3]
            factor = 1.0 - shade * (1.0 - shadow)
            color[:, :, :3] = np.clip(color[:, :, :3] * factor, 0.0, 1.0)
        color[:, :, 3] = 1.0  # Modell-Texturen brauchen keine Durchsicht; volle Deckung vermeidet helle Raender
        color_image.pixels.foreach_set(color.reshape(-1))
        _save(color_image, path)
    finally:
        bpy.data.images.remove(color_image)
        if shadow_image is not None:
            bpy.data.images.remove(shadow_image)
        if os.path.exists(shadow_path):
            os.remove(shadow_path)
    print(f"Textur: {path}  ({size} x {size}, {used * 100:.0f} % der Flaeche genutzt)")
    if used < 0.35:
        print("  [HINWEIS] Wenig Flaeche genutzt. Kleineres Bild waehlen oder margin in unwrap verkleinern.")
    return path


def apply(objects: list[bpy.types.Object] | None, path: str, name: str = "Textur") -> bpy.types.Material:
    """Gibt allen Objekten ein Material mit diesem Bild (zum Ansehen in Blender).

    Achtung: Danach steckt das Bild auch im .glb. Der Roblox-Import kann es dann gleich
    mitnehmen; sicherer ist, das PNG trotzdem einzeln hochzuladen und in Studio zu setzen.
    """
    meshes = _meshes(objects)
    image = bpy.data.images.load(path, check_existing=True)
    image.reload()
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    mat["rbx_color"] = [255, 255, 255]
    nodes = mat.node_tree.nodes
    shader = nodes.get("Principled BSDF")
    node = nodes.get("rbx_texture") or nodes.new("ShaderNodeTexImage")
    node.name = "rbx_texture"
    node.image = image
    if shader is not None:
        mat.node_tree.links.new(node.outputs["Color"], shader.inputs["Base Color"])
        shader.inputs["Roughness"].default_value = 0.85
    for obj in meshes:
        obj.data.materials.clear()
        obj.data.materials.append(mat)
    return mat
