class_name CampConfig
extends Resource
## 營地的可調數值與外觀(DEV_PLAN 11 D1、15 DP1)。實際數值在 game/camp/camp_config.tres。
##
## 美術替換:把正式圖填進 *_texture / *_frames 欄位即可,程式不用改。
## 欄位留空時,營地用程式畫的佔位圖(夜空、圓桌、營火)。

@export_group("流程")
## 營地畫在第幾層 CanvasLayer(最底的夜空)。景物、特效、介面依序用下一層、再下一層……共 4 層。
## 全部比 HUD(10)高,所以會蓋住 HUD;比暫停選單(20)低,所以暫停選單會蓋在營地上面。
@export var canvas_layer: int = 15
## 小遊戲的場景。日後加入大胃王等小遊戲時,換這裡或加入口。
@export var minigame_scene: PackedScene
## 每次進營地可以玩幾次小遊戲(避免無限刷獎勵)。0 表示不限。
@export var minigame_plays_per_visit: int = 1
## 「即將開放」等提示停留的秒數。
@export var toast_sec: float = 1.6
## 進營地時播的背景音樂(DEV_PLAN 4.10:營地自己播 camp)。
@export var music_track: StringName = &"camp"
## 進入營地、開關小遊戲時,畫面由黑淡入的秒數。
@export var fade_sec: float = 0.3

@export_group("摸摸頭")
## 每摸一次金毛增加的滿意度。
@export var pet_satisfaction_gain: int = 2
## 每次進營地,最多幾次摸頭會增加滿意度(之後金毛照樣開心,但不再加分)。
@export var pet_rewards_per_visit: int = 5
## 兩次摸頭之間至少隔多少秒(連點太快時忽略)。
@export var pet_cooldown_sec: float = 0.3
## 摸頭後金毛開心(瞇眼、豎耳、快速搖尾巴)的秒數。
@export var pet_react_sec: float = 1.1
## 進營地多少秒後,金毛頭上冒出「想被摸」的愛心泡泡(摸過就不再出現)。
@export var pet_hint_delay_sec: float = 1.5
## 摸頭的觸控範圍比金毛的圖大多少(每邊,邏輯像素)。
@export var pet_touch_margin: float = 6.0
## 冒出的愛心特效(DEV_PLAN 4.10 的一次性粒子)。
@export var heart_particles: PackedScene

@export_group("版面")
@export var button_size: Vector2 = Vector2(132, 26)
@export var button_gap: int = 6
## 選單底邊離安全區底邊的距離(避開系統手勢區)。
@export var menu_bottom_margin: float = 20.0
@export var title_font_size: int = 24
@export var button_font_size: int = 12
@export var small_font_size: int = 12

@export_group("金毛")
## 營地專用的金毛(卸下盔甲趴著,D 線畫的 game/camp/art/)。動畫:rest、blink、happy。
@export var goldie_frames: SpriteFrames
## 平常的動畫(呼吸)。
@export var goldie_animation: StringName = &"rest"
## 被摸時的動畫。
@export var goldie_happy_animation: StringName = &"happy"
## 眨眼的動畫(只有一格)。沒有時不眨眼。
@export var goldie_blink_animation: StringName = &"blink"
## 金毛的圖朝右畫;營地裡要朝左看著營火。
@export var goldie_flip: bool = true
@export var goldie_scale: float = 2.0
## 尾巴(獨立的圖,動畫 wag)。留空時用程式畫的尾巴。
@export var tail_frames: SpriteFrames
## 尾巴根部相對金毛圖中心的位置(朝右時;邏輯像素 ÷ goldie_scale)。
@export var tail_offset: Vector2 = Vector2(-11, 4)
## 尾巴每秒搖幾下(來回算一下);摸頭時乘上 pet_wag_mult。
@export var tail_wags_per_sec: float = 1.2
@export var pet_wag_mult: float = 3.0
## 每隔幾秒眨一次眼(隨機取這個範圍)。
@export var blink_every_min: float = 2.5
@export var blink_every_max: float = 5.0
@export var tail_color: Color = Color("e8b24a")

@export_group("鬥牛犬")
## GameState.level_index 達到這個值時,鬥牛犬坐在營火旁(第 3 關加入;第二次營地時 level_index = 3)。
@export var bulldog_from_level_index: int = 2
@export var bulldog_frames: SpriteFrames
@export var bulldog_animation: StringName = &"idle"
@export var bulldog_scale: float = 2.0
## 點鬥牛犬時「汪!」泡泡停留的秒數。
@export var bulldog_bark_sec: float = 0.9

@export_group("故事(DS1)")
## 進營地時播的對白:GameState.level_index → 對白檔(B 線依 docs/STORY.md 建立)。
## 第一次營地(1-2 之後,level_index = 1)播 camp1;第二次(1-4 之後,= 3)播 camp2。
## 用路徑字串:檔案還不存在時安靜略過,直接顯示選單。
@export var story_paths: Dictionary[int, String] = {1: "res://data/story/camp1.tres", 3: "res://data/story/camp2.tres"}
## 對白框(C 線,DEV_PLAN 4.11)。留空時用 ui/dialogue/dialogue_box.tscn。
@export var dialogue_box_scene: PackedScene

@export_group("梅林(DS2)")
## 梅林的圖(C 線,動畫 idle、run、cast)。留空時用 assets/sprites/merlin/merlin_frames.tres;沒有圖就不出現。
@export var merlin_frames: SpriteFrames
@export var merlin_idle_animation: StringName = &"idle"
@export var merlin_cast_animation: StringName = &"cast"
@export var merlin_scale: float = 2.0
## 梅林的圖朝右畫;true = 朝左。
@export var merlin_flip: bool = false
## 梅林相對圓桌中心的位置(邏輯像素)。坐在桌子後面:圖的下半部被桌面遮住。
@export var merlin_offset: Vector2 = Vector2(-22, -20)
## 手杖頂端相對梅林圖中心的位置(朝右時;梅林的圖的像素)。閃光從這裡冒出。
@export var merlin_staff_tip: Vector2 = Vector2(9, -7)
## 平常每隔幾秒施法一次(隨機取這個範圍;max 為 0 表示平常不施法)。
@export var merlin_cast_every_min: float = 6.0
@export var merlin_cast_every_max: float = 11.0
## 一次施法的秒數。
@export var merlin_cast_sec: float = 0.9
## 施法時手杖冒出的閃光(DEV_PLAN 4.10 的一次性粒子)。
@export var merlin_sparkle_particles: PackedScene
@export var merlin_glow_color: Color = Color(0.55, 0.75, 1.0, 0.35)
## 點梅林時隨機說的話(翻譯鍵,i18n/strings.csv)。不會連續兩次說同一句。
@export var merlin_lines: PackedStringArray = ["CAMP_MERLIN_01", "CAMP_MERLIN_02", "CAMP_MERLIN_03",
		"CAMP_MERLIN_04", "CAMP_MERLIN_05", "CAMP_MERLIN_06"]
## 對話泡泡停留的秒數。
@export var merlin_bubble_sec: float = 3.2
## 對話泡泡最寬多少(邏輯像素)。
@export var merlin_bubble_width: float = 150.0
## 兩次點梅林之間至少隔多少秒(連點太快時忽略)。
@export var merlin_tap_cooldown_sec: float = 0.6
## 點梅林時的音效(C 線的 magic;檔案不存在時安靜略過)。
@export var merlin_sfx: StringName = &"magic"
## 點梅林的觸控範圍比看得到的部分大多少(每邊,邏輯像素)。
@export var merlin_touch_margin: float = 4.0

@export_group("營火與夜空")
## 營火的火星數量(CPUParticles2D;手機效能:保持少量)。
@export var ember_amount: int = 10
## 營火的煙數量。
@export var smoke_amount: int = 4
## 營火光暈閃爍的幅度(0 = 不閃)。
@export var fire_flicker: float = 0.12
## 螢火蟲數量。
@export var firefly_count: int = 7
## 流星出現的間隔(秒,隨機取這個範圍)。
@export var shooting_star_every_min: float = 3.0
@export var shooting_star_every_max: float = 7.0
## 星星的數量。
@export var star_count: int = 34

@export_group("美術(留空 = 程式畫的佔位圖)")
## 整個營地背景。至少 200×440,置中對齊遊戲區(和場地背景相同的約定)。
@export var background_texture: Texture2D
@export var table_texture: Texture2D
@export var fire_frames: SpriteFrames
@export var fire_animation: StringName = &"default"

@export_group("顏色(佔位圖用)")
@export var sky_top_color: Color = Color("141030")
@export var sky_bottom_color: Color = Color("3a2c55")
@export var ground_color: Color = Color("2e3b2a")
@export var ground_light_color: Color = Color("4a4a2e")
@export var table_color: Color = Color("8a5a32")
@export var table_edge_color: Color = Color("5a3418")
@export var fire_colors: Array[Color] = [Color("e8452c"), Color("ff9a2e"), Color("ffe36a")]
@export var glow_color: Color = Color(1.0, 0.55, 0.2, 0.05)
@export var vigor_bar_color: Color = Color("7ed957")
@export var satisfaction_bar_color: Color = Color("ff8fb0")
