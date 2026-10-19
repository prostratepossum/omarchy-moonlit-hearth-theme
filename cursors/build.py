#!/usr/bin/python3
"""Build the Moonlit Hearth XCursor theme.

Snow-white shapes with a navy outline and a faint moonlight glow at the tip,
where a small six-point snowflake slowly twinkles. Pointer = pointing hand
with a tiny crescent moon; wait = a lantern whose amber flame flickers;
progress = arrow carrying a small lantern. SVGs on a 32-unit canvas ->
rsvg-convert -> XCursor (same packing as the Starwatch builder). Shapes not drawn here fall back to Adwaita.

    ./build.py            -> MoonlitHearth/ next to this script
    ./build.py --install  -> also copies to ~/.local/share/icons/MoonlitHearth
"""
import io
import math
import shutil
import struct
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
OUT = HERE / "MoonlitHearth"
PREVIEW = HERE / "preview.png"
SIZES = (24, 32, 48, 64)

NAVY = "#0a1424"
NAVY_LIGHT = "#1f3350"
SNOW = "#f2f7fc"
FROST = "#c6daeb"
MOON = "#8fbbe0"
MOON_PALE = "#dcebf7"
FLAME_CORE = "#fff4d6"
FLAME = "#f0c47a"
AMBER = "#e8a15a"
EMBER = "#d27a6a"
BRASS = "#8a6248"

DEFS = f"""
<defs>
  <linearGradient id="body" x1="0" y1="0" x2="0.6" y2="1">
    <stop offset="0" stop-color="{SNOW}"/>
    <stop offset="1" stop-color="{FROST}"/>
  </linearGradient>
  <radialGradient id="moonglow">
    <stop offset="0" stop-color="{MOON}" stop-opacity="0.85"/>
    <stop offset="1" stop-color="{MOON}" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="glow">
    <stop offset="0" stop-color="{FLAME}" stop-opacity="0.9"/>
    <stop offset="1" stop-color="{FLAME}" stop-opacity="0"/>
  </radialGradient>
  <linearGradient id="flame" x1="0" y1="1" x2="0" y2="0">
    <stop offset="0" stop-color="{AMBER}"/>
    <stop offset="0.5" stop-color="{FLAME}"/>
    <stop offset="1" stop-color="{FLAME_CORE}"/>
  </linearGradient>
  <filter id="shadow" x="-50%" y="-50%" width="200%" height="200%">
    <feDropShadow dx="0.6" dy="0.9" stdDeviation="0.8" flood-color="#000" flood-opacity="0.5"/>
  </filter>
</defs>
"""


def svg(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">{DEFS}{body}</svg>'


def snowflake(x, y, r, angle=0.0, alpha=1.0):
    """Six-point snowflake of radius r centred at (x, y): navy halo under frost-white arms."""
    arms = []
    for k in range(6):
        a = math.radians(angle + 60 * k)
        ex, ey = x + r * math.cos(a), y + r * math.sin(a)
        arms.append(f"M{x:.2f},{y:.2f} L{ex:.2f},{ey:.2f}")
        # little V barbs two thirds out
        bx, by = x + 0.62 * r * math.cos(a), y + 0.62 * r * math.sin(a)
        for side in (-1, 1):
            b = a + side * math.radians(40)
            arms.append(f"M{bx:.2f},{by:.2f} L{bx + 0.34 * r * math.cos(b):.2f},{by + 0.34 * r * math.sin(b):.2f}")
    d = " ".join(arms)
    w = max(0.55, r * 0.2)
    return (f'<g opacity="{alpha:.2f}">'
            f'<circle cx="{x:.2f}" cy="{y:.2f}" r="{r * 1.5:.2f}" fill="url(#moonglow)" opacity="{0.55 * alpha:.2f}"/>'
            f'<path d="{d}" stroke="{NAVY}" stroke-width="{w + 0.9:.2f}" stroke-linecap="round" fill="none"/>'
            f'<path d="{d}" stroke="{SNOW}" stroke-width="{w:.2f}" stroke-linecap="round" fill="none"/></g>')


def twinkle(i, n):
    """(radius, rotation, alpha) for frame i of a slow n-frame twinkle loop."""
    a = 2 * math.pi * i / n
    return (2.7 + 0.45 * math.sin(a), 30 * i / n, 0.72 + 0.28 * (0.5 + 0.5 * math.sin(a)))


def crescent(x, y, r, glow=1.0):
    """Crescent moon of radius r, opening to the right-down, centred at (x, y)."""
    # Outer circle arc then inner arc back (offset circle) -> crescent path.
    ox, oy = x + r * 0.48, y - r * 0.32
    ri = r * 0.82
    # Intersection points of the two circles, computed numerically.
    dx, dy = ox - x, oy - y
    d = math.hypot(dx, dy)
    a = (r * r - ri * ri + d * d) / (2 * d)
    h = math.sqrt(max(0.0, r * r - a * a))
    mx, my = x + a * dx / d, y + a * dy / d
    p1 = (mx + h * dy / d, my - h * dx / d)
    p2 = (mx - h * dy / d, my + h * dx / d)
    path = (f"M{p1[0]:.2f},{p1[1]:.2f} A{r:.2f},{r:.2f} 0 1 0 {p2[0]:.2f},{p2[1]:.2f} "
            f"A{ri:.2f},{ri:.2f} 0 1 1 {p1[0]:.2f},{p1[1]:.2f} Z")
    return (f'<circle cx="{x:.2f}" cy="{y:.2f}" r="{r * 1.9:.2f}" fill="url(#moonglow)" opacity="{0.5 * glow:.2f}"/>'
            f'<path d="{path}" fill="{MOON_PALE}" stroke="{NAVY}" stroke-width="0.9" stroke-linejoin="round"/>')


def flame(x, y, h=5.0, sway=0.0, bright=1.0):
    """Lantern flame whose base sits at (x, y); sway bends the tip sideways."""
    w = h * 0.42
    tx = x + sway
    d = (f"M{x - w:.2f},{y - h * 0.25:.2f} Q{x - w:.2f},{y:.2f} {x:.2f},{y:.2f} "
         f"Q{x + w:.2f},{y:.2f} {x + w:.2f},{y - h * 0.25:.2f} "
         f"Q{x + w * 0.7:.2f},{y - h * 0.6:.2f} {tx:.2f},{y - h:.2f} "
         f"Q{x - w * 0.7:.2f},{y - h * 0.6:.2f} {x - w:.2f},{y - h * 0.25:.2f} Z")
    return (f'<path d="{d}" fill="url(#flame)" opacity="{min(1, 0.75 + 0.25 * bright):.2f}"/>'
            f'<ellipse cx="{x:.2f}" cy="{y - h * 0.22:.2f}" rx="{w * 0.38:.2f}" ry="{h * 0.2:.2f}" fill="{FLAME_CORE}"/>')


def flicker(i, n):
    """(height, sway, brightness) for frame i of an n-frame flicker loop."""
    a = 2 * math.pi * i / n
    return (1.0 + 0.13 * math.sin(a * 2) + 0.07 * math.sin(a * 3 + 1),
            0.16 * math.sin(a) + 0.07 * math.sin(a * 3),
            0.78 + 0.22 * math.sin(a * 2 + 0.5))


def lantern(cx, cy, s, fl):
    """Lantern centred at (cx, cy), scale s (1 = ~24 units tall), flame state fl."""
    hk, sway, b = fl

    def P(x, y):
        return f"{cx + x * s:.2f},{cy + y * s:.2f}"
    sw = 1.0 * s
    ring = (f'<path d="M{P(-2.6, -9.2)} Q{P(-2.6, -12.4)} {P(0, -12.4)} Q{P(2.6, -12.4)} {P(2.6, -9.2)}" '
            f'fill="none" stroke="{NAVY}" stroke-width="{2.4 * s:.2f}" stroke-linecap="round"/>'
            f'<path d="M{P(-2.6, -9.2)} Q{P(-2.6, -12.4)} {P(0, -12.4)} Q{P(2.6, -12.4)} {P(2.6, -9.2)}" '
            f'fill="none" stroke="{FROST}" stroke-width="{1.0 * s:.2f}" stroke-linecap="round"/>')
    cap = f"M{P(-3.2, -9.4)} L{P(3.2, -9.4)} L{P(6.4, -6.2)} L{P(-6.4, -6.2)} Z"
    glass = f"M{P(-5.4, -6.2)} L{P(5.4, -6.2)} L{P(4.8, 7.4)} L{P(-4.8, 7.4)} Z"
    base = f"M{P(-6.6, 7.2)} L{P(6.6, 7.2)} L{P(6.0, 10.2)} L{P(-6.0, 10.2)} Z"
    bars = (f'<path d="M{P(-1.8, -6.2)} L{P(-1.6, 7.4)} M{P(1.8, -6.2)} L{P(1.6, 7.4)}" '
            f'stroke="{NAVY}" stroke-width="{0.55 * s:.2f}" opacity="0.55"/>')
    fh = 7.6 * s * hk
    return (f'<circle cx="{cx:.2f}" cy="{cy + 0.5 * s:.2f}" r="{12 * s:.2f}" fill="url(#glow)" opacity="{0.42 * b:.2f}"/>'
            f'<g filter="url(#shadow)">{ring}'
            f'<path d="{glass}" fill="{NAVY_LIGHT}" stroke="{NAVY}" stroke-width="{sw + 0.6:.2f}" stroke-linejoin="round"/>'
            f'<path d="{glass}" fill="{AMBER}" opacity="{0.28 + 0.2 * b:.2f}"/>'
            f'{flame(cx, cy + 5.4 * s, fh, sway * 6 * s, b)}{bars}'
            f'<path d="{glass}" fill="none" stroke="{FROST}" stroke-width="{0.8 * s:.2f}" stroke-linejoin="round"/>'
            f'<path d="{cap}" fill="{FROST}" stroke="{NAVY}" stroke-width="{0.9 * s:.2f}" stroke-linejoin="round"/>'
            f'<path d="{base}" fill="{FROST}" stroke="{NAVY}" stroke-width="{0.9 * s:.2f}" stroke-linejoin="round"/></g>')


ARROW = "M4,4 L4,24.5 L9.4,19.6 L12.9,27.4 L16.4,25.9 L12.9,18.4 L20.2,18.4 Z"


def arrow(extra="", tw=None):
    flake = snowflake(14.6, 6.2, *(tw or (2.7, 0, 0.9)))
    return svg(f'<circle cx="4.6" cy="4.8" r="4.4" fill="url(#moonglow)" opacity="0.65"/>'
               f'<g filter="url(#shadow)"><path d="{ARROW}" fill="url(#body)" stroke="{NAVY}" '
               f'stroke-width="1.45" stroke-linejoin="round"/></g>{flake}{extra}')


def double_arrow(angle):
    d = ("M4,16 L10,10.5 L10,13.9 L22,13.9 L22,10.5 L28,16 L22,21.5 L22,18.1 "
         "L10,18.1 L10,21.5 Z")
    return svg(f'<g transform="rotate({angle} 16 16)" filter="url(#shadow)"><path d="{d}" '
               f'fill="url(#body)" stroke="{NAVY}" stroke-width="1.3" stroke-linejoin="round"/></g>'
               f'<circle cx="16" cy="16" r="1.5" fill="{MOON}" stroke="{NAVY}" stroke-width="0.6"/>')


def move():
    d = ("M16,3 L20.5,8 L17.6,8 L17.6,14.4 L24,14.4 L24,11.5 L29,16 L24,20.5 L24,17.6 "
         "L17.6,17.6 L17.6,24 L20.5,24 L16,29 L11.5,24 L14.4,24 L14.4,17.6 L8,17.6 "
         "L8,20.5 L3,16 L8,11.5 L8,14.4 L14.4,14.4 L14.4,8 L11.5,8 Z")
    return svg(f'<g filter="url(#shadow)"><path d="{d}" fill="url(#body)" stroke="{NAVY}" '
               f'stroke-width="1.2" stroke-linejoin="round"/></g>'
               f'<circle cx="16" cy="16" r="1.9" fill="{MOON}" stroke="{NAVY}" stroke-width="0.6"/>')


POINT_HAND = ("M10.6,5 Q10.6,2.8 12.7,2.8 Q14.8,2.8 14.8,5 L14.8,12.2 "
              "Q14.8,10.6 16.6,10.6 Q18.4,10.6 18.4,12.2 L18.4,13.1 "
              "Q18.4,11.7 20.1,11.7 Q21.8,11.7 21.8,13.3 L21.8,14.3 "
              "Q21.8,13 23.4,13 Q25,13 25,14.7 L25,20.6 Q25,28.2 18.4,28.2 L15.4,28.2 "
              "Q11.6,28.2 9.6,24.4 L6.4,18.4 Q5.6,16.7 7.1,16 Q8.6,15.3 9.6,16.8 L10.6,18.4 Z")


def point_hand(glow):
    return svg(f'<circle cx="12.7" cy="3.6" r="3.6" fill="url(#moonglow)" opacity="0.6"/>'
               f'<g filter="url(#shadow)"><path d="{POINT_HAND}" fill="url(#body)" stroke="{NAVY}" '
               f'stroke-width="1.3" stroke-linejoin="round"/></g>'
               f'{crescent(24.2, 6.6, 3.6, glow)}')


def hand(closed=False):
    if closed:
        d = ("M8.5,15.5 Q8.5,12.6 11,12.6 Q11.2,10.4 13.1,10.4 Q14.9,10.4 15.1,11.6 "
             "Q15.5,9.9 17.3,9.9 Q19.1,9.9 19.3,11.5 Q19.7,10.5 21.3,10.5 Q23.2,10.5 23.2,12.8 "
             "L23.2,20 Q23.2,27.5 16.6,27.5 L14.6,27.5 Q10.5,27.5 8.5,22 Z")
    else:
        d = ("M8.5,15 Q8.5,12.5 10.8,12.5 L10.8,7 Q10.8,5 12.8,5 Q14.8,5 14.8,7 L14.8,11 "
             "L14.8,5.5 Q14.8,3.5 16.8,3.5 Q18.8,3.5 18.8,5.5 L18.8,11 L18.8,6.5 Q18.8,4.5 20.8,4.5 "
             "Q22.8,4.5 22.8,6.5 L22.8,20 Q22.8,27.5 16.5,27.5 L14.5,27.5 Q10.5,27.5 8.5,22 Z")
    held = (f'<path d="M11.2,13 L11.2,16.4 M15.1,11.8 L15.1,15.6 M19.3,11.6 L19.3,15.4" stroke="{NAVY}" '
            f'stroke-width="0.9" stroke-linecap="round" opacity="0.7"/>') if closed else ""
    return svg(f'<g filter="url(#shadow)"><path d="{d}" fill="url(#body)" stroke="{NAVY}" '
               f'stroke-width="1.3" stroke-linejoin="round"/></g>{held}')


def text_beam():
    d = "M11,4 Q16,4 16,7 Q16,4 21,4 M16,7 L16,25 M11,28 Q16,28 16,25 Q16,28 21,28 M13,16 L19,16"
    return svg(f'<path d="{d}" fill="none" stroke="{NAVY}" stroke-width="3.8" stroke-linecap="round"/>'
               f'<path d="{d}" fill="none" stroke="{SNOW}" stroke-width="1.7" stroke-linecap="round"/>')


def crosshair():
    d = "M16,3 L16,12 M16,20 L16,29 M3,16 L12,16 M20,16 L29,16"
    return svg(f'<path d="{d}" stroke="{NAVY}" stroke-width="3.4" stroke-linecap="round"/>'
               f'<path d="{d}" stroke="{SNOW}" stroke-width="1.4" stroke-linecap="round"/>'
               f'<circle cx="16" cy="16" r="1.8" fill="{MOON}" stroke="{NAVY}" stroke-width="0.6"/>')


def not_allowed():
    return svg(f'<g filter="url(#shadow)"><circle cx="16" cy="16" r="10" fill="{NAVY}" fill-opacity="0.55" '
               f'stroke="{NAVY}" stroke-width="4.4"/>'
               f'<circle cx="16" cy="16" r="10" fill="none" stroke="{EMBER}" stroke-width="2.4"/>'
               f'<path d="M9,23 L23,9" stroke="{NAVY}" stroke-width="4.4" stroke-linecap="round"/>'
               f'<path d="M9,23 L23,9" stroke="{EMBER}" stroke-width="2.4" stroke-linecap="round"/></g>')


# name -> (frames, hotspot in 32-unit space, frame delay ms)
TWINK = 16
FLICK = 12
CURSORS = {
    "default": ([arrow(tw=twinkle(i, TWINK)) for i in range(TWINK)], (4, 4), 150),
    "pointer": ([point_hand(0.75 + 0.25 * math.sin(2 * math.pi * i / TWINK)) for i in range(TWINK)],
                (12.7, 2.8), 150),
    "text": ([text_beam()], (16, 16), 0),
    "crosshair": ([crosshair()], (16, 16), 0),
    "not-allowed": ([not_allowed()], (16, 16), 0),
    "move": ([move()], (16, 16), 0),
    "grab": ([hand(False)], (16, 14), 0),
    "grabbing": ([hand(True)], (16, 16), 0),
    "ew-resize": ([double_arrow(0)], (16, 16), 0),
    "ns-resize": ([double_arrow(90)], (16, 16), 0),
    "nwse-resize": ([double_arrow(45)], (16, 16), 0),
    "nesw-resize": ([double_arrow(-45)], (16, 16), 0),
    "wait": ([svg(lantern(16, 17.2, 1.12, flicker(i, FLICK))) for i in range(FLICK)], (16, 16), 85),
    "progress": ([arrow(lantern(23.4, 21.2, 0.58, flicker(i, FLICK)), twinkle(i * TWINK // FLICK, TWINK))
                  for i in range(FLICK)], (4, 4), 85),
}

ALIASES = {
    "default": ["left_ptr", "arrow", "top_left_arrow", "context-menu", "copy", "alias"],
    "pointer": ["hand1", "hand2", "pointing_hand", "e29285e634086352946a0e7090d73106",
                "9d800788f1b08800ae810202380a0822"],
    "text": ["xterm", "ibeam", "vertical-text"],
    "crosshair": ["cross", "tcross", "cell", "color-picker"],
    "not-allowed": ["no-drop", "forbidden", "circle", "crossed_circle", "03b6e0fcb3499374a867c041f52298f0"],
    "move": ["fleur", "all-scroll", "size_all", "all-resize"],
    "grab": ["openhand", "5aca4d189052212118709018842178c0"],
    "grabbing": ["closedhand", "dnd-move", "dnd-none", "208530c400c041818281048008011002"],
    "ew-resize": ["col-resize", "sb_h_double_arrow", "h_double_arrow", "size_hor", "e-resize",
                  "w-resize", "left_side", "right_side", "split_h", "14fef782d02440884392942c11205230"],
    "ns-resize": ["row-resize", "sb_v_double_arrow", "v_double_arrow", "size_ver", "n-resize",
                  "s-resize", "top_side", "bottom_side", "split_v", "2870a09082c103050810ffdffffe0204"],
    "nwse-resize": ["size_fdiag", "bd_double_arrow", "nw-resize", "se-resize", "top_left_corner",
                    "bottom_right_corner", "c7088f0f3e6c8088236ef8e1e3e70000"],
    "nesw-resize": ["size_bdiag", "fd_double_arrow", "ne-resize", "sw-resize", "top_right_corner",
                    "bottom_left_corner", "fcf1c3c7cd4491d801f1e1c78f100000"],
    "wait": ["watch", "clock"],
    "progress": ["left_ptr_watch", "half-busy", "00000000000000020006000e7e9ffc3f",
                 "08e8e1c95fe2fc01f976f1e063a24ccd", "3ecb610c1bf2410f44200f48c40d3599"],
}


def render(svg_text, size):
    png = subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size)],
                         input=svg_text.encode(), capture_output=True, check=True).stdout
    return Image.open(io.BytesIO(png)).convert("RGBA")


def xcursor(frames, hotspot, delay):
    images = []
    for size in SIZES:
        hx, hy = (round(c * size / 32) for c in hotspot)
        for svg_text in frames:
            rgba = np.asarray(render(svg_text, size), dtype=np.uint32)
            a = rgba[..., 3]
            argb = (a << 24) | (rgba[..., 0] * a // 255 << 16) | (rgba[..., 1] * a // 255 << 8) | (rgba[..., 2] * a // 255)
            images.append((size, size, size, hx, hy, delay, argb.astype("<u4").tobytes()))
    out = bytearray(struct.pack("<4sIII", b"Xcur", 16, 0x10000, len(images)))
    pos = 16 + 12 * len(images)
    for nominal, w, h, *_rest, px in images:
        out += struct.pack("<III", 0xFFFD0002, nominal, pos)
        pos += 36 + len(px)
    for nominal, w, h, hx, hy, dl, px in images:
        out += struct.pack("<IIIIIIIII", 36, 0xFFFD0002, nominal, 1, w, h, hx, hy, dl)
        out += px
    return bytes(out)


def contact_sheet():
    """Every shape at 24 px (actual size, nearest-scaled x2) and 64 px, on night
    navy and on white, plus the animated frames of default/pointer/wait/progress."""
    names = list(CURSORS)
    cell = 76
    rows = [((10, 20, 36, 255), 24), ((10, 20, 36, 255), 64), ((240, 240, 240, 255), 24), ((240, 240, 240, 255), 64)]
    anim = ["default", "pointer", "wait", "progress"]
    width = max(len(names) * cell, max(len(CURSORS[n][0]) for n in anim) * cell)
    sheet = Image.new("RGBA", (width, cell * (len(rows) + len(anim))), (10, 20, 36, 255))
    for r, (bg, size) in enumerate(rows):
        sheet.paste(Image.new("RGBA", (width, cell), bg), (0, r * cell))
        for i, name in enumerate(names):
            im = render(CURSORS[name][0][0], size)
            if size == 24:
                im = im.resize((48, 48), Image.NEAREST)
            sheet.alpha_composite(im, (i * cell + (cell - im.width) // 2, r * cell + (cell - im.height) // 2))
    for r, name in enumerate(anim):
        y = (len(rows) + r) * cell
        for i, f in enumerate(CURSORS[name][0]):
            im = render(f, 64)
            sheet.alpha_composite(im, (i * cell + 6, y + 6))
    sheet.save(PREVIEW)


def main():
    if OUT.exists():
        shutil.rmtree(OUT)
    cdir = OUT / "cursors"
    cdir.mkdir(parents=True)
    for name, (frames, hotspot, delay) in CURSORS.items():
        (cdir / name).write_bytes(xcursor(frames, hotspot, delay))
        for alias in ALIASES.get(name, []):
            if not (cdir / alias).exists():
                (cdir / alias).symlink_to(name)
    (OUT / "index.theme").write_text(
        "[Icon Theme]\nName=MoonlitHearth\nComment=Moonlit Hearth cursors: snow white and night navy, "
        "a twinkling snowflake, a crescent moon, and a lantern\nInherits=Adwaita\n")
    (OUT / "cursor.theme").write_text("[Icon Theme]\nInherits=MoonlitHearth\n")
    contact_sheet()

    if "--install" in sys.argv:
        dest = Path.home() / ".local/share/icons/MoonlitHearth"
        if dest.exists():
            shutil.rmtree(dest)
        shutil.copytree(OUT, dest, symlinks=True)
        print(f"installed to {dest}")
    print(f"built {len(CURSORS)} cursors, {sum(len(v) for v in ALIASES.values())} aliases")


if __name__ == "__main__":
    main()
