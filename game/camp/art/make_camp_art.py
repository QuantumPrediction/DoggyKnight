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
    cv = Canvas(FW, FH)
    by = -0.5 * breath
    # 後腿(屁股)與身體
    cv.ellipse(9.0, 16.2 + by, 5.6, 5.4 + 0.5 * breath)
    cv.ellipse(15.5, 16.8 + by, 10.0, 4.8 + 0.5 * breath)
    # 胸口(比較亮的毛)
    cv.ellipse(22.0, 14.8, 4.2, 4.6, base="b", hi="c", lo="b")
    # 頭與嘴巴
    cv.ellipse(25.2, 9.4, 5.3, 4.9)
    cv.ellipse(30.0, 11.6, 3.4, 2.4, base="c", hi="c", lo="b")
    # 前腳(伸向前方)
    cv.rect(22, 19, 31, 20, "b")
    cv.rect(23, 21, 31, 21, "f")
    # 後腳
    cv.ellipse(6.5, 20.6, 3.4, 1.6, base="b", hi="b", lo="f")
    # 身體下緣的深色
    for x in range(6, 22):
        if cv.get(x, 22) == "." and cv.get(x, 21) in ("f", "b"):
            cv.set(x, 21, "d")
    cv.outline()
    # 前腳和胸口之間的線、兩隻腳之間的線
    for x in range(24, 31):
        if cv.get(x, 18) != ".":
            cv.set(x, 18, "a")
    cv.set(27, 20, "a")
    cv.set(27, 21, "a")
    cv.set(31, 19, "c")
    # 耳朵(垂在頭的左邊;摸頭時豎起來一點)
    ey = 8.2 if ear_up else 10.0
    for y in range(FH):
        for x in range(FW):
            dx = (x + 0.5 - 21.6) / 2.3
            dy = (y + 0.5 - ey) / 3.6
            d = dx * dx + dy * dy
            if d <= 1.0:
                cv.set(x, y, "d" if d > 0.45 else ("f" if dy < 0.2 else "e"))
    # 頭頂的高光
    cv.set(23, 5, "c")
    cv.set(24, 5, "c")
    cv.set(25, 5, "c")
    # 鼻子
    cv.set(33, 10, "a")
    cv.set(32, 10, "a")
    cv.set(33, 11, "a")
    # 臉
    if face == "rest":
        cv.set(27, 8, "a")
        cv.set(27, 9, "a")
        cv.set(28, 12, "i")
        cv.set(31, 13, "a")
        cv.set(30, 13, "a")
    elif face == "blink":
        cv.set(26, 9, "a")
        cv.set(27, 9, "a")
        cv.set(28, 12, "i")
        cv.set(31, 13, "a")
        cv.set(30, 13, "a")
    elif face == "happy":
        # 瞇眼 ^ ^、張嘴吐舌、腮紅
        cv.set(26, 9, "a")
        cv.set(27, 8, "a")
        cv.set(28, 9, "a")
        cv.set(27, 11, "i")
        cv.set(28, 11, "i")
        cv.set(29, 13, "a")
        cv.set(30, 13, "g")
        cv.set(31, 13, "g")
        cv.set(32, 13, "a")
        cv.set(30, 14, "h")
        cv.set(31, 14, "h")
        cv.set(29, 14, "a")
        cv.set(32, 14, "a")
        cv.set(30, 15, "a")
        cv.set(31, 15, "a")
    return cv


def tail(angle_deg: float) -> Canvas:
    """毛茸茸的尾巴,根在右下角 (TW-2, TH-2),往左伸。angle 0 = 平放,正數 = 往上翹。"""
    cv = Canvas(TW, TH)
    root = (TW - 2.0, TH - 2.5)
    a = math.radians(angle_deg)
    length = 10.0
    steps = 14
    for i in range(steps + 1):
        t = i / steps
        # 稍微彎曲:越到尾端越往上捲
        bend = a + 0.55 * t * t
        x = root[0] - math.cos(bend) * length * t
        y = root[1] - math.sin(bend) * length * t
        r = 2.0 - 0.9 * t
        cv.ellipse(x, y, r + 0.3, r, base="b", hi="c", lo="f")
    # 尾端的淺色
    tip_x = root[0] - math.cos(a + 0.55) * length
    tip_y = root[1] - math.sin(a + 0.55) * length
    cv.ellipse(tip_x, tip_y, 1.4, 1.2, base="c", hi="c", lo="c")
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
