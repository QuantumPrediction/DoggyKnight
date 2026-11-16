"""One-shot particle effects (CP3, DEV_PLAN 4.10): assets/fx/particles/<name>.tscn.

Every effect is a CPUParticles2D (Compatibility renderer, old phones) whose root runs
one_shot_particles.gd: it bursts once when added to the tree and frees itself. All
particles are tiny pixel sprites from assets/fx/particles/tex/ (crisp squares, sticks,
stars, hearts - never blurry circles), coloured from the 40-colour palette, and few in
number (the busiest, confetti, has 36).
"""

from __future__ import annotations

from palette import rgba
from pixel import Canvas, res_path, write_text

TEX_DIR = "res://assets/fx/particles/tex"


def _tex(rows: list[str], legend: dict[str, str]) -> Canvas:
    c = Canvas(max(len(r) for r in rows), len(rows))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in legend:
                c.set(x, y, legend[ch])
    return c


W = {"w": "white"}
TEXTURES = {
    "square": _tex(["ww", "ww"], W),
    "dot": _tex(["w"], W),
    "plus": _tex([".w.", "www", ".w."], W),
    "spark": _tex(["..w..", "..w..", "wwwww", "..w..", "..w.."], W),
    "streak": _tex(["w", "w", "w", "w"], W),
    "stick": _tex(["www"], W),
    "chip": _tex(["ww", "w."], W),
    "feather": _tex([".wv.", "wwvv", ".vv."], {"w": "lilac", "v": "violet"}),
    "straw": _tex(["gGg"], {"g": "gold_l", "G": "gold"}),
    "puff": _tex([".ww.", "wwww", ".ww."], W),
    "heart": _tex([".p.p.", "ppppp", "ppppp", ".ppp.", "..p.."], {"p": "pink"}),
    "heart_outline": _tex([".r.r.", "rpwpr", "rpppr", ".rpr.", "..r.."], {"p": "pink", "w": "white", "r": "red"}),
    "star": _tex(["..y..", ".yyy.", "yywyy", ".yyy.", ".y.y."], {"y": "yellow", "w": "white"}),
    "confetti": _tex(["ww", "ww", "ww"], W),
}


def _color(name: str, a: float = 1.0) -> str:
    r, g, b, _ = rgba(name)
    return "%.3f, %.3f, %.3f, %.3f" % (r / 255, g / 255, b / 255, a)


def gradient(stops: list[tuple[float, str, float]], constant: bool = False) -> list[str]:
    offs = ", ".join("%g" % s[0] for s in stops)
    cols = ", ".join(_color(s[1], s[2]) for s in stops)
    out = ["offsets = PackedFloat32Array(%s)" % offs, "colors = PackedColorArray(%s)" % cols]
    if constant:
        out.insert(0, "interpolation_mode = 1")
    return out


def curve(points: list[tuple[float, float]]) -> list[str]:
    data = ", ".join("Vector2(%g, %g), 0.0, 0.0, 0, 0" % p for p in points)
    return ["_data = [%s]" % data, "point_count = %d" % len(points)]


# Each effect: node properties + optional colour ramp / initial colour ramp / scale curve.
EFFECTS: dict[str, dict] = {
    "hit_burst": {
        "tex": "square", "z": 5, "props": {
            "amount": 9, "lifetime": 0.32, "explosiveness": 1.0, "spread": 180.0, "gravity": "Vector2(0, 40)",
            "initial_velocity_min": 45.0, "initial_velocity_max": 95.0, "damping_min": 140.0, "damping_max": 220.0,
            "scale_amount_min": 0.5, "scale_amount_max": 1.0,
        },
        "ramp": [(0, "white", 1), (0.35, "yellow", 1), (0.7, "orange", 1), (1, "orange", 0)],
        "scale": [(0, 1), (1, 0.5)],
    },
    "straw_bits": {
        "tex": "straw", "z": 5, "props": {
            "amount": 10, "lifetime": 0.85, "explosiveness": 0.95, "direction": "Vector2(0, -1)", "spread": 75.0,
            "gravity": "Vector2(0, 220)", "initial_velocity_min": 50.0, "initial_velocity_max": 95.0,
            "angular_velocity_min": -540.0, "angular_velocity_max": 540.0, "angle_min": -180.0, "angle_max": 180.0,
            "damping_min": 20.0, "damping_max": 40.0,
        },
        "ramp": [(0, "white", 1), (0.75, "white", 1), (1, "white", 0)],
    },
    "feathers": {
        "tex": "feather", "z": 5, "props": {
            "amount": 7, "lifetime": 1.2, "explosiveness": 0.9, "direction": "Vector2(0, -1)", "spread": 100.0,
            "gravity": "Vector2(0, 40)", "initial_velocity_min": 30.0, "initial_velocity_max": 60.0,
            "damping_min": 60.0, "damping_max": 90.0, "angular_velocity_min": -200.0, "angular_velocity_max": 200.0,
            "angle_min": -180.0, "angle_max": 180.0, "tangential_accel_min": -30.0, "tangential_accel_max": 30.0,
        },
        "ramp": [(0, "white", 1), (0.7, "white", 1), (1, "white", 0)],
    },
    "confetti": {
        "tex": "confetti", "z": 5, "props": {
            "amount": 36, "lifetime": 1.8, "explosiveness": 0.92, "direction": "Vector2(0, -1)", "spread": 55.0,
            "gravity": "Vector2(0, 110)", "initial_velocity_min": 80.0, "initial_velocity_max": 150.0,
            "damping_min": 30.0, "damping_max": 60.0, "angular_velocity_min": -720.0, "angular_velocity_max": 720.0,
            "angle_min": -180.0, "angle_max": 180.0,
        },
        "initial": [(0, "red", 1), (0.17, "yellow", 1), (0.34, "sky", 1), (0.5, "leaf_l", 1), (0.67, "pink", 1),
                    (0.84, "white", 1)],
        "ramp": [(0, "white", 1), (0.8, "white", 1), (1, "white", 0)],
    },
    "level_up_pillar": {
        "tex": "plus", "z": 5, "props": {
            "amount": 22, "lifetime": 0.9, "explosiveness": 0.35, "emission_shape": 3,
            "emission_rect_extents": "Vector2(7, 3)", "direction": "Vector2(0, -1)", "spread": 6.0,
            "gravity": "Vector2(0, 0)", "initial_velocity_min": 35.0, "initial_velocity_max": 70.0,
            "damping_min": 10.0, "damping_max": 30.0,
        },
        "ramp": [(0, "white", 1), (0.3, "yellow", 1), (0.75, "gold_l", 1), (1, "gold", 0)],
        "scale": [(0, 1), (1, 0.5)],
    },
    "shockwave": {
        "tex": "puff", "z": -1, "props": {
            "amount": 18, "lifetime": 0.55, "explosiveness": 1.0, "emission_shape": 2, "emission_sphere_radius": 6.0,
            "spread": 180.0, "gravity": "Vector2(0, 0)", "initial_velocity_min": 85.0, "initial_velocity_max": 110.0,
            "damping_min": 160.0, "damping_max": 200.0, "radial_accel_min": 0.0, "radial_accel_max": 0.0,
        },
        "ramp": [(0, "white", 1), (0.4, "stone_l", 1), (1, "stone", 0)],
        "scale": [(0, 1), (1, 0.6)],
    },
    "sparkle": {
        "tex": "spark", "z": 6, "props": {
            "amount": 6, "lifetime": 0.6, "explosiveness": 0.7, "emission_shape": 1, "emission_sphere_radius": 9.0,
            "spread": 180.0, "gravity": "Vector2(0, -10)", "initial_velocity_min": 4.0, "initial_velocity_max": 12.0,
        },
        "ramp": [(0, "white", 1), (0.5, "yellow", 1), (1, "gold_l", 0)],
        "scale": [(0, 0.4), (0.3, 1), (1, 0.2)],
    },
    "ultimate_burst": {
        "tex": "streak", "z": 6, "align": True, "props": {
            "amount": 32, "lifetime": 0.55, "explosiveness": 1.0, "spread": 180.0, "gravity": "Vector2(0, 0)",
            "initial_velocity_min": 130.0, "initial_velocity_max": 210.0, "damping_min": 220.0, "damping_max": 300.0,
            "scale_amount_min": 1.0, "scale_amount_max": 2.0,
        },
        "ramp": [(0, "white", 1), (0.3, "yellow", 1), (0.7, "orange", 1), (1, "orange", 0)],
    },
    "footstep_dust": {
        "tex": "puff", "z": -1, "props": {
            "amount": 3, "lifetime": 0.35, "explosiveness": 0.9, "direction": "Vector2(0, -1)", "spread": 70.0,
            "gravity": "Vector2(0, 0)", "initial_velocity_min": 6.0, "initial_velocity_max": 14.0,
            "damping_min": 20.0, "damping_max": 30.0, "scale_amount_min": 0.5, "scale_amount_max": 1.0,
        },
        "ramp": [(0, "white", 0.9), (0.5, "stone_l", 0.7), (1, "stone_l", 0)],
        "scale": [(0, 0.6), (1, 1)],
    },
    "heart": {
        "tex": "heart_outline", "z": 6, "props": {
            "amount": 3, "lifetime": 1.0, "explosiveness": 0.6, "direction": "Vector2(0, -1)", "spread": 35.0,
            "gravity": "Vector2(0, -20)", "initial_velocity_min": 18.0, "initial_velocity_max": 30.0,
            "tangential_accel_min": -20.0, "tangential_accel_max": 20.0,
        },
        "ramp": [(0, "white", 1), (0.75, "white", 1), (1, "white", 0)],
        "scale": [(0, 0.5), (0.2, 1.2), (0.35, 1), (1, 1)],
    },
    "star_burst": {
        "tex": "star", "z": 6, "props": {
            "amount": 8, "lifetime": 0.65, "explosiveness": 1.0, "spread": 180.0, "gravity": "Vector2(0, 90)",
            "initial_velocity_min": 50.0, "initial_velocity_max": 90.0, "damping_min": 40.0, "damping_max": 60.0,
            "angular_velocity_min": -180.0, "angular_velocity_max": 180.0,
        },
        "ramp": [(0, "white", 1), (0.75, "white", 1), (1, "white", 0)],
        "scale": [(0, 0.5), (0.2, 1), (1, 0.7)],
    },
}


def _num(v) -> str:
    if isinstance(v, str):
        return v
    if isinstance(v, float):
        return ("%.3f" % v).rstrip("0").rstrip(".") if v != int(v) else "%.1f" % v
    return str(v)


def effect_tscn(name: str, fx: dict) -> str:
    lines = ['[gd_scene format=3]', "",
             '[ext_resource type="Script" path="res://assets/fx/particles/one_shot_particles.gd" id="1_fx"]',
             '[ext_resource type="Texture2D" path="%s/%s.png" id="2_tex"]' % (TEX_DIR, fx["tex"])]
    if "ramp" in fx:
        lines += ["", '[sub_resource type="Gradient" id="Gradient_ramp"]'] + gradient(fx["ramp"])
    if "initial" in fx:
        lines += ["", '[sub_resource type="Gradient" id="Gradient_initial"]'] + gradient(fx["initial"], constant=True)
    if "scale" in fx:
        lines += ["", '[sub_resource type="Curve" id="Curve_scale"]'] + curve(fx["scale"])
    lines += ["", '[node name="%s" type="CPUParticles2D"]' % name, "z_index = %d" % fx["z"],
              "emitting = false", "one_shot = true", 'texture = ExtResource("2_tex")']
    for k, v in fx["props"].items():
        lines.append("%s = %s" % (k, _num(v)))
    if fx.get("align"):
        lines.append("particle_flag_align_y = true")
    if "ramp" in fx:
        lines.append('color_ramp = SubResource("Gradient_ramp")')
    if "initial" in fx:
        lines.append('color_initial_ramp = SubResource("Gradient_initial")')
    if "scale" in fx:
        lines.append('scale_amount_curve = SubResource("Curve_scale")')
    lines += ['script = ExtResource("1_fx")', ""]
    return "\n".join(lines)


def write_all() -> None:
    for name, tex in TEXTURES.items():
        tex.save(res_path("%s/%s.png" % (TEX_DIR, name)))
    for name, fx in EFFECTS.items():
        write_text(res_path("res://assets/fx/particles/%s.tscn" % name), effect_tscn(name, fx))
