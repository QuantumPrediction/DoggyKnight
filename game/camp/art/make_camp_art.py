#!/usr/bin/env python3
"""營地專用的像素圖(D 線,DEV_PLAN 15 DP1)。

卸下盔甲、趴在營火旁的金毛(朝右畫,遊戲裡鏡像成朝左看營火),以及會搖的尾巴。
顏色取自 C 線的調色盤(ui/theme/palette_colors.gd),風格與 assets/sprites/ 一致:
深色描邊、左上受光。全部由程式畫出,沒有外部素材。

重新產生(在專案根目錄):
    python3 game/camp/art/make_camp_art.py
輸出:
    game/camp/art/camp_goldie.png       每格 34×24,依序:rest_0、rest_1(呼吸)、blink、happy_0、happy_1
    game/camp/art/camp_goldie_tail.png  每格 14×12,依序:down、mid、up(尾巴的根在每格的右下角)
"""

from __future__ import annotations

import math
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))

PALETTE = {
    "a": (0x2A, 0x1B, 0x2D),  # INK 描邊
    "b": (0xF7, 0xD4, 0x88),  # GOLD_L 毛色
    "c": (0xFF, 0xF1, 0xC9),  # CREAM 高光
    "f": (0xE6, 0xAE, 0x5C),  # GOLD 陰影
    "d": (0xC0, 0x7F, 0x3E),  # GOLD_D 深陰影
    "e": (0x8A, 0x52, 0x32),  # BROWN 耳朵深處
    "i": (0xFF, 0x99, 0xAA),  # PINK 腮紅
    "h": (0xE8, 0x43, 0x4F),  # RED 舌頭
    "g": (0xA8, 0x30, 0x4A),  # RED_D 嘴巴
    "w": (0xFF, 0xFA, 0xF0),  # WHITE 眼睛反光
}

FW, FH = 34, 24
TW, TH = 14, 12


class Canvas:
    def __init__(self, w: int, h: int) -> None:
        self.w = w
        self.h = h
        self.px: list[list[str]] = [["." for _ in range(w)] for _ in range(h)]

    def get(self, x: int, y: int) -> str:
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return "."

    def set(self, x: int, y: int, c: str) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = c

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, light: bool = True,
                base: str = "b", hi: str = "c", lo: str = "f") -> None:
        for y in range(self.h):
            for x in range(self.w):
                dx = (x + 0.5 - cx) / rx
                dy = (y + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1.0:
                    c = base
                    if light:
                        if dy < -0.55 and dx < 0.5:
                            c = hi
                        elif dy > 0.45:
                            c = lo
                    self.set(x, y, c)

    def rect(self, x0: int, y0: int, x1: int, y1: int, c: str) -> None:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, c)

    def outline(self) -> None:
        """透明的格子只要上下左右碰到顏色,就變成描邊。"""
        add = []
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] != ".":
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    n = self.get(x + dx, y + dy)
                    if n not in (".", "a"):
                        add.append((x, y))
                        break
        for x, y in add:
            self.set(x, y, "a")

    def image(self) -> Image.Image:
        img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for y in range(self.h):
            for x in range(self.w):
                c = self.px[y][x]
                if c != ".":
                    img.putpixel((x, y), PALETTE[c] + (255,))
        return img


def goldie(breath: int = 0, face: str = "rest", ear_up: bool = False) -> Canvas:
    """趴著的金毛,朝右。頭大身小(和 C 線的 Q 版比例一致)。breath 1 = 吸氣(背部高 1 格)。"""
    cv = Canvas(FW, FH)
    by = -0.5 * breath
    # 後腿(屁股)與身體
    cv.ellipse(8.6, 16.8 + by, 5.0, 4.9 + 0.5 * breath)
    cv.ellipse(13.5, 17.4 + by, 9.0, 4.3 + 0.5 * breath)
    # 前腳(伸向前方)
    cv.rect(19, 19, 29, 20, "b")
    cv.rect(20, 21, 29, 21, "f")
    # 後腳
    cv.ellipse(6.0, 20.8, 3.4, 1.5, base="b", hi="b", lo="f")
    # 頭(大)與嘴巴(奶油色)
    cv.ellipse(23.6, 9.6, 6.9, 6.0)
    cv.ellipse(29.6, 12.0, 3.6, 2.6, base="c", hi="c", lo="c")
    # 胸口的亮毛
    for (x, y) in ((19, 15), (20, 15), (19, 16), (20, 16), (21, 16), (20, 17), (21, 17), (22, 17)):
        if cv.get(x, y) != ".":
            cv.set(x, y, "c")
    # 身體下緣的深色
    for x in range(4, 20):
        for y in range(FH - 1, 0, -1):
            if cv.get(x, y) != ".":
                if cv.get(x, y) in ("b", "f"):
                    cv.set(x, y, "d")
                break
    # 耳朵(垂在頭的左邊;摸頭時豎起來一點)
    ey = 9.4 if ear_up else 10.8
    ex = 18.8
    for y in range(FH):
        for x in range(FW):
            dx = (x + 0.5 - ex) / 2.4
            dy = (y + 0.5 - ey) / 3.9
            d = dx * dx + dy * dy
            if d <= 1.0:
                cv.set(x, y, "d" if d > 0.5 else ("f" if dy < 0.0 else "e"))
    cv.outline()
    # 後腿的輪廓(讓身體不像一條麵包)
    for (x, y) in ((11, 14), (12, 15), (12, 16), (12, 17), (11, 18), (10, 19)):
        cv.set(x, y, "f")
    # 前腳和胸口之間的線、兩隻前腳之間的線、腳趾
    for x in range(22, 29):
        if cv.get(x, 18) not in (".",):
            cv.set(x, 18, "a")
    cv.set(25, 20, "a")
    cv.set(25, 21, "a")
    cv.set(29, 19, "c")
    cv.set(28, 21, "a")
    # 鼻子
    cv.set(32, 10, "a")
    cv.set(33, 10, "a")
    cv.set(32, 11, "a")
    cv.set(33, 11, "a")
    cv.set(32, 10, "e")
    # 臉
    eye_x, eye_y = 25, 8
    if face == "rest":
        cv.set(eye_x, eye_y, "w")
        cv.set(eye_x + 1, eye_y, "a")
        cv.set(eye_x, eye_y + 1, "a")
        cv.set(eye_x + 1, eye_y + 1, "a")
    elif face == "blink":
        cv.set(eye_x, eye_y + 1, "a")
        cv.set(eye_x + 1, eye_y + 1, "a")
    elif face == "happy":
        cv.set(eye_x - 1, eye_y + 1, "a")
        cv.set(eye_x, eye_y, "a")
        cv.set(eye_x + 1, eye_y, "a")
        cv.set(eye_x + 2, eye_y + 1, "a")
    # 腮紅
    cv.set(24, 11, "i")
    cv.set(25, 11, "i")
    if face == "happy":
        cv.set(26, 11, "i")
        # 張嘴吐舌
        for x in (28, 29, 30, 31):
            cv.set(x, 14, "a")
        cv.set(29, 14, "g")
        cv.set(30, 14, "g")
        cv.set(29, 15, "h")
        cv.set(30, 15, "h")
        cv.set(28, 15, "a")
        cv.set(31, 15, "a")
        cv.set(29, 16, "a")
        cv.set(30, 16, "a")
    else:
        # 小小的嘴
        cv.set(30, 13, "a")
        cv.set(31, 13, "a")
    return cv


def tail(angle_deg: float) -> Canvas:
    """毛茸茸的尾巴(金毛的尾巴下面有長長的飾毛),根在右下角,往左伸。angle 0 = 平放,正數 = 往上翹。"""
    cv = Canvas(TW, TH)
    root = (TW - 1.5, TH - 3.0)
    a = math.radians(angle_deg)
    length = 9.5
    steps = 16
    for i in range(steps + 1):
        t = i / steps
        bend = a + 0.6 * t * t
        x = root[0] - math.cos(bend) * length * t
        y = root[1] - math.sin(bend) * length * t
        r = 2.3 - 1.1 * t
        cv.ellipse(x, y, r + 0.2, r, base="b", hi="c", lo="f")
        # 下面的飾毛(往下垂的一撮撮)
        if 0.2 < t < 0.9 and i % 3 == 0:
            cv.ellipse(x + 0.4, y + r + 0.4, 1.1, 1.3, base="f", hi="f", lo="f")
    tip_x = root[0] - math.cos(a + 0.6) * length
    tip_y = root[1] - math.sin(a + 0.6) * length
    cv.ellipse(tip_x, tip_y, 1.5, 1.3, base="c", hi="c", lo="c")
    cv.outline()
    return cv


def sheet(frames: list[Canvas], w: int, h: int) -> Image.Image:
    img = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        img.paste(f.image(), (i * w, 0))
    return img


def main() -> None:
    body = [
        goldie(0, "rest"),
        goldie(1, "rest"),
        goldie(0, "blink"),
        goldie(0, "happy", ear_up=True),
        goldie(1, "happy", ear_up=True),
    ]
    sheet(body, FW, FH).save(os.path.join(HERE, "camp_goldie.png"))
    tails = [tail(-8.0), tail(22.0), tail(52.0)]
    sheet(tails, TW, TH).save(os.path.join(HERE, "camp_goldie_tail.png"))
    print("wrote camp_goldie.png, camp_goldie_tail.png")


if __name__ == "__main__":
    main()
