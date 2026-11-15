class_name MinigameConfig
extends Resource
## 所有小遊戲共用的可調數值(DEV_PLAN 11 D4)。每個小遊戲用一個 .tres,
## 可以是這個類別,或繼承它的類別(例如 ScrollMinigameConfig)。

## 送出 EventBus.minigame_finished 時用的代號,例如 &"scroll"。
@export var minigame_id: StringName = &""
@export var grading: MinigameGrading
## 遊戲時間(秒)。
@export var duration_sec: float = 15.0
## 開始前的倒數(秒)。倒數期間會播放「怎樣玩」的提示動畫。
@export var countdown_sec: float = 3.0
## 時間到之後,等多久才顯示評價(讓結束動畫播完)。
@export var results_delay_sec: float = 1.2
## 評價畫面至少停留多久才接受「點一下繼續」,避免玩家連點時誤跳過。
@export var results_min_sec: float = 1.0
## 評價畫面自動關閉的秒數;0 表示一直等到玩家點一下。
@export var results_auto_close_sec: float = 0.0
## 切回遊戲時是否自動繼續。false:停在暫停畫面,等玩家點一下(手機上較安全)。
@export var resume_on_foreground: bool = false
## 時間剩下多少秒時,計時條開始閃爍。
@export var time_warning_sec: float = 3.0
