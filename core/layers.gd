class_name Layers
extends RefCounted
## 碰撞圖層(DEV_PLAN 4.5)的位元遮罩常數。
## 用法:collision_layer = Layers.PLAYER;collision_mask = Layers.ARENA | Layers.ENEMY

const ARENA: int = 1 << 0          ## 1 場地
const PLAYER: int = 1 << 1         ## 2 主角
const COMPANION: int = 1 << 2      ## 3 同伴
const ENEMY: int = 1 << 3          ## 4 敵人
const PLAYER_ATTACK: int = 1 << 4  ## 5 我方攻擊判定
const ENEMY_ATTACK: int = 1 << 5   ## 6 敵方攻擊判定
const PICKUP: int = 1 << 6         ## 7 掉落物
