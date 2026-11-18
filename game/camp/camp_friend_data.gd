class_name CampFriendData
extends Resource
## 營地裡會說話的同伴(v2.7 DW1):崔斯坦、高文、摩根娜,以及第六章第二次營地「多出來」的湖中仙女。
## 一位同伴一份;全部放在 CampConfig.friends(game/camp/camp_config.tres),誰在哪一章的營地由
## CampConfig.cast_layouts 決定。圖用 C 線的 assets/sprites/<代號>/(C 線原地替換,這裡不用改)。
## 第一章至第三章的梅林、湖中仙女、蘭斯洛特、鬥牛犬仍用 v2.6 的專用類別(CampMerlin、CampLancelot)。

## 代號(和 cast_layouts 的鍵、對白的 speaker 代號相同),例如 &"tristan"。
@export var id: StringName = &""
@export var frames: SpriteFrames
@export var idle_animation: StringName = &"idle"
## 被點時播的動畫(播完或 tap_sec 秒後回到 idle)。
@export var tap_animation: StringName = &"attack"
## 放大倍數(整數:像素保持方正)。64 格的大圖(摩根娜)用 1。
@export var scale: float = 2.0
## 圖朝右畫;true = 朝左。auto_face 開著時這個只是預設值。
@export var flip: bool = false
## 自動轉向:站在圓桌中心右邊的人朝左、左邊的人朝右(大家都看著營火與圓桌)。
@export var auto_face: bool = true
## 點他時隨機說的話(翻譯鍵)。一輪說完才重複,不會連續兩次說同一句。空白 = 只做動作、不說話。
@export var lines: PackedStringArray = []
## 被點時的音效與音高(例如高文用低音的 bark)。
@export var sfx: StringName = &""
@export var sfx_pitch: float = 1.0
## 被點時的動作秒數。
@export var tap_sec: float = 0.7
## 被點時跳起幾像素。
@export var hop_px: float = 3.0
## 被點時的光(加亮混合);透明 = 不發光。
@export var glow_color: Color = Color(1, 1, 1, 0)
## 光的位置(相對圖中心,圖的像素;朝右時)。
@export var glow_offset: Vector2 = Vector2.ZERO
## 被點時冒的一次性特效(DEV_PLAN 4.10 的粒子,例如 sparkle);留空 = 不放。
@export var tap_particles: PackedScene
## 平常偶爾自己做的動作(例如崔斯坦彈琴);空白 = 不做。
@export var ambient_animation: StringName = &""
@export var ambient_every_min: float = 5.0
@export var ambient_every_max: float = 9.0
@export var ambient_sec: float = 1.6
## 做動作(被點或平常的動作)時頭上飄出音符(崔斯坦的豎琴)。
@export var music_notes: bool = false
@export var note_color: Color = Color("fff3a0")
## 呼吸的週期(秒);每位錯開一點,大家才不會一起上下動。
@export var breathe_sec: float = 2.2
## 觸控範圍比看得到的部分大多少(每邊,邏輯像素)。
@export var touch_margin: float = 4.0
## 對話泡泡的尾巴指向頭頂;這是頭頂相對圖上緣往下幾像素(圖的像素;圖上面有空白時調大)。
@export var head_inset: float = 2.0
