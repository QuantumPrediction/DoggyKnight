class_name Layout
extends RefCounted
## 遊戲區內的固定版面(DEV_PLAN 4.9)。座標是遊戲世界座標,遊戲區為 (0,0) 至 (180,320)。

const TILE: int = 16

## 可戰鬥區域:11×14 格,水平置中;上方留給 HUD,下方留給必殺技按鈕與拇指。
const ARENA_RECT: Rect2 = Rect2(2, 72, 176, 224)

## HUD 在遊戲區內佔用的範圍(介面實際位置另以 SafeArea 調整)。
const HUD_RECT: Rect2 = Rect2(0, 0, 180, 72)

## 金毛每關開始的位置(場地中央偏下,讓上方出現的敵人有反應時間)。
const PLAYER_START: Vector2 = Vector2(90, 232)
