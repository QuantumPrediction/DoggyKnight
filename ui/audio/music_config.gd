class_name MusicConfig
extends Resource
## 背景音樂的可調數值(C 線,CP6)。資料檔:ui/audio/music_config.tres。

## 一般音量(dB)。音效約在 0 dB,音樂放低一點,不蓋過打擊聲。
@export var volume_db: float = -9.0
## 暫停選單打開時再壓低多少(dB)。
@export var duck_db: float = -10.0
## 換曲時的交叉淡入淡出秒數。
@export var crossfade: float = 0.8
## 播短曲(過關、失敗、第一章完)前,原本的曲子用多快淡出。
@export var jingle_fade_out: float = 0.25
## 個別曲目的音量微調(dB),例如 {&"camp": -1.0}。
@export var track_trim_db: Dictionary = {&"victory": 1.5, &"chapter_clear": 1.5, &"fail": 0.0, &"camp": 0.0}
