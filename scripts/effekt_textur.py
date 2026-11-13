#!/usr/bin/env python3
"""Zeichnet Grundformen fuer Effekte (Partikel, Strahlen, Spuren) als PNG mit Durchsichtigkeit.

Laeuft ohne Fremdprogramme und ohne Zusatzpakete (nur Python-Standardbibliothek). Das ist der Weg,
der immer geht. Blender (assets/kreativ/blender/rbx_vfx.py) und PhotoCraft machen es schoener.

    python effekt_textur.py --liste
    python effekt_textur.py leuchtpunkt --ziel export/effekte
    python effekt_textur.py rauch --groesse 512 --saat 7 --vorschau
    python effekt_textur.py ring_waechst --raster 4 --groesse 512      # Bildfolge (Flipbook)
    python effekt_textur.py alle --ziel export/effekte --vorschau      # der ganze Standard-Satz

Die Bilder sind WEISS mit Durchsichtigkeit. Die Farbe bekommt der Effekt erst in Roblox
(ParticleEmitter.Color, Beam.Color). So laesst sich ein Bild fuer viele Effekte verwenden.

--vorschau schreibt zusaetzlich <name>.vorschau.png: dasselbe Bild eingefaerbt auf dunklem Grund.
Nur zum Ansehen (weiss auf durchsichtig erkennt man sonst schlecht); hochgeladen wird das Original.
"""

from __future__ import annotations

import argparse
import math
import struct
import sys
import zlib
from pathlib import Path
from typing import Callable

# Eine Form bekommt: u, v von -1 bis 1 (Bildmitte = 0), t von 0 bis 1 (Fortschritt einer Bildfolge),
# und einen Rausch-Erzeuger. Sie gibt die Deckkraft von 0 bis 1 zurueck.
Shape = Callable[[float, float, float, "Noise"], float]


# ---------------------------------------------------------------------------
# Hilfen
# ---------------------------------------------------------------------------


def clamp(value: float, low: float = 0.0, high: float = 1.0) -> float:
    return low if value < low else high if value > high else value


def smoothstep(edge0: float, edge1: float, value: float) -> float:
    if edge0 == edge1:
        return 0.0 if value < edge0 else 1.0
    x = clamp((value - edge0) / (edge1 - edge0))
    return x * x * (3.0 - 2.0 * x)


def gauss(distance: float, width: float) -> float:
    return math.exp(-(distance * distance) / (2.0 * width * width))


class Noise:
    """Einfaches, wiederholbares Rauschen (gleiche Saat = gleiches Bild)."""

    def __init__(self, seed: int) -> None:
        self.seed = seed & 0xFFFFFFFF
        self._rays: dict[int, list[tuple[float, float, float]]] = {}

    def rays(self, count: int) -> list[tuple[float, float, float]]:
        """`count` Strahlen rundum mit leicht zufaelligem Winkel und Reichweite: (cos, sin, Reichweite)."""
        if count not in self._rays:
            result = []
            for index in range(count):
                angle = (index + self._hash(index, 7) * 0.7) * (2 * math.pi / count)
                result.append((math.cos(angle), math.sin(angle), 0.45 + 0.5 * self._hash(index, 3)))
            self._rays[count] = result
        return self._rays[count]

    def _hash(self, x: int, y: int) -> float:
        n = (x * 374761393 + y * 668265263 + self.seed * 1442695041) & 0xFFFFFFFF
        n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
        return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0

    def value(self, x: float, y: float, period: int = 0) -> float:
        """Weiches Rauschen 0..1. period > 0: wiederholt sich nahtlos nach `period` Einheiten."""
        x0, y0 = math.floor(x), math.floor(y)
        fx, fy = x - x0, y - y0
        fx = fx * fx * (3.0 - 2.0 * fx)
        fy = fy * fy * (3.0 - 2.0 * fy)

        def corner(ix: int, iy: int) -> float:
            if period > 0:
                ix %= period
                iy %= period
            return self._hash(ix, iy)

        top = corner(x0, y0) + (corner(x0 + 1, y0) - corner(x0, y0)) * fx
        bottom = corner(x0, y0 + 1) + (corner(x0 + 1, y0 + 1) - corner(x0, y0 + 1)) * fx
        return top + (bottom - top) * fy

    def fbm(self, x: float, y: float, octaves: int = 4, period: int = 0) -> float:
        """Mehrere Schichten Rauschen uebereinander (wolkig). Ergebnis 0..1."""
        total, amplitude, scale, norm = 0.0, 0.5, 1.0, 0.0
        for _ in range(octaves):
            total += amplitude * self.value(x * scale, y * scale, int(period * scale) if period else 0)
            norm += amplitude
            amplitude *= 0.5
            scale *= 2.0
        return total / norm


# ---------------------------------------------------------------------------
# Einzelbilder
# ---------------------------------------------------------------------------


def leuchtpunkt(u: float, v: float, t: float, noise: Noise) -> float:
    """Weicher Lichtpunkt. Der Alleskoenner: Funken, Gluehen, Magie, Muendungsfeuer."""
    r = math.hypot(u, v)
    return clamp(1.0 - r) ** 2.2


def scheibe(u: float, v: float, t: float, noise: Noise) -> float:
    """Runde Scheibe mit weichem Rand. Fuer Tropfen, Blasen, Konfetti."""
    return 1.0 - smoothstep(0.78, 0.9, math.hypot(u, v))


def ring(u: float, v: float, t: float, noise: Noise) -> float:
    """Duenner, weicher Ring. Fuer Treffer, Aufschlag, Auswahl-Markierung."""
    return gauss(math.hypot(u, v) - 0.72, 0.06)


def druckwelle(u: float, v: float, t: float, noise: Noise) -> float:
    """Ring mit auslaufender Innenseite. Fuer Explosionen und Landungen."""
    r = math.hypot(u, v)
    outer = 1.0 - smoothstep(0.82, 0.92, r)
    inner = smoothstep(0.2, 0.86, r) ** 3
    return outer * inner


def funke(u: float, v: float, t: float, noise: Noise) -> float:
    """Vierzackiger Lichtblitz. Fuer Glitzern, Schuesse, Magie."""
    r = math.hypot(u, v)
    fade = clamp(1.0 - r) ** 1.5
    rays = gauss(v, 0.035) * gauss(u, 0.55) + gauss(u, 0.035) * gauss(v, 0.55)
    return clamp(rays * fade * 1.4 + gauss(r, 0.12))


def stern(u: float, v: float, t: float, noise: Noise) -> float:
    """Fuenfzackiger Stern. Fuer Belohnungen, Level-Aufstieg, Sammelobjekte."""
    r = math.hypot(u, v)
    angle = math.atan2(u, -v)  # 0 = Spitze nach oben
    outer, inner = 0.88, 0.38
    segment = math.pi / 5
    # Winkel zur naechsten Spitze (0 = Spitze, segment = innere Ecke).
    theta = abs(((angle + segment) % (2 * segment)) - segment)
    # Gerade Kante von der Spitze zur inneren Ecke, als Abstand vom Mittelpunkt ausgedrueckt.
    edge = (outer * inner * math.sin(segment)) / (outer * math.sin(theta) + inner * math.sin(segment - theta))
    return 1.0 - smoothstep(edge - 0.04, edge + 0.015, r)


def rauch(u: float, v: float, t: float, noise: Noise) -> float:
    """Wolkiger Ballen. Fuer Rauch, Staub, Dampf, Nebel."""
    r = math.hypot(u, v)
    cloud = noise.fbm(u * 2.6 + 11.0, v * 2.6 + 5.0, 5)
    shape = 1.0 - smoothstep(0.25, 0.95, r + (cloud - 0.5) * 0.55)
    return clamp(shape * (0.45 + cloud * 0.75))


def flamme(u: float, v: float, t: float, noise: Noise) -> float:
    """Tropfenfoermige Flamme, unten breit, oben spitz. Fuer Feuer und Fackeln."""
    height = (0.86 - v) / 1.76  # 0 am Fuss, 1 an der Spitze (v zeigt im Bild nach unten)
    if height <= 0.0 or height >= 1.0:
        return 0.0
    # Tropfenform: unten rund und breit, nach oben spitz zulaufend.
    width = 1.12 * math.sqrt(height) * (1.0 - height) ** 0.95
    wobble = (noise.fbm(u * 2.5 + 3.0, v * 2.5 - 7.0, 4) - 0.5) * 0.5 * height
    body = 1.0 - smoothstep(width * 0.35, width, abs(u + wobble))
    # Heller Kern unten, nach oben duenner werdend.
    return clamp(body * (0.5 + 0.7 * (1.0 - height) ** 1.2))


def schlagbogen(u: float, v: float, t: float, noise: Noise) -> float:
    """Sichel wie die Spur eines Schwerthiebs. Fuer Nahkampf-Schlaege."""
    r = math.hypot(u, v - 0.38)
    angle = math.atan2(u, -(v - 0.38))  # 0 = nach oben
    span = 1.15
    along = clamp(1.0 - abs(angle) / span)
    thickness = 0.02 + 0.12 * along**0.7
    band = gauss(r - 0.9, thickness)
    return clamp(band * smoothstep(0.0, 0.25, along))


def kratzer(u: float, v: float, t: float, noise: Noise) -> float:
    """Drei schraege Krallenspuren. Fuer Monster-Angriffe."""
    total = 0.0
    for offset in (-0.38, 0.0, 0.38):
        x = u * 0.94 + v * 0.34 - offset
        y = -u * 0.34 + v * 0.94
        length = clamp(1.0 - abs(y) / 0.85)
        total += gauss(x, 0.012 + 0.07 * length) * smoothstep(0.0, 0.2, length)
    return clamp(total)


def strahl(u: float, v: float, t: float, noise: Noise) -> float:
    """Leuchtband, links und rechts nahtlos. Fuer Beam (Laser, Blitz, Verbindungslinie)."""
    flicker = 0.75 + 0.5 * noise.fbm((u + 1.0) * 4.0, 0.5, 3, period=8)
    return clamp(gauss(v, 0.16) * flicker + gauss(v, 0.05))


def spur(u: float, v: float, t: float, noise: Noise) -> float:
    """Band, das nach rechts auslaeuft. Fuer Trail (Schweif hinter Geschossen, Waffen, Fuessen)."""
    along = (u + 1.0) * 0.5
    width = 0.42 * (1.0 - along) ** 0.7 + 0.02
    return clamp(gauss(v, width * 0.5) * (1.0 - along) ** 1.3)


def linie(u: float, v: float, t: float, noise: Noise) -> float:
    """Kurzer Strich mit spitzen Enden. Fuer Regen, Geschwindigkeitslinien, Funkenflug."""
    length = clamp(1.0 - abs(u) / 0.92)
    return clamp(gauss(v, 0.01 + 0.05 * length) * smoothstep(0.0, 0.3, length))


# ---------------------------------------------------------------------------
# Bildfolgen (t laeuft von 0 bis 1 ueber alle Bilder)
# ---------------------------------------------------------------------------


def ring_waechst(u: float, v: float, t: float, noise: Noise) -> float:
    """Ring dehnt sich aus und verblasst. Fuer Aufschlaege, Heilung, Faehigkeiten."""
    r = math.hypot(u, v)
    radius = 0.12 + 0.76 * (1.0 - (1.0 - t) ** 2)
    width = 0.09 * (1.0 - t) + 0.02
    return clamp(gauss(r - radius, width) * (1.0 - t) ** 0.8)


def verpuffen(u: float, v: float, t: float, noise: Noise) -> float:
    """Rauchballen quillt auf und loest sich auf. Fuer Explosionsrauch, Staub beim Landen."""
    r = math.hypot(u, v)
    grow = 0.35 + 0.6 * (1.0 - (1.0 - t) ** 2)
    cloud = noise.fbm(u * 2.4 + 4.0, v * 2.4 + 9.0 - t * 1.2, 5)
    shape = 1.0 - smoothstep(grow * 0.35, grow, r + (cloud - 0.5) * 0.5)
    # Von innen heraus aufloesen: Was unter der steigenden Schwelle liegt, verschwindet.
    dissolve = smoothstep(t * 0.9 - 0.15, t * 0.9 + 0.15, cloud)
    return clamp(shape * dissolve * (0.5 + cloud * 0.7))


def explosion(u: float, v: float, t: float, noise: Noise) -> float:
    """Heller Kern, dann zerfasernde Wolke. Fuer Explosionen und starke Treffer."""
    r = math.hypot(u, v)
    core = clamp(1.0 - r / (0.25 + 0.5 * t)) ** 1.5 * (1.0 - t) ** 3 * 1.6
    return clamp(core + verpuffen(u, v, t, noise) * smoothstep(0.0, 0.2, t))


def funkenstoss(u: float, v: float, t: float, noise: Noise) -> float:
    """Strahlen schiessen nach aussen. Fuer Treffer, Einschlaege, Aufsammeln."""
    r = math.hypot(u, v)
    if r > 1.05:
        return 0.0
    rays = 0.0
    for cos_a, sin_a, reach in noise.rays(9):
        # Lage des Bildpunkts entlang des Strahls und quer dazu.
        along_ray = u * cos_a + v * sin_a
        if along_ray <= 0.0:
            continue
        across = -u * sin_a + v * cos_a
        head = reach * (1.0 - (1.0 - t) ** 2)
        tail = head * (0.25 + 0.6 * t)
        along = smoothstep(tail - 0.05, tail + 0.05, along_ray) * (1.0 - smoothstep(head - 0.03, head + 0.05, along_ray))
        if along > 0.0:
            rays += gauss(across, 0.022) * along
    flash = clamp(1.0 - r / 0.35) ** 2 * (1.0 - t) ** 4
    return clamp((rays * (1.0 - t) ** 0.6 + flash) * 1.2)


def schlag_wischt(u: float, v: float, t: float, noise: Noise) -> float:
    """Sichel wischt von links nach rechts durch. Fuer Schwerthiebe mit Bewegung."""
    r = math.hypot(u, v - 0.38)
    angle = math.atan2(u, -(v - 0.38))
    span = 1.15
    head = -span + 2.0 * span * (1.0 - (1.0 - t) ** 1.6) * 1.15
    behind = head - angle
    visible = smoothstep(0.0, 0.08, behind) * (1.0 - smoothstep(0.5, 1.5, behind))
    edge = clamp(1.0 - abs(angle) / span)
    band = gauss(r - 0.9, 0.02 + 0.11 * visible * edge**0.5)
    return clamp(band * visible * smoothstep(0.0, 0.2, edge) * (1.0 - t**3))


SHAPES: dict[str, Shape] = {
    "leuchtpunkt": leuchtpunkt,
    "scheibe": scheibe,
    "ring": ring,
    "druckwelle": druckwelle,
    "funke": funke,
    "stern": stern,
    "rauch": rauch,
    "flamme": flamme,
    "schlagbogen": schlagbogen,
    "kratzer": kratzer,
    "strahl": strahl,
    "spur": spur,
    "linie": linie,
}

SEQUENCES: dict[str, Shape] = {
    "ring_waechst": ring_waechst,
    "verpuffen": verpuffen,
    "explosion": explosion,
    "funkenstoss": funkenstoss,
    "schlag_wischt": schlag_wischt,
}

# Roblox kennt genau diese Raster fuer Bildfolgen.
FLIPBOOK_LAYOUTS = {2: "Grid2x2", 4: "Grid4x4", 8: "Grid8x8"}


# ---------------------------------------------------------------------------
# Zeichnen und Speichern
# ---------------------------------------------------------------------------


def render_alpha(shape: Shape, size: int, t: float, noise: Noise) -> list[bytearray]:
    """Eine Kachel als Liste von Zeilen mit Deckkraft 0..255."""
    rows: list[bytearray] = []
    step = 2.0 / size
    for y in range(size):
        v = -1.0 + (y + 0.5) * step
        row = bytearray(size)
        for x in range(size):
            u = -1.0 + (x + 0.5) * step
            value = shape(u, v, t, noise)
            row[x] = 0 if value <= 0.0 else 255 if value >= 1.0 else int(value * 255.0 + 0.5)
        rows.append(row)
    return rows


def render_image(name: str, size: int, grid: int, seed: int) -> list[bytearray]:
    """Ganzes Bild als Zeilen mit Deckkraft. grid > 1: Bildfolge aus grid x grid Kacheln."""
    noise = Noise(seed)
    if name in SHAPES:
        return render_alpha(SHAPES[name], size, 0.0, noise)

    shape = SEQUENCES[name]
    tile = size // grid
    frames = grid * grid
    rows = [bytearray(size) for _ in range(size)]
    for frame in range(frames):
        # t erreicht im letzten Bild knapp 1, damit das letzte Bild nicht ganz leer ist.
        t = frame / frames
        tile_rows = render_alpha(shape, tile, t, noise)
        left = (frame % grid) * tile
        top = (frame // grid) * tile
        for y, tile_row in enumerate(tile_rows):
            rows[top + y][left : left + tile] = tile_row
    return rows


def png_bytes(width: int, height: int, color_type: int, scanlines: list[bytes]) -> bytes:
    def chunk(kind: bytes, data: bytes) -> bytes:
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + line for line in scanlines)  # Filter 0 je Zeile
    header = struct.pack(">IIBBBBB", width, height, 8, color_type, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


def write_white_alpha(path: Path, alpha_rows: list[bytearray]) -> None:
    """Weiss mit Durchsichtigkeit (RGBA). Das ist die Datei fuer Roblox."""
    size = len(alpha_rows)
    lines = []
    for row in alpha_rows:
        line = bytearray(b"\xff" * (size * 4))
        line[3::4] = row
        lines.append(bytes(line))
    path.write_bytes(png_bytes(size, size, 6, lines))


def write_preview(path: Path, alpha_rows: list[bytearray], grid: int) -> None:
    """Eingefaerbt auf dunklem Grund, mit Hilfslinien zwischen den Kacheln einer Bildfolge (RGB)."""
    size = len(alpha_rows)
    tile = size // grid if grid > 1 else size
    tint = (255, 176, 64)
    lines = []
    for y, row in enumerate(alpha_rows):
        line = bytearray(size * 3)
        for x, alpha in enumerate(row):
            dark = 34 if ((x // 16) + (y // 16)) % 2 == 0 else 26
            on_line = grid > 1 and (x % tile == 0 or y % tile == 0)
            base = 70 if on_line else dark
            a = alpha / 255.0
            index = x * 3
            line[index] = int(base + (tint[0] - base) * a)
            line[index + 1] = int(base + (tint[1] - base) * a)
            line[index + 2] = int(base + (tint[2] - base) * a)
        lines.append(bytes(line))
    path.write_bytes(png_bytes(size, size, 2, lines))


def coverage(alpha_rows: list[bytearray]) -> tuple[float, int]:
    """Anteil sichtbarer Bildpunkte und groesste Deckkraft am Bildrand (sollte 0 sein)."""
    size = len(alpha_rows)
    visible = sum(1 for row in alpha_rows for value in row if value > 8)
    border = max(max(alpha_rows[0]), max(alpha_rows[-1]), max(row[0] for row in alpha_rows), max(row[-1] for row in alpha_rows))
    return visible / (size * size), border


def hint(name: str, grid: int) -> str:
    if name in SEQUENCES:
        layout = FLIPBOOK_LAYOUTS[grid]
        return (
            f"ParticleEmitter: FlipbookLayout = {layout}, FlipbookMode = OneShot "
            f"(laeuft einmal ueber die Lebensdauer). In Config/Effects: Flipbook = {grid}"
        )
    if name == "strahl":
        return "Beam: Texture, TextureMode = Wrap, TextureSpeed > 0, LightEmission = 1"
    if name == "spur":
        return "Trail: Texture, TextureMode = Stretch, LightEmission = 1"
    return "ParticleEmitter: Texture; Farbe ueber Color, Leuchten ueber LightEmission"


def make(name: str, target: Path, size: int, grid: int, seed: int, preview: bool, file_name: str | None) -> Path:
    if name in SEQUENCES:
        if grid not in FLIPBOOK_LAYOUTS:
            raise SystemExit(f"FEHLER: --raster muss 2, 4 oder 8 sein (Roblox kennt nur diese), nicht {grid}.")
        if size % grid != 0:
            raise SystemExit(f"FEHLER: --groesse {size} ist nicht durch das Raster {grid} teilbar.")
    else:
        grid = 1

    rows = render_image(name, size, grid, seed)
    target.mkdir(parents=True, exist_ok=True)
    path = target / f"{file_name or name}.png"
    write_white_alpha(path, rows)
    if preview:
        write_preview(path.with_suffix(".vorschau.png"), rows, grid)

    share, border = coverage(rows)
    note = ""
    if name not in ("strahl", "spur") and border > 12:
        note = "  ACHTUNG: Form beruehrt den Bildrand (harte Kante im Spiel)"
    print(f"{path}  {size}x{size}  sichtbar {share * 100:.0f} %{note}")
    print(f"    {hint(name, grid)}")
    return path


# ---------------------------------------------------------------------------
# Pruefen fertiger Bilder (auch aus PhotoCraft oder Blender)
# ---------------------------------------------------------------------------

EDGE_MARGIN = 4  # so viele Bildpunkte am Rand jeder Kachel muessen leer bleiben


def read_png(path: Path) -> tuple[int, int, bool, list[list[tuple[int, int, int, int]]]]:
    """Liest ein PNG (8 Bit, ohne Zeilensprung). Gibt Breite, Hoehe, hat-Durchsicht und Zeilen aus (r, g, b, a) zurueck."""
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("keine PNG-Datei")
    position = 8
    header = None
    palette: list[tuple[int, int, int]] = []
    palette_alpha: list[int] = []
    compressed = bytearray()
    while position < len(data):
        length = struct.unpack(">I", data[position : position + 4])[0]
        kind = data[position + 4 : position + 8]
        body = data[position + 8 : position + 8 + length]
        position += 12 + length
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", body)
        elif kind == b"PLTE":
            palette = [(body[i], body[i + 1], body[i + 2]) for i in range(0, len(body), 3)]
        elif kind == b"tRNS":
            palette_alpha = list(body)
        elif kind == b"IDAT":
            compressed += body
        elif kind == b"IEND":
            break
    if header is None:
        raise ValueError("PNG ohne Kopf")
    width, height, depth, color_type, _, _, interlace = header
    if depth != 8 or interlace != 0:
        raise ValueError(f"nur 8 Bit ohne Zeilensprung wird gelesen (hier: {depth} Bit). In PhotoCraft als 8-Bit-PNG exportieren.")
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(color_type)
    if channels is None:
        raise ValueError(f"unbekannter PNG-Farbtyp {color_type}")
    raw = zlib.decompress(bytes(compressed))
    stride = width * channels
    rows: list[list[tuple[int, int, int, int]]] = []
    previous = bytearray(stride)
    offset = 0
    for _ in range(height):
        filter_type = raw[offset]
        line = bytearray(raw[offset + 1 : offset + 1 + stride])
        offset += 1 + stride
        for i in range(stride):
            left = line[i - channels] if i >= channels else 0
            up = previous[i]
            up_left = previous[i - channels] if i >= channels else 0
            if filter_type == 1:
                line[i] = (line[i] + left) & 255
            elif filter_type == 2:
                line[i] = (line[i] + up) & 255
            elif filter_type == 3:
                line[i] = (line[i] + ((left + up) >> 1)) & 255
            elif filter_type == 4:
                estimate = left + up - up_left
                a, b, c = abs(estimate - left), abs(estimate - up), abs(estimate - up_left)
                line[i] = (line[i] + (left if a <= b and a <= c else up if b <= c else up_left)) & 255
        previous = line
        row = []
        for x in range(width):
            base = x * channels
            if color_type == 6:
                row.append((line[base], line[base + 1], line[base + 2], line[base + 3]))
            elif color_type == 2:
                row.append((line[base], line[base + 1], line[base + 2], 255))
            elif color_type == 4:
                row.append((line[base], line[base], line[base], line[base + 1]))
            elif color_type == 0:
                row.append((line[base], line[base], line[base], 255))
            else:
                index = line[base]
                r, g, b = palette[index] if index < len(palette) else (0, 0, 0)
                row.append((r, g, b, palette_alpha[index] if index < len(palette_alpha) else 255))
        rows.append(row)
    has_alpha = color_type in (4, 6) or (color_type == 3 and bool(palette_alpha))
    return width, height, has_alpha, rows


def check_image(path: Path, grid: int, seamless: bool) -> int:
    """Prueft ein Effekt-Bild gegen die Regeln aus references/effekte.md. Gibt die Zahl der Fehler zurueck."""
    errors: list[str] = []
    notes: list[str] = []
    try:
        width, height, has_alpha, rows = read_png(path)
    except (OSError, ValueError, zlib.error, struct.error, IndexError) as problem:
        print(f"{path}\n  [FEHLER]  nicht lesbar: {problem}")
        return 1

    if width != height:
        errors.append(f"nicht quadratisch ({width} x {height})")
    if width not in (64, 128, 256, 512, 1024) or height not in (64, 128, 256, 512, 1024):
        errors.append(f"Kantenlaenge {width} x {height}: erlaubt sind 64, 128, 256, 512, 1024")
    if not has_alpha:
        errors.append("keine Durchsicht: Der Hintergrund muss durchsichtig sein, nicht schwarz oder dunkel")
    if errors:
        print(f"{path}")
        for text in errors:
            print(f"  [FEHLER]  {text}")
        return len(errors)

    cell = width // grid
    visible = 0
    not_white = 0
    red = 0
    frame_cover: list[float] = []
    edge_hits: list[str] = []
    for frame in range(grid * grid):
        frame_row, frame_column = divmod(frame, grid)
        x0, y0 = frame_column * cell, frame_row * cell
        covered = 0
        touched: set[str] = set()
        for y in range(cell):
            row = rows[y0 + y]
            for x in range(cell):
                r, g, b, a = row[x0 + x]
                if a <= 8:
                    continue
                covered += 1
                if a > 40:
                    visible += 1
                    if min(r, g, b) < 190:
                        not_white += 1
                        if r > 140 and g < 90 and b < 90:
                            red += 1
                if y < EDGE_MARGIN:
                    touched.add("oben")
                elif y >= cell - EDGE_MARGIN:
                    touched.add("unten")
                if not seamless:
                    if x < EDGE_MARGIN:
                        touched.add("links")
                    elif x >= cell - EDGE_MARGIN:
                        touched.add("rechts")
        frame_cover.append(covered / (cell * cell))
        if touched:
            where = f"Bild {frame + 1}: " if grid > 1 else ""
            edge_hits.append(where + ", ".join(sorted(touched)))

    if edge_hits:
        shown = "; ".join(edge_hits[:6]) + (" ..." if len(edge_hits) > 6 else "")
        errors.append(f"Farbe naeher als {EDGE_MARGIN} Bildpunkte am Rand ({shown}). Im Spiel sieht man dort die Kante des Vierecks.")
    if visible == 0:
        errors.append("Bild ist leer")
    else:
        if not_white / visible > 0.05:
            notes.append(f"{not_white / visible * 100:.0f} % der Flaeche sind nicht weiss. Weiss zeichnen, die Farbe kommt je Schicht in Roblox.")
        if red / visible > 0.01:
            notes.append("Rote Flaechen im Bild. Rote Tropfen oder Spritzer wirken wie Blut und koennen bei Roblox zu einer Verwarnung fuehren: Rot nur als Gluehen, Flamme oder Rauch.")
    if grid > 1:
        peak = max(frame_cover)
        if frame_cover[-1] > max(0.03, peak * 0.35):
            notes.append(f"Das letzte Bild ist noch zu {frame_cover[-1] * 100:.0f} % gefuellt. Die Folge sollte zerfallen und fast leer enden, sonst verschwindet der Effekt mit einem Ruck.")
        empty_inside = [index + 1 for index, share in enumerate(frame_cover[1:-2], start=1) if share < 0.001]
        if empty_inside:
            notes.append(f"Leere Bilder mitten in der Folge: {empty_inside}. Stimmt --raster {grid}?")
    elif frame_cover[0] < 0.02:
        notes.append("Nur sehr wenig Flaeche genutzt: Form groesser zeichnen.")

    kind = f"Bildfolge {grid}x{grid}, je {cell} px" if grid > 1 else "Einzelbild"
    print(f"{path}  ({width} x {height}, {kind})")
    for text in errors:
        print(f"  [FEHLER]  {text}")
    for text in notes:
        print(f"  [HINWEIS] {text}")
    if not errors and not notes:
        print("  [OK]      Rand frei, weiss mit Durchsicht.")
    return len(errors)


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description="Zeichnet Effekt-Texturen als PNG (weiss mit Durchsichtigkeit).")
    parser.add_argument("form", nargs="?", help="Name einer Form oder Bildfolge, oder 'alle'")
    parser.add_argument("--liste", action="store_true", help="alle Formen und Bildfolgen anzeigen")
    parser.add_argument("--ziel", default="export/effekte", help="Zielordner (Standard: export/effekte)")
    parser.add_argument("--groesse", type=int, default=0, help="Kantenlaenge in Bildpunkten (Standard 256, Bildfolgen 512; hoechstens 1024)")
    parser.add_argument("--raster", type=int, default=4, help="Bildfolgen: Kacheln je Seite, 2, 4 oder 8 (Standard 4)")
    parser.add_argument("--saat", type=int, default=1, help="Zufalls-Saat fuer Rauch und Funken (andere Zahl = anderes Bild)")
    parser.add_argument("--name", default=None, help="Dateiname ohne Endung (Standard: Name der Form)")
    parser.add_argument("--vorschau", action="store_true", help="zusaetzlich eine eingefaerbte Vorschau schreiben")
    parser.add_argument("--pruefen", nargs="+", metavar="PNG", help="fertige Bilder pruefen statt zeichnen (Rand frei, weiss, Durchsicht); bei Bildfolgen --raster angeben")
    parser.add_argument("--einzelbild", action="store_true", help="mit --pruefen: Das Bild ist ein Einzelbild, keine Bildfolge")
    parser.add_argument("--nahtlos", action="store_true", help="mit --pruefen: Band fuer Beam/Trail, darf links und rechts den Rand beruehren")
    args = parser.parse_args()

    if args.pruefen:
        if args.raster not in FLIPBOOK_LAYOUTS:
            raise SystemExit("FEHLER: --raster muss 2, 4 oder 8 sein.")
        grid = 1 if args.einzelbild else args.raster
        problems = sum(check_image(Path(name), grid, args.nahtlos) for name in args.pruefen)
        raise SystemExit(1 if problems else 0)

    if args.liste or not args.form:
        print("Einzelbilder:")
        for name, shape in SHAPES.items():
            print(f"  {name:<14} {(shape.__doc__ or '').strip()}")
        print("Bildfolgen (Flipbook):")
        for name, shape in SEQUENCES.items():
            print(f"  {name:<14} {(shape.__doc__ or '').strip()}")
        return

    target = Path(args.ziel)
    if args.form == "alle":
        for name in SHAPES:
            make(name, target, args.groesse or 256, 1, args.saat, args.vorschau, None)
        for name in SEQUENCES:
            make(name, target, args.groesse or 512, args.raster, args.saat, args.vorschau, None)
        return

    if args.form not in SHAPES and args.form not in SEQUENCES:
        known = ", ".join(list(SHAPES) + list(SEQUENCES))
        raise SystemExit(f'FEHLER: Form "{args.form}" gibt es nicht. Vorhanden: {known}')
    default_size = 512 if args.form in SEQUENCES else 256
    size = args.groesse or default_size
    if size < 16 or size > 1024:
        raise SystemExit("FEHLER: --groesse muss zwischen 16 und 1024 liegen (Roblox verkleinert groessere Bilder).")
    make(args.form, target, size, args.raster, args.saat, args.vorschau, args.name)


if __name__ == "__main__":
    main()
