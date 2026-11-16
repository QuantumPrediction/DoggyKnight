class_name DialogueConfig
extends Resource
## 對白框的可調數值(C 線,CS1)。資料檔:ui/dialogue/dialogue_config.tres。

## 逐字顯示的速度(每秒幾個字)。
@export var chars_per_second: float = 30.0
## 遇到標點(,。!?…)時多停一下(秒)。
@export var punctuation_pause: float = 0.12
## 每顯示幾個字播一次說話音效。
@export var blip_every: int = 2
## 說話音效的音量(dB)。
@export var blip_volume_db: float = -8.0
## 每個說話者的音高(找不到時用 1.0;旁白不播說話音效)。
@export var speaker_pitch: Dictionary = {
	"goldie": 1.3, "bulldog": 0.78, "merlin": 0.95, "black_knight": 0.55, "morgana": 1.12,
	"scarecrow_captain": 0.68, "crow": 1.6,
}
## 新的一句出現後,至少等這麼久(秒)才接受下一下點擊,避免連點跳過。
@export var tap_guard: float = 0.15
## 一般對白時,畫面後方變暗的程度。
@export var dim_alpha: float = 0.3
## 繪本頁時,畫面後方變暗的程度。
@export var book_dim_alpha: float = 0.85
## 翻頁動畫(秒,一半合上、一半打開)。
@export var page_turn_time: float = 0.32
