"""Effekt-Bilder in Blender rendern: leuchtende 3D-Formen vor durchsichtigem Hintergrund.

Fuer alles, was das einfache Zeichen-Skript (scripts/effekt_textur.py) nicht kann:
Splitter, Kristalle, Blitze, Wirbel, Formen mit Tiefe und Drehung. Heraus kommt ein
weisses Bild mit Durchsicht (oder eine Bildfolge im Raster), die Farbe kommt in Roblox.

    import rbx_base as rb, rbx_vfx as vfx

    rb.new_scene()
    vfx.spikes("Zacken", count=9, length=0.9, width=0.09, seed=3)     # Formen liegen in der X-Z-Ebene
    vfx.ring("Ring", radius=0.45, thickness=0.05)
    vfx.render(r"<spiel>/export/effekte/Splitter.png", size=256, glow=0.5)

Bildfolge (Flipbook): eine Funktion aendert die Szene je nach Fortschritt t (0 bis 1).

    def schritt(t):
        zacken.scale = (0.2 + t, 1, 0.2 + t)
        vfx.set_strength(zacken, 1.0 - t)                              # verblasst
    vfx.render_sequence(r"<spiel>/export/effekte/Splitter_Folge.png", schritt, grid=4, size=128)

Vereinbarungen:
  - Die Kamera schaut von vorn (-Y) auf die X-Z-Ebene und zeigt das Quadrat von -1 bis +1.
    Formen also um den Ursprung bauen und innerhalb von etwa 0.9 bleiben (Rand frei lassen).
  - Helligkeit wird zu Deckkraft: hell = deckend, dunkel = durchsichtig.
  - Raster nur 2, 4 oder 8 (Roblox kennt 2x2, 4x4, 8x8). Gesamtbild hoechstens 1024.
"""

from __future__ import annotations

import math
import os
import random
import tempfile

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

import rbx_base as rb

CAMERA = "rbx_vfx_cam"
STRENGTH_NODE = "rbx_strength"
GLOW_GAIN = 2.2  # duenne Formen verlieren beim Weichzeichnen Helligkeit; das gleicht es aus


# ---------------------------------------------------------------------------
# Leuchtendes Material
# ---------------------------------------------------------------------------


def glow_material(name: str = "Leuchten", strength: float = 1.0, fade: str = "") -> bpy.types.Material:
    """Selbstleuchtendes Weiss. `strength` 0 bis 1 = Deckkraft im fertigen Bild.

    fade: ""       gleichmaessig hell
          "z"      von unten (hell) nach oben (durchsichtig) auslaufend, je Objekt
          "radial" von der Objektmitte nach aussen auslaufend (fuer FLACHE Formen wie Scheiben)
          "soft"   Mitte hell, Rand der Form durchsichtig (fuer Kugeln und runde Koerper)
    """
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    tree = mat.node_tree
    tree.nodes.clear()
    output = tree.nodes.new("ShaderNodeOutputMaterial")
    emission = tree.nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = (1, 1, 1, 1)
    value = tree.nodes.new("ShaderNodeValue")
    value.name = STRENGTH_NODE
    value.outputs[0].default_value = strength
    tree.links.new(emission.outputs["Emission"], output.inputs["Surface"])

    if fade in ("z", "radial", "soft"):
        multiply = tree.nodes.new("ShaderNodeMath")
        multiply.operation = "MULTIPLY"
        if fade == "soft":
            # Zur Kamera gewandte Flaechen hell, Rand der Form durchsichtig: weiche Kugel
            facing = tree.nodes.new("ShaderNodeLayerWeight")
            facing.inputs["Blend"].default_value = 0.5
            invert = tree.nodes.new("ShaderNodeMath")
            invert.operation = "SUBTRACT"
            invert.inputs[0].default_value = 1.0
            power = tree.nodes.new("ShaderNodeMath")
            power.operation = "POWER"
            power.inputs[1].default_value = 1.6
            tree.links.new(facing.outputs["Facing"], invert.inputs[1])
            tree.links.new(invert.outputs[0], power.inputs[0])
            tree.links.new(power.outputs[0], multiply.inputs[0])
        else:
            coords = tree.nodes.new("ShaderNodeTexCoord")
            gradient = tree.nodes.new("ShaderNodeTexGradient")
            mapping = tree.nodes.new("ShaderNodeMapping")
            if fade == "z":
                # "Generated" laeuft je Objekt von 0 bis 1; Z auf die Verlaufs-Achse legen und umdrehen
                mapping.inputs["Rotation"].default_value = (0.0, math.radians(90), 0.0)
                mapping.inputs["Location"].default_value = (1.0, 0.0, 0.0)
                gradient.gradient_type = "LINEAR"
            else:
                mapping.inputs["Location"].default_value = (-1.0, -1.0, -1.0)
                mapping.inputs["Scale"].default_value = (2.0, 2.0, 2.0)
                gradient.gradient_type = "SPHERICAL"
            tree.links.new(coords.outputs["Generated"], mapping.inputs["Vector"])
            tree.links.new(mapping.outputs["Vector"], gradient.inputs["Vector"])
            tree.links.new(gradient.outputs["Fac"], multiply.inputs[0])
        tree.links.new(value.outputs[0], multiply.inputs[1])
        tree.links.new(multiply.outputs[0], emission.inputs["Strength"])
    else:
        tree.links.new(value.outputs[0], emission.inputs["Strength"])
    return mat


def set_strength(target: bpy.types.Object | bpy.types.Material, strength: float) -> None:
    """Aendert die Helligkeit (= Deckkraft) eines leuchtenden Materials, z. B. zum Ausblenden."""
    materials = [target] if isinstance(target, bpy.types.Material) else [slot.material for slot in target.material_slots]
    for mat in materials:
        if mat is None or mat.node_tree is None:
            continue
        node = mat.node_tree.nodes.get(STRENGTH_NODE)
        if node is not None:
            node.outputs[0].default_value = max(0.0, strength)


def _lit(obj: bpy.types.Object, mat: bpy.types.Material | None) -> bpy.types.Object:
    rb.paint(obj, mat or glow_material())
    return obj


# ---------------------------------------------------------------------------
# Formen (alle um den Ursprung, in der X-Z-Ebene)
# ---------------------------------------------------------------------------


def spikes(
    name: str,
    count: int = 8,
    length: float = 0.9,
    width: float = 0.08,
    inner: float = 0.05,
    jitter: float = 0.35,
    seed: int = 1,
    mat: bpy.types.Material | None = None,
) -> bpy.types.Object:
    """Strahlenkranz aus spitzen Zacken (Einschlag, Funkenstoss, Stern). `jitter` macht ihn unregelmaessig."""
    rng = random.Random(seed)
    bm = bmesh.new()
    for index in range(count):
        angle = (index / count) * math.tau + rng.uniform(-jitter, jitter) * (math.tau / count)
        reach = length * (1.0 - jitter * rng.random() * 0.6)
        half = width * (0.6 + 0.8 * rng.random())
        points = [(-half, 0.0, inner), (half, 0.0, inner), (0.0, 0.0, reach), (0.0, -half, inner), (0.0, half, inner)]
        rotation = Matrix.Rotation(angle, 4, "Y")
        verts = [bm.verts.new(rotation @ Vector(point)) for point in points]
        bm.faces.new((verts[0], verts[1], verts[2]))
        bm.faces.new((verts[3], verts[4], verts[2]))
    return _lit(rb._finish(name, bm, Vector((0, 0, 0))), mat)


def ring(
    name: str,
    radius: float = 0.6,
    thickness: float = 0.06,
    segments: int = 48,
    mat: bpy.types.Material | None = None,
) -> bpy.types.Object:
    """Flacher Ring (Druckwelle, Aura, Zielkreis). Mit Drehung um X wird daraus eine Ellipse mit Tiefe."""
    bm = bmesh.new()
    inner = [bm.verts.new((math.cos(i / segments * math.tau) * (radius - thickness / 2), 0.0, math.sin(i / segments * math.tau) * (radius - thickness / 2))) for i in range(segments)]
    outer = [bm.verts.new((math.cos(i / segments * math.tau) * (radius + thickness / 2), 0.0, math.sin(i / segments * math.tau) * (radius + thickness / 2))) for i in range(segments)]
    for i in range(segments):
        j = (i + 1) % segments
        bm.faces.new((inner[i], inner[j], outer[j], outer[i]))
    return _lit(rb._finish(name, bm, Vector((0, 0, 0))), mat)


def orb(name: str, radius: float = 0.4, mat: bpy.types.Material | None = None) -> bpy.types.Object:
    """Leuchtkugel mit weichem Rand (Kern einer Explosion, Energie-Ball)."""
    obj = rb.sphere(name, radius, detail=3, smooth=True)
    return _lit(obj, mat or glow_material("LeuchtenWeich", 1.0, fade="soft"))


def shards(
    name: str,
    count: int = 12,
    spread: float = 0.75,
    size: float = 0.12,
    seed: int = 1,
    mat: bpy.types.Material | None = None,
) -> bpy.types.Object:
    """Lose Splitter (Truemmer, Scherben, Kristallstaub), zufaellig gedreht und verteilt."""
    rng = random.Random(seed)
    bm = bmesh.new()
    for _ in range(count):
        angle = rng.random() * math.tau
        distance = spread * math.sqrt(rng.random())
        center = Vector((math.cos(angle) * distance, rng.uniform(-0.2, 0.2), math.sin(angle) * distance))
        scale = size * (0.5 + rng.random())
        spin = Matrix.Rotation(rng.random() * math.tau, 4, Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))).normalized())
        points = [Vector((0, 0, 1.4)), Vector((-0.5, -0.3, -0.5)), Vector((0.5, -0.3, -0.5)), Vector((0, 0.5, -0.5))]
        verts = [bm.verts.new(center + (spin @ point) * scale) for point in points]
        for face in ((0, 1, 2), (0, 2, 3), (0, 3, 1), (1, 3, 2)):
            bm.faces.new([verts[i] for i in face])
    return _lit(rb._finish(name, bm, Vector((0, 0, 0))), mat)


def bolt(
    name: str,
    start: tuple[float, float] = (0.0, 0.9),
    end: tuple[float, float] = (0.0, -0.9),
    width: float = 0.05,
    kinks: int = 7,
    wobble: float = 0.22,
    seed: int = 1,
    mat: bpy.types.Material | None = None,
) -> bpy.types.Object:
    """Gezackte Linie von start nach end, jeweils (X, Z): Blitz, Riss, Energie-Faden."""
    rng = random.Random(seed)
    a = Vector((start[0], 0.0, start[1]))
    b = Vector((end[0], 0.0, end[1]))
    along = (b - a).normalized()
    side = Vector((along.z, 0.0, -along.x))
    points = []
    for index in range(kinks + 1):
        t = index / kinks
        offset = 0.0 if index in (0, kinks) else rng.uniform(-wobble, wobble)
        points.append(a.lerp(b, t) + side * offset)
    bm = bmesh.new()
    rows = []
    for index, point in enumerate(points):
        t = index / kinks
        half = width * (1.0 - 0.75 * t)  # zum Ende hin duenner
        rows.append((bm.verts.new(point - side * half), bm.verts.new(point + side * half)))
    for index in range(kinks):
        bm.faces.new((rows[index][0], rows[index][1], rows[index + 1][1], rows[index + 1][0]))
    return _lit(rb._finish(name, bm, Vector((0, 0, 0))), mat)


# ---------------------------------------------------------------------------
# Rendern
# ---------------------------------------------------------------------------


def _camera() -> bpy.types.Object:
    camera = bpy.data.objects.get(CAMERA)
    if camera is None:
        data = bpy.data.cameras.new(CAMERA)
        data.type = "ORTHO"
        data.ortho_scale = 2.0
        camera = bpy.data.objects.new(CAMERA, data)
        bpy.context.scene.collection.objects.link(camera)
    camera.location = (0.0, -10.0, 0.0)
    camera.rotation_euler = (math.radians(90), 0.0, 0.0)
    return camera


def _render_pixels(size: int, samples: int) -> np.ndarray:
    """Rendert die Szene und gibt (Hoehe, Breite, 4) zurueck, Zeile 0 = oben."""
    scene = bpy.context.scene
    render = scene.render
    saved = {
        "engine": render.engine,
        "camera": scene.camera,
        "x": render.resolution_x,
        "y": render.resolution_y,
        "percentage": render.resolution_percentage,
        "path": render.filepath,
        "transparent": render.film_transparent,
        "format": render.image_settings.file_format,
        "mode": render.image_settings.color_mode,
        "transform": scene.view_settings.view_transform,
        "look": scene.view_settings.look,
    }
    handle, temp_path = tempfile.mkstemp(suffix=".png", prefix="rbx_vfx_")
    os.close(handle)
    try:
        render.engine = "CYCLES"
        scene.cycles.device = "CPU"
        scene.cycles.samples = samples
        scene.cycles.use_denoising = False
        scene.camera = _camera()
        scene.view_settings.view_transform = "Standard"  # Helligkeit unverfaelscht ins Bild
        scene.view_settings.look = "None"
        render.resolution_x = render.resolution_y = size
        render.resolution_percentage = 100
        render.film_transparent = True
        render.image_settings.file_format = "PNG"
        render.image_settings.color_mode = "RGBA"
        render.filepath = temp_path
        bpy.ops.render.render(write_still=True)
        image = bpy.data.images.load(temp_path, check_existing=False)
        try:
            flat = np.empty(size * size * 4, dtype=np.float32)
            image.pixels.foreach_get(flat)
        finally:
            bpy.data.images.remove(image)
    finally:
        render.engine = saved["engine"]
        scene.camera = saved["camera"]
        render.resolution_x, render.resolution_y = saved["x"], saved["y"]
        render.resolution_percentage = saved["percentage"]
        render.filepath = saved["path"]
        render.film_transparent = saved["transparent"]
        render.image_settings.file_format = saved["format"]
        render.image_settings.color_mode = saved["mode"]
        scene.view_settings.view_transform = saved["transform"]
        scene.view_settings.look = saved["look"]
        if os.path.exists(temp_path):
            os.remove(temp_path)
    return flat.reshape(size, size, 4)[::-1].copy()


def _blur(values: np.ndarray, radius: int) -> np.ndarray:
    """Weichzeichnen (drei Kasten-Durchgaenge je Richtung, wirkt wie ein Gauss)."""
    if radius < 1:
        return values
    result = values.astype(np.float32)
    width = radius * 2 + 1
    kernel = np.ones(width, dtype=np.float32) / width
    for _ in range(3):
        padded = np.pad(result, ((0, 0), (radius, radius)), mode="constant")
        result = np.apply_along_axis(lambda row: np.convolve(row, kernel, mode="valid"), 1, padded)
        padded = np.pad(result, ((radius, radius), (0, 0)), mode="constant")
        result = np.apply_along_axis(lambda column: np.convolve(column, kernel, mode="valid"), 0, padded)
    return result


def _to_alpha(pixels: np.ndarray, glow: float, glow_radius: float) -> np.ndarray:
    """Helligkeit -> Deckkraft. Dazu ein weicher Schein um die Form."""
    brightness = pixels[:, :, :3].max(axis=2) * pixels[:, :, 3]
    alpha = np.clip(brightness, 0.0, 1.0)
    if glow > 0:
        radius = max(1, int(round(pixels.shape[0] * glow_radius)))
        halo = np.clip(_blur(alpha, radius) * GLOW_GAIN, 0.0, 1.0)
        alpha = np.clip(np.maximum(alpha, halo * glow), 0.0, 1.0)
    alpha[alpha < 2.0 / 255.0] = 0.0
    return alpha


EDGE_MARGIN = 4  # so viele Bildpunkte am Rand bleiben ganz leer (sonst sieht man im Spiel die Kante des Vierecks)


def _edge_fade(alpha: np.ndarray, border: float = 0.06) -> np.ndarray:
    """Blendet zum Bildrand aus; die aeussersten EDGE_MARGIN Bildpunkte werden ganz durchsichtig."""
    size = alpha.shape[0]
    distance = np.minimum(np.arange(size), np.arange(size)[::-1]).astype(np.float32)
    ramp = np.clip((distance - EDGE_MARGIN + 1) / max(1.0, size * border), 0.0, 1.0)
    mask = np.minimum.outer(ramp, ramp)
    faded = alpha * mask
    faded[(mask < 1.0) & (faded < 9.0 / 255.0)] = 0.0  # kein kaum sichtbarer Schleier bis an die Kante
    return faded


def _write(alpha: np.ndarray, path: str) -> None:
    height, width = alpha.shape
    pixels = np.ones((height, width, 4), dtype=np.float32)
    pixels[:, :, 3] = alpha
    image = bpy.data.images.new("rbx_vfx_out", width, height, alpha=True)
    try:
        image.alpha_mode = "STRAIGHT"
        image.pixels.foreach_set(pixels[::-1].reshape(-1))
        os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
        image.filepath_raw = path
        image.file_format = "PNG"
        image.save()
    finally:
        bpy.data.images.remove(image)


def _report(alpha: np.ndarray, path: str, note: str) -> None:
    used = float((alpha > 0.02).mean())
    print(f"Effekt-Bild: {path}  ({alpha.shape[1]} x {alpha.shape[0]}{note}, {used * 100:.0f} % sichtbar)")
    if used < 0.04:
        print("  [HINWEIS] Fast leer. Form groesser bauen oder Helligkeit erhoehen.")


def render(path: str, size: int = 256, glow: float = 0.4, glow_radius: float = 0.05, samples: int = 16) -> str:
    """Rendert die Szene als weisses Bild mit Durchsicht.

    glow 0 = harte Kanten, 0.4 = sanfter Schein, 1 = starker Schein. glow_radius = Breite des
    Scheins als Anteil der Bildbreite.
    """
    if size not in (64, 128, 256, 512, 1024):
        raise ValueError("size muss 64, 128, 256, 512 oder 1024 sein.")
    alpha = _edge_fade(_to_alpha(_render_pixels(size, samples), glow, glow_radius))
    _write(alpha, path)
    _report(alpha, path, "")
    return path


def render_sequence(
    path: str,
    update,
    grid: int = 4,
    size: int = 128,
    glow: float = 0.4,
    glow_radius: float = 0.05,
    samples: int = 12,
) -> str:
    """Rendert grid x grid Bilder in ein Raster (Flipbook). `update(t)` stellt die Szene fuer t = 0..1 ein.

    size = Kantenlaenge EINES Bildes. grid 4 und size 128 ergeben 512 x 512, ein guter Normalfall.
    In Roblox: FlipbookLayout Grid4x4 (bzw. 2x2, 8x8), FlipbookMode OneShot.
    """
    if grid not in (2, 4, 8):
        raise ValueError("grid muss 2, 4 oder 8 sein.")
    if size * grid > 1024:
        raise ValueError(f"Gesamtbild waere {size * grid} Pixel breit. Hoechstens 1024: size oder grid verkleinern.")
    frames = grid * grid
    sheet = np.zeros((size * grid, size * grid), dtype=np.float32)
    for index in range(frames):
        update(index / (frames - 1))
        bpy.context.view_layer.update()
        alpha = _edge_fade(_to_alpha(_render_pixels(size, samples), glow, glow_radius))
        row, column = divmod(index, grid)
        sheet[row * size : (row + 1) * size, column * size : (column + 1) * size] = alpha
    _write(sheet, path)
    _report(sheet, path, f", Raster {grid}x{grid}")
    return path


def preview(path: str, source: str, color: tuple[int, int, int] = (255, 170, 60)) -> str:
    """Faerbt ein fertiges Effekt-Bild ein und legt es auf dunklen Grund: So sieht es im Spiel etwa aus."""
    image = bpy.data.images.load(source, check_existing=False)
    try:
        width, height = image.size
        flat = np.empty(width * height * 4, dtype=np.float32)
        image.pixels.foreach_get(flat)
    finally:
        bpy.data.images.remove(image)
    alpha = flat.reshape(height, width, 4)[:, :, 3]
    ground = np.array([0.07, 0.08, 0.11], dtype=np.float32)
    tint = np.array(color, dtype=np.float32) / 255.0
    out = np.ones((height, width, 4), dtype=np.float32)
    out[:, :, :3] = ground + (tint - ground) * alpha[:, :, None]
    result = bpy.data.images.new("rbx_vfx_preview", width, height, alpha=False)
    try:
        result.pixels.foreach_set(out.reshape(-1))
        result.filepath_raw = path
        result.file_format = "PNG"
        result.save()
    finally:
        bpy.data.images.remove(result)
    return path
