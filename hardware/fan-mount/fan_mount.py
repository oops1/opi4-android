"""30x30 fan adapter for a 20x20x17 mm pin-fin heatsink glued onto the RK3399 (Orange Pi 4).

The part slips over the top of the heatsink (friction sleeve with flex slits), sits on a small
inner ledge, widens through a funnel and ends in a 30x30 plate with the standard 24 mm fan
hole pattern. The fan blows down into the fins; air leaves sideways below the sleeve.

Coordinates: z = 0 is the top face of the heatsink, the sleeve goes down to -GRIP.
Print upside down (fan plate on the bed), no supports needed.

Usage: python fan_mount.py  ->  writes fan_mount_fit*.stl next to this file
Needs: pip install manifold3d numpy
"""
import struct
from pathlib import Path

import numpy as np
from manifold3d import CrossSection, JoinType, Manifold

# ---- parameters (mm) -------------------------------------------------------
HS = 20.0             # heatsink side
GRIP = 5.0            # how deep the sleeve covers the heatsink top
WALL = 1.6            # sleeve wall
LEDGE = 0.9           # inner stop resting on the outer row of pins
FUNNEL_H = 8.0        # height of the 20 -> 30 transition
PLATE_T = 2.5         # fan plate thickness
FAN = 30.0            # fan frame size
FAN_PITCH = 24.0      # fan screw hole spacing (30 mm fans)
FAN_HOLE_D = 2.7      # self-tapping M3 into plastic / clearance for M2.5
FAN_OPEN_D = 28.0     # air opening under the rotor
CORNER_R = 2.0        # rounding of the plate corners
SLIT_W = 1.2          # flex slits in the sleeve
SLIT_H = 3.5
SEG = 96              # circle resolution
FITS = {"tight": 0.10, "normal": 0.20, "loose": 0.35}  # clearance per side

EPS = 0.01


def slab(cs: CrossSection, z: float) -> Manifold:
    """Very thin extrusion of a 2D section at height z (used as a hull endpoint)."""
    return cs.extrude(EPS).translate((0, 0, z))


def rounded_square(side: float, r: float) -> CrossSection:
    return CrossSection.square((side - 2 * r, side - 2 * r), center=True).offset(
        r, JoinType.Round, circular_segments=SEG)


def box(x0, x1, y0, y1, z0, z1) -> Manifold:
    return Manifold.cube((x1 - x0, y1 - y0, z1 - z0)).translate((x0, y0, z0))


def build(fit: float) -> Manifold:
    s_in = HS + 2 * fit
    s_out = s_in + 2 * WALL
    top = FUNNEL_H + PLATE_T

    sleeve = (CrossSection.square((s_out, s_out), center=True).extrude(GRIP).translate((0, 0, -GRIP))
              - CrossSection.square((s_in, s_in), center=True).extrude(GRIP + 2 * EPS)
              .translate((0, 0, -GRIP - EPS)))

    funnel_out = Manifold.batch_hull([
        slab(CrossSection.square((s_out, s_out), center=True), 0.0),
        slab(rounded_square(FAN, CORNER_R), FUNNEL_H - EPS),
    ])
    funnel_in = Manifold.batch_hull([
        slab(CrossSection.square((HS - 2 * LEDGE, HS - 2 * LEDGE), center=True), -EPS),
        slab(CrossSection.circle(FAN_OPEN_D / 2, SEG), FUNNEL_H),
    ])
    plate = (rounded_square(FAN, CORNER_R) - CrossSection.circle(FAN_OPEN_D / 2, SEG)) \
        .extrude(PLATE_T).translate((0, 0, FUNNEL_H))

    body = sleeve + (funnel_out - funnel_in) + plate

    # fan screw holes, through the plate and the funnel corners below it
    h = FAN_PITCH / 2
    for x in (-h, h):
        for y in (-h, h):
            body -= Manifold.cylinder(top + GRIP + 2, FAN_HOLE_D / 2, circular_segments=SEG) \
                .translate((x, y, -GRIP - 1))

    # flex slits in the middle of each sleeve side
    z0, z1 = -GRIP - 1, -GRIP + SLIT_H
    a, b = s_in / 2 - 0.5, s_out / 2 + 0.5
    w = SLIT_W / 2
    for slit in (box(a, b, -w, w, z0, z1), box(-b, -a, -w, w, z0, z1),
                 box(-w, w, a, b, z0, z1), box(-w, w, -b, -a, z0, z1)):
        body -= slit

    # flip for printing: fan plate on the bed
    return body.mirror((0, 0, 1)).translate((0, 0, top))


def write_stl(m: Manifold, path: Path, name: str) -> None:
    mesh = m.to_mesh()
    v = np.asarray(mesh.vert_properties)[:, :3].astype(np.float32)
    t = np.asarray(mesh.tri_verts)
    tri = v[t]
    n = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    n /= np.linalg.norm(n, axis=1, keepdims=True) + 1e-12
    rec = np.zeros(len(t), dtype=[("n", "<f4", 3), ("v", "<f4", (3, 3)), ("a", "<u2")])
    rec["n"], rec["v"] = n, tri
    with open(path, "wb") as f:
        f.write(struct.pack("<80sI", name.encode()[:80], len(t)))
        f.write(rec.tobytes())


if __name__ == "__main__":
    out = Path(__file__).parent
    for label, fit in FITS.items():
        m = build(fit)
        if m.status().name != "NoError":
            raise SystemExit(f"{label}: mesh error {m.status()}")
        lo, hi = np.array(m.bounding_box()[:3]), np.array(m.bounding_box()[3:])
        p = out / f"fan_mount_fit_{label}.stl"
        write_stl(m, p, f"opi4 fan mount fit {fit}")
        print(f"{p.name}: fit {fit} mm/side, size {np.round(hi - lo, 2)} mm, "
              f"volume {m.volume():.0f} mm3 (~{m.volume() * 1.24 / 1000:.1f} g PLA), "
              f"genus {m.genus()}, tris {m.num_tri()}")
