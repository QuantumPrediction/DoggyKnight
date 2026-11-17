# 《金毛騎士》原型開發計劃(給 Claude Code)

版本:v2.4,2026-11-17。工作名稱《金毛騎士》,repo:`DoggyKnight`。

**最終目標:一款在 App Store(iOS)與 Google Play(Android)上架的手機遊戲。** 原型本身不公開上架,但從第一天起就按手機與商店的要求來做,避免日後返工。

這份文件是四個 Claude Code 工作階段(下稱「線」)同時開發的唯一依據。每條線開工前必須讀完第 1 至 5 節(包括 4.9 整合約定),以及自己那一線的章節。商店規定、費用與送審清單集中在 `docs/STORE_RELEASE.md`(D 線與整合工作階段必讀)。

### v2.4 變更摘要(玩法深度,相對 v2.3)

- 擁有人要求繼續深化,並參考同類型最受歡迎的遊戲(《Archero》的「移動閃避、停下攻擊」與技能抉擇;《Vampire Survivors》《Survivor.io》的技能進化、寶箱與無盡模式;《Brotato》《Soul Knight》的局外成長)。**只參考玩法機制,名稱、角色、美術全部原創。**
- **範圍變更(擁有人要求)**:把戲進化與 6 個新把戲;寶箱;關卡中途的抉擇事件;零食經濟、營地訓練(用遊戲內零食做永久升級,**不涉及真錢,不是商店**)與零食復活;通關後的「無盡試煉」。
- 合約補充見 4.12;任務見第 17 節。不重建 APK(擁有人指示:最後才建)。

### v2.3 變更摘要(深化,相對 v2.2)

- 擁有人問「故事夠不夠好玩?敵人是否太容易?畫面是否太簡單?」並要求再深化。**範圍變更(擁有人要求)**:
  - 加入完整的第一章故事:開場繪本、每關前後的頭像對白、營地對白、結局與第二章預告(`docs/STORY.md`)。仍然不做動畫過場(劇情動畫)。
  - 小怪由兩種增加為四種:新增稻草人弓兵(遠程)、空盔甲兵(重裝);1-4 新增中頭目稻草人隊長;黑騎士新增招式。
  - 打完第一章後解鎖困難模式。
  - 美術提升:角色頭像、繪本插畫、光影、前景層次、更細緻的動畫。
- 合約補充(4.11):`boss_appeared`、`dialogue_started`、`dialogue_finished` 三個訊號;`GameState` 加 `difficulty`、`chapter_cleared`、`story_seen`;新資料類別 `DialogueLine`、`DialogueScript`;`LevelData` 加 `story_before`、`story_after`;對白框;`i18n/story.csv`。
- 新增第 16 節「深化」:四條線的任務。
- 詳細記錄:`docs/requests/20261116-INT-v2.3-story-contract.md`。

### v2.2 變更摘要(M3 打磨,相對 v2.1)

- 擁有人要求「遊玩性高、觀賞性更高級、遊戲體驗達致頂級」。新增第 15 節「M3 打磨」:四條線各自的打磨任務與品質標準。
- 合約補充(4.10):`boss_hp_changed`、`combo_changed` 兩個訊號;`GameState` 加音樂、震動、教學、最佳星數;`LevelData` 加星級門檻;`SpawnEntry` 加出場隊形;`Haptics` 震動工具;`Music` 背景音樂 Autoload;畫面轉場;一次性粒子特效;三個新背景。
- 背景音樂由「暫不做」改為本輪製作(擁有人要求的頂級體驗)。
- 詳細記錄:`docs/requests/20261116-INT-v2.2-polish-contract.md`。

### v2.1 變更摘要(整合約定,相對 v2)

- 合約補充(已由擁有人授權整合工作階段決定):`exp_collected`、`ultimate_requested` 兩個訊號;`LevelData` 加 `companions`、`background`;資料的名稱欄位改存翻譯鍵;金毛基準數值移到 A 線的 `data/player/`。
- 新增 4.9「整合約定」:場地、同伴、畫面、營地、音效、特效、背景、版面、暫停與數值套用的固定做法。四條線都必讀。
- 新增共用目錄 `i18n/`(文字)與 C 線的 `Sfx` 音效 Autoload。
- 詳細記錄:`docs/requests/20261115-INT-v2.1-integration-contract.md`。

### v2 變更摘要(相對 v1)

- 目標平台由「只做 Android APK」改為「App Store + Google Play」。iOS 建置由「不包含」移入 M3(TestFlight)。
- Android 交付物改為 AAB(Google Play 規定的格式);APK 只用來在實機除錯。
- 新增手機規則:安全區、不同長寬比都填滿畫面、切到背景自動暫停並存檔、Android 返回鍵、不連網、不收集資料(第 2、4.8、5 節)。
- 合約補上暫停與手機生命週期的訊號(4.1、4.2、4.4、4.8)。
- 新增目錄擁有權:`export_presets.cfg`、`android/`、`store/`、`docs/licenses.md`(第 3 節)。
- 觸控目標尺寸改用邏輯像素訂明(第 10 節)。
- 新增任務:C13 App 圖示與啟動畫面、D10 iOS 匯出、D11 商店素材草稿。新增里程碑 M4 上架準備(第 6、14 節)。
- Godot 版本規則:各線仍不得升級;整合工作階段在擁有人同意下,可為符合商店的新規定而升級。

---

## 0. 給專案擁有人的操作步驟

1. 把 `CLAUDE.md`、`docs/DEV_PLAN.md`、`docs/KICKOFF_PROMPTS.md`、`docs/STORE_RELEASE.md` 放進 repo 並推上 `main`。
2. **盡早申請開發者帳號。** 審核需要時間,不必等程式寫好(詳見 `docs/STORE_RELEASE.md`):
   - Google Play Console:一次性 US$25,需要身分驗證。用「個人」帳號的話,正式上架前必須先讓**至少 12 位測試者連續 14 天**參加封閉測試。這可以和 M3 試玩合併進行,所以 M3 之前要先找好測試者。
   - Apple Developer Program:每年 US$99。iOS 版必須在 **Mac + Xcode 26 或以上**建置與上傳。沒有 Mac 就要租用雲端 Mac,否則 iOS 版延到 M4。
3. 開 **一個** Claude Code 工作階段,貼上 `KICKOFF_PROMPTS.md` 的「Phase 0」指示。等它完成並合併到 `main`。**Phase 0 未合併前不要開四條線。**
4. 開四個工作階段,分別貼上 A、B、C、D 線的指示。
5. 每條線每次收工都會更新 `docs/status/LINE_X.md` 並開 PR。合併次序見第 7 節。
6. 四條線都到達里程碑 M1 後,開一個「整合」工作階段(指示在 `KICKOFF_PROMPTS.md`)。
7. 任何一線提出「合約變更申請」(`docs/requests/`)時,由你決定是否接受,再交給整合工作階段修改 `core/`。
8. M3 之前決定 App 名稱與套件識別碼(第 2 節)。第一次上傳到商店之後,套件識別碼就不能再改。

---

## 1. 原型的目標與範圍

**原型要回答的問題只有一個:「金毛帶著同伴打小怪、升級選把戲、打頭目」這個核心循環好不好玩。**

但原型要用「會上架的手機遊戲」的標準來做:直向單手玩、只用觸控、適配各種手機螢幕、被來電或通知打斷也不會遺失進度。

### 包含

- 第一章「石中劍」的第 1 至 5 關,加第 6 關頭目戰:守橋的黑騎士(被魔法驅動的空盔甲)。
- 主角金毛騎士:拖曳移動、停下自動揮劍、必殺技。
- 一位同伴:貝德維爾的英國鬥牛犬(自動跟隨、舉盾格擋)。
- 兩種小怪:稻草人兵(近戰)、烏鴉斥候(快速、俯衝)。
- 升級三選一,共 6 個「把戲」。
- 一個營地小遊戲:拉扯王室卷軸。
- 流程:標題 → 關卡 → 升級選擇 → 過關結算 → 營地 → 下一關;失敗 → 結算 → 重試。暫停選單(含音效開關)。製作名單與授權畫面。
- Android 測試版:可上傳到 Google Play「內部測試」或「封閉測試」的 AAB,以及實機除錯用的 APK。
- iOS 測試版:可上傳到 TestFlight 的建置。前提是擁有人已有 Mac(或雲端 Mac)與 Apple 開發者帳號;沒有的話,寫好步驟,留到 M4。

### 不包含(任何一線都不要做)

遊戲內商店、抽卡、內購、廣告、帳號、雲端存檔、劇情動畫、第二章以後的內容、其他同伴、多語言切換、iPad 專用版面、**公開上架**。只預留介面,不寫實作。

為甚麼原型不公開上架:Apple 規定試玩版、Demo、測試版不能放上 App Store,只能用 TestFlight 給測試者。Google Play 也有內部和封閉測試管道可用。原型通過試玩後,由擁有人決定加多少內容再正式上架(第 14 節)。

### 完成定義(整個原型)

- [ ] 在 Android 實機上,經 Google Play 內部測試安裝,從標題畫面玩到打敗黑騎士,全程不當機。
- [ ] (已具備 Mac 與 Apple 帳號時)iPhone 實機經 TestFlight 安裝,同樣可以玩完。
- [ ] 一關 60 至 90 秒;失敗後 2 秒內可以重試。
- [ ] 沒看過遊戲的人不需任何文字教學,10 秒內懂得移動與攻擊。
- [ ] 遊戲中切到別的 App、接電話或鎖螢幕再回來:遊戲已暫停,進度沒有遺失。Android 按返回鍵會打開暫停選單,不會直接關掉遊戲。
- [ ] 在有瀏海或挖孔、長寬比由 16:9 到 20:9 的手機上,介面不被遮住,畫面沒有明顯黑邊。
- [ ] 所有測試腳本通過(`tools/run_tests.sh`)。

---

## 2. 技術基礎

| 項目 | 決定 |
| --- | --- |
| 目標平台 | Android(Google Play)與 iOS(App Store)。只做手機直向。iOS 只支援 iPhone,iPad 不另做版面 |
| 引擎 | Godot 4 穩定版,建議 4.7.x(2026-11 最新穩定版是 4.7.2)。所選版本必須能匯出 Google Play 現時要求的 target API 36 AAB、支援 16 KB 記憶體分頁,並能配合 Xcode 26 建置 iOS。Phase 0 驗證後,把確切版本號寫進 `CLAUDE.md`。若三國專案用的版本較舊,本專案仍以符合商店要求為先。**四條線不得升級**;只有整合工作階段可在擁有人同意下,為符合商店的新規定而升級 |
| 算繪器 | 建議 Compatibility:2D 像素遊戲足夠,舊手機相容性最好。Phase 0 確認後寫進 `CLAUDE.md` |
| 語言 | GDScript,全部加型別標註 |
| 畫面 | 直向鎖定。遊戲區邏輯解析度 180×320,整數倍放大,像素不做平滑(nearest)。較長或較寬的手機,畫面向外延伸(stretch aspect `expand`),多出來的地方用場地背景填滿,不留黑邊。遊戲判定區仍是置中的 180×320 |
| 安全區 | HUD 與按鈕必須避開瀏海、挖孔、圓角與 iOS 底部橫條,用 `core/` 提供的安全區工具計算(4.8) |
| 格子 | 地圖格 16×16;金毛與同伴 24×24;小怪 16 至 24;頭目 48 至 64 |
| 場地 | 每關一個單畫面場地,不捲動。可戰鬥區域約 11×14 格,上方留給 HUD |
| 輸入 | 只有觸控:按住任意位置出現虛擬搖桿,拖曳移動;放手即停下並自動攻擊。只認第一根手指,其他手指不影響移動。重要按鈕不放在螢幕最底或左右邊緣(系統手勢區)。桌面測試時,滑鼠等同觸控 |
| 手機生命週期 | 切到背景、來電、鎖螢幕:自動暫停並存檔。Android 返回鍵或返回手勢:打開暫停選單,不直接退出(4.8) |
| 效能與電量 | 目標 60 FPS。高更新率手機也鎖 60,以省電和保持手感一致。中階 Android 手機上 40 隻敵人仍維持 60 FPS(D9) |
| 隱私 | 原型不連網、不收集任何個人資料或裝置識別碼。遊玩記錄只存在本機。這樣兩家商店的隱私問卷都可以填「不收集資料」 |
| 套件識別碼 | Android package name 與 iOS Bundle ID 用同一個,由擁有人在 M3 前決定(格式如 `com.yourstudio.doggyknight`)。在此之前用佔位值。**第一次上傳商店後永遠不能改** |
| 資料 | 敵人、關卡、把戲、同伴全部用 `Resource`(`.tres`)描述,數值不寫死在程式裡 |
| 外掛 | 原型階段不裝任何第三方外掛 |

---

## 3. 目錄與擁有權

**每條線只能修改自己擁有的目錄。** 別線的目錄只能讀,不能改。

| 路徑 | 擁有者 | 內容 |
| --- | --- | --- |
| `project.godot`、`core/`、`CLAUDE.md`、`docs/DEV_PLAN.md`、`docs/STORE_RELEASE.md`、`tools/run_tests.sh`、`tools/placeholders/`、`tests/framework/`、`tests/core/`、`tests/phase0/`、`.gitignore` | Phase 0 / 整合 | 專案設定、事件匯流排、全域狀態、資料類別、手機生命週期、畫面適配、測試框架與合約測試。**四條線一律不得修改** |
| `game/actors/`、`game/combat/`、`data/enemies/`、`data/companions/`、`data/player/`、`tests/line_a/` | A 線 | 角色、敵人、同伴、戰鬥、金毛基準數值 |
| `game/flow/`、`game/progression/`、`data/levels/`、`data/tricks/`、`tests/line_b/` | B 線 | 關卡流程、波次、經驗、把戲、存檔、暫停 |
| `assets/`、`ui/`、`tools/pixel/`、`tests/line_c/` | C 線 | 像素圖、動畫、介面、字型、音效、App 圖示 |
| `game/camp/`、`game/minigames/`、`platform/`、`export/`、`export_presets.cfg`、`android/`、`store/`、`tests/line_d/` | D 線 | 營地、小遊戲、手機建置、商店素材草稿 |
| `docs/status/LINE_X.md` | 各線自己 | 進度報告 |
| `docs/requests/` | 任何線可新增檔案 | 合約變更申請 |
| `docs/licenses.md` | 任何線可新增條目(只加不刪) | 外部素材與授權記錄 |
| `i18n/strings.csv` | 任何線可新增條目(只加不刪);C 線可修改文字 | 全部介面與資料文字(翻譯鍵 → 繁體中文) |

Godot 特有的衝突點:

- `project.godot`(Autoload、輸入對應、圖層名稱、視窗與手機設定)只由 Phase 0 與整合工作階段修改。需要新增設定時提出申請,不要自己改。
- `export_presets.cfg` 是 Godot 固定放在專案根目錄的匯出設定;`android/` 是 Godot 安裝的 Android 建置範本(用 Gradle 建置 AAB 時需要)。兩者都歸 D 線。
- **金鑰與密碼一律不得提交到 repo**:Android 的 keystore、Apple 的憑證與描述檔都不行。Godot 4 把匯出密碼存在 `.godot/export_credentials.cfg`,這個檔案已被 `.gitignore` 排除。

---

## 4. 共用合約(Phase 0 建立,之後凍結)

四條線靠這些合約互相配合。開發時對方還沒完成的部分,用佔位或假資料代替,**不要等**。

### 4.1 EventBus(Autoload:`core/event_bus.gd`)

所有跨線通訊只走訊號,不互相直接呼叫場景內部節點。

```gdscript
# 戰鬥(A 線發出)
signal enemy_died(enemy_id: StringName, position: Vector2, exp_value: int)
signal player_damaged(amount: int)
signal vigor_changed(current: int, maximum: int)
signal loyalty_changed(current: float, maximum: float)
signal ultimate_used()
signal player_downed()                      # 活力歸零,金毛趴下睡著
signal boss_phase_changed(phase: int)
signal exp_collected(amount: int)          # 拾取經驗珠(原始值;exp_mult 由 B 線套用)

# 流程與成長(B 線發出)
signal level_started(level_id: StringName)
signal wave_started(index: int, total: int)
signal wave_cleared(index: int)
signal level_completed(level_id: StringName)
signal level_failed(level_id: StringName)
signal exp_changed(current: int, needed: int)
signal leveled_up(new_level: int)
signal trick_offered(options: Array)        # Array[TrickData]
signal trick_chosen(trick_id: StringName)   # 由 C 線的選擇介面發出
signal game_paused(paused: bool)            # B 線發出;C 線的暫停畫面聽這個

# 介面(C 線發出)
signal ultimate_requested()                 # HUD 的必殺技按鈕被按下;A 線執行後發 ultimate_used
signal resume_requested()                   # 暫停畫面的「繼續」
signal quit_to_title_requested()            # 暫停畫面的「回標題」

# 營地與小遊戲(D 線發出)
signal camp_entered()
signal minigame_finished(minigame_id: StringName, score: int, grade: int)  # grade 0 至 3
signal camp_left()

# 手機生命週期(core/app_lifecycle.gd 發出,Phase 0 實作)
signal app_backgrounded()                   # 切到背景、來電、鎖螢幕
signal app_foregrounded()
signal back_requested()                     # Android 返回鍵或返回手勢
```

### 4.2 GameState(Autoload:`core/game_state.gd`)

```gdscript
var player_stats: StatBlock       # 金毛目前數值(含把戲加成)
var vigor: int                    # 活力(生命值)
var satisfaction: int             # 滿意度 0 至 100,由小遊戲提高
var snacks: int                   # 零食(續關用,原型只做計數)
var chapter: int
var level_index: int
var hero_level: int
var active_tricks: Array[StringName]
var next_level_bonus: float       # 小遊戲表現換來的下一關加成
var sound_on: bool                # 音效開關,隨存檔保存
func reset_run() -> void
```

### 4.3 資料類別(`core/data/`)

- `StatBlock`:`max_vigor`、`move_speed`、`attack_damage`、`attack_interval`、`attack_range`、`damage_taken_mult`、`pickup_radius`、`exp_mult`。
- `EnemyData`:`id`、`display_name`、`scene: PackedScene`、`max_hp`、`contact_damage`、`move_speed`、`exp_value`。
- `CompanionData`:`id`、`display_name`、`scene`、`role`。
- `TrickData`:`id`、`display_name`、`description`、`icon`、`stat_modifiers: Dictionary`、`is_ability: bool`。
- `LevelData`:`id`、`display_name`、`waves: Array[WaveData]`、`is_boss: bool`、`arena_scene`、`companions: Array[StringName]`、`background: PackedScene`。
- `WaveData`:`spawns: Array[SpawnEntry]`(`enemy_id`、`count`、`delay`)。
- 所有 `display_name`、`description` 存**翻譯鍵**(例如 `ENEMY_SCARECROW`、`TRICK_SIT_DESC`),文字在 `i18n/strings.csv`,介面用 `tr()` 顯示。
- 金毛的基準數值:`data/player/goldie_base_stats.tres`(A 線擁有);`GameState.reset_run()` 會複製一份到 `player_stats`。

### 4.4 場景與介面合約

| 項目 | 路徑 | 合約 |
| --- | --- | --- |
| 主角 | `game/actors/player/player.tscn` | 根節點 `CharacterBody2D`,在群組 `player`;提供 `take_damage(amount: int)`、`heal(amount: int)` |
| 同伴 | `game/actors/companions/bulldog.tscn` | 群組 `companion` |
| 敵人 | 由 `EnemyData.scene` 指定 | 群組 `enemy`;提供 `setup(data: EnemyData)`、`take_damage(amount: int)` |
| 戰鬥場地 | `game/combat/arena.tscn` | 提供 `spawn_enemy(enemy_id: StringName, at: Vector2) -> Node`、`get_spawn_points() -> Array[Vector2]`、`clear() -> void`;另加(v2.1)`spawn_companion(companion_id: StringName) -> Node`、`set_background(scene: PackedScene) -> void`、`get_player() -> Node2D` |
| HUD | `ui/hud/hud.tscn` | 只聽 EventBus,不讀取任何戰鬥節點;位置依安全區排列 |
| 把戲選擇 | `ui/trick_choice/trick_choice.tscn` | 聽 `trick_offered`,玩家選擇後發出 `trick_chosen` |
| 暫停畫面 | `ui/pause/pause.tscn` | 聽 `game_paused`;按鈕發出 `resume_requested`、`quit_to_title_requested`;音效開關直接改 `GameState.sound_on` |
| 營地 | `game/camp/camp.tscn` | 進入時發 `camp_entered`,離開時發 `camp_left` |
| 標題 | `ui/screens/title.tscn` | 見 4.9 |
| 過關結算 | `ui/screens/results.tscn` | 見 4.9 |
| 失敗結算 | `ui/screens/failure.tscn` | 見 4.9 |
| 製作名單與授權 | `ui/screens/credits.tscn` | 見 4.9 |
| 音效 | `ui/audio/sfx.gd`(Autoload `Sfx`) | 見 4.9 |

### 4.5 碰撞圖層與角色代號

圖層:1 場地、2 主角、3 同伴、4 敵人、5 我方攻擊判定、6 敵方攻擊判定、7 掉落物。

角色代號(檔名、資料 id、動畫資源都用同一個):`goldie`、`bulldog`、`scarecrow`、`crow`、`black_knight`。

### 4.6 美術合約

- 圖檔:`assets/sprites/<代號>/<代號>.png`;動畫資源:`assets/sprites/<代號>/<代號>_frames.tres`(`SpriteFrames`)。
- 動畫名稱固定:`idle`、`run`、`attack`、`hurt`;頭目另加 `charge`、`slam`、`down`。
- 只畫朝右,朝左用鏡像。
- Phase 0 會先放純色方塊的佔位動畫資源,路徑與名稱完全相同。C 線日後**原地替換檔案**,不改路徑、不改名稱,A 線因此不需要改任何程式。
- 場地背景要比 180×320 大,至少畫到 200×440,遊戲區置中。這樣長螢幕或較寬的 iPhone 向外延伸時,看到的是場景,不是黑邊。

### 4.7 把戲清單(id 固定)

| id | 名稱 | 類型 | 效果(初始值,可調) | 實作 |
| --- | --- | --- | --- | --- |
| `sit` | 坐下 | 數值 | 受到的傷害 −20% | B 線(`stat_modifiers`) |
| `wag` | 搖尾巴 | 數值 | 移動速度 +15% | B 線 |
| `fetch` | 尋回 | 數值 | 拾取範圍 +50%,經驗 +20% | B 線 |
| `shake` | 握手 | 能力 | 每第 4 下攻擊造成雙倍傷害 | A 線(`game/combat/abilities/`) |
| `spin` | 轉圈 | 能力 | 每 6 秒一次迴旋斬,打中周圍所有敵人 | A 線 |
| `bark` | 吠叫 | 能力 | 每 8 秒一次,震懾附近敵人 1.5 秒 | A 線 |

數值類把戲由 B 線修改 `GameState.player_stats`;能力類把戲由 A 線聽 `trick_chosen` 後啟用。同一個把戲可重複選,效果疊加。

### 4.8 手機與平台合約

- **生命週期**(`core/app_lifecycle.gd`,Autoload,Phase 0 實作):把系統通知(應用程式暫停、失去焦點、返回鍵請求)轉成 4.1 的 `app_backgrounded`、`app_foregrounded`、`back_requested`。專案設定要讓返回鍵**不會**直接退出遊戲。
- **誰處理甚麼**:B 線收到 `app_backgrounded` 時暫停戰鬥並存檔。收到 `back_requested` 時:關卡中就打開暫停選單;已在暫停選單就繼續;在標題畫面就詢問是否離開(只限 Android;iOS 沒有返回鍵,也不應自行關閉 App)。
- **安全區**(`core/safe_area.gd`,class `SafeArea`,Phase 0 實作):提供 `get_safe_rect() -> Rect2`,傳回以遊戲邏輯座標表示的安全區域。C 線的 HUD 與按鈕據此排列;桌面測試時傳回整個畫面,並提供模擬瀏海的開關(`SafeArea.simulate_notch`)。另有 `get_game_rect()`(置中的 180×320 遊戲區)與 `get_screen_size()`。
- **畫面適配**(`core/screen_fit.gd`,Autoload `ScreenFit`,Phase 0 實作):視窗大小改變時,把畫面設為「視窗 ÷ 整數倍數」。結果:任何手機都是整數倍放大,畫面寬至少 180、高至少 320 邏輯像素,黑邊少於一個邏輯像素。例:1080×2400 的手機是 180×400;iPhone 15 是 196×426。
- **座標約定**:遊戲區佔世界座標 (0,0) 至 (180,320)。戰鬥場地與營地等場景用 `Camera2D`,把視角中心放在 `SafeArea.GAME_CENTER`,遊戲區就會置中;延伸出來的地方要有場地背景(4.6)。介面放在 `CanvasLayer`,用 `get_safe_rect()` 排列。碰撞圖層的位元遮罩用 `core/layers.gd` 的 `Layers` 常數。
- **模擬事件**:沙盒與測試要模擬切到背景或返回鍵時,呼叫 `AppLifecycle.simulate_background()`、`simulate_foreground()`、`simulate_back()`。桌面上按 Esc 等同 Android 返回鍵。
- **平台服務**:廣告、內購、分析一律只經 `platform/` 的介面呼叫(D7)。原型只有空實作,不得連網。

### 4.9 整合約定(v2.1,四條線必讀)

這些是接線時的固定做法。開發時對方還沒完成,就照這裡做替身。

**一關的組成(B 線組裝,A 線提供零件)**

1. B 線的關卡流程實例化 `LevelData.arena_scene`(預設 `game/combat/arena.tscn`),呼叫 `set_background(LevelData.background)`,再為 `LevelData.companions` 的每個代號呼叫 `spawn_companion()`。
2. `arena.tscn` 本身包含:地面與邊界、置中的 `Camera2D`(4.8)、主角(放在 `Layout.PLAYER_START`)。`get_player()` 傳回主角。
3. `spawn_enemy(id, at)` 讀取 `data/enemies/<id>.tres`;`spawn_companion(id)` 讀取 `data/companions/<id>.tres`。精英稻草人兵是獨立資料 `scarecrow_elite`(生命 75,A 線擁有),頭目是 `black_knight`。
4. 「場上敵人清空」以群組 `enemy` 的節點數為準(頭目召喚的小怪也算)。敵人死亡時,**立即**離開 `enemy` 群組,然後才播倒下動畫。
5. 版面:`core/layout.gd`。戰鬥區 `Layout.ARENA_RECT`(11×14 格),HUD 在其上方,必殺技按鈕在戰鬥區右下角、安全區之內。

**數值由誰套用**

- 傷害:A 線計算。金毛攻擊力 = `player_stats.attack_damage × (1 + GameState.next_level_bonus)`;受到的傷害 × `player_stats.damage_taken_mult`。
- 活力:A 線讀寫 `GameState.vigor`,每次改變發 `vigor_changed`;主角進場時也發一次,讓 HUD 有初始值。活力跨關保留(營地小遊戲會回復);B 線在新遊戲與重試時把活力設為上限。
- 經驗:A 線在拾取經驗珠時發 `exp_collected(原始值)`;B 線乘上 `player_stats.exp_mult` 後累計。
- `next_level_bonus`:D 線在小遊戲結束時設定;B 線在下一關**過關**後歸零(失敗重試時保留)。
- 把戲:數值類由 B 線改 `player_stats`(相加:`{"move_speed": 0.15}` 表示 +15%,以基準值計算);能力類由 A 線聽 `trick_chosen`,每多選一次就多疊一層。新遊戲時 B 線呼叫 `GameState.reset_run()`,A 線在主角進場時依 `GameState.active_tricks` 重建能力。

**暫停**

- B 線用 `get_tree().paused` 暫停。升級選把戲與暫停選單都會暫停,但只有暫停選單發 `game_paused`。
- C 線的暫停畫面、把戲選擇介面、HUD 的根節點設 `process_mode = PROCESS_MODE_ALWAYS`。A 線的節點維持預設(會被暫停)。
- 金毛倒下(`player_downed`)後,B 線等約 1 秒再發 `level_failed` 並顯示失敗結算;按「再試一次」後 2 秒內要回到戰鬥。

**介面場景(C 線製作,B 線實例化)**

- 每個介面場景的根節點是 `Control`(全螢幕錨點)。B 線把它們放在自己的 `CanvasLayer` 之下:HUD 第 10 層、把戲選擇與暫停第 20 層、結算與標題第 30 層。
- `ui/screens/title.tscn`:方法 `setup(has_save: bool)`;訊號 `new_game_pressed`、`continue_pressed`、`credits_pressed`。在 Android 上收到 `back_requested` 時由 B 線詢問是否離開。
- `ui/screens/results.tscn`:方法 `setup(result: Dictionary)`;訊號 `continue_pressed`。
- `ui/screens/failure.tscn`:方法 `setup(result: Dictionary)`;訊號 `retry_pressed`、`title_pressed`。
- `ui/screens/credits.tscn`:訊號 `closed`。內容用 `Engine.get_license_text()` 等(見 `docs/licenses.md`)。
- `result` 的鍵(B 線提供):`level_id: StringName`、`level_name: String`(翻譯鍵)、`victory: bool`、`time_sec: float`、`kills: int`、`tricks: Array`(這一關新學的把戲 id)、`hero_level: int`、`next_is_camp: bool`、`is_final: bool`(打敗黑騎士)。
- HUD 的必殺技按鈕在 `loyalty_changed` 的 current ≥ maximum 時出現,按下發 `ultimate_requested`。

**營地(D 線製作,B 線實例化)**

- B 線在第 2、4 關過關結算之後實例化 `game/camp/camp.tscn`,加到流程根節點之下;營地自己負責畫面(用 `SafeArea` 排版)。收到 `camp_left` 後,B 線移除營地並進入下一關。
- 小遊戲結束時,D 線直接更新 `GameState.vigor`(依評價回復)、`satisfaction`、`next_level_bonus`,再發 `minigame_finished`。

**音效、特效、背景、文字**

- 音效:任何線呼叫 `Sfx.play(&"<id>")`。固定的 id:`swing`、`hit`、`hurt`、`enemy_down`、`pickup`、`level_up`、`bark`、`boss_warning`、`ultimate`、`clear`、`fail`、`ui_tap`、`scroll`、`ink`。音效檔是 `assets/sfx/<id>.wav`(C 線);找不到檔案時安靜略過。
- 特效:`assets/fx/<名稱>/<名稱>_frames.tres`,動畫名稱 `default`。固定的名稱:`slash`(揮劍弧光)、`hit_spark`(命中火花)、`exp_orb`(經驗珠)、`ultimate_slash`(必殺技)、`dizzy_stars`(暈眩星星)、`dust`(腳步塵)。預警圈與預警線由 A 線用程式畫(紅色半透明,填滿表示即將命中)。
- 場地背景:`assets/backgrounds/<名稱>.tscn`,根節點 `Node2D`,在世界座標畫出 `Layout.ARENA_RECT` 的地面與周圍至少 (-10,-60) 至 (190,380) 的延伸區。固定的名稱:`sword_stone`(1-1,石中劍)、`meadow`(1-2 至 1-5)、`bridge`(1-6,石橋)。
- 把戲圖示:`assets/icons/tricks/<把戲 id>.png`(16×16,C 線)。B 線的把戲資料檔直接引用這個路徑。
- 文字:`i18n/strings.csv`(鍵, zh_TW)。新增鍵時用自己的前綴:A 線 `ENEMY_`、`COMPANION_`;B 線 `LEVEL_`、`TRICK_`;C 線 `UI_`;D 線 `CAMP_`、`MINIGAME_`。
- 所有佔位資源(特效、背景、音效 Autoload)已由整合工作階段放好;C 線原地替換,路徑與名稱不變。

**主場景**

- B 線建立 `game/flow/main.tscn`(開機後顯示標題)。整合時由整合工作階段把它設為主場景。

### 4.10 打磨合約(v2.2,四條線必讀)

**新訊號**

- `boss_hp_changed(current: int, maximum: int)`:A 線在頭目出場時與每次受傷時發出;C 線的 HUD 顯示頭目血條。
- `combo_changed(count: int)`:A 線在連擊數改變時發出(0 = 連擊中斷);C 線的 HUD 顯示連擊數。

**GameState 新欄位(B 線存檔、讀檔)**

- `music_on`、`haptics_on`(C 線暫停畫面的開關)、`tutorial_done`(第一關操作提示看過了)、`best_stars`(每關最佳星數)。`reset_run()` 不會重設它們。

**資料新欄位**

- `LevelData.par_time`(秒)、`LevelData.damage_budget`(點):B 線計算星級。★1 過關;★2 在 `par_time` 內過關;★3 這一關受到的傷害不超過 `damage_budget`。
- `SpawnEntry.pattern`:出場隊形 `edges`(預設)、`surround`、`line_top`、`corners`。B 線的波次生成器解讀。

**結算資料新增的鍵(B 線提供,C 線顯示)**

- `stars: int`(這次 0 至 3)、`star_goals: Array`(每項 `{"key": 翻譯鍵, "met": bool}`,依序為過關、時間、傷害)、`best_stars: int`、`new_best: bool`、`level_index: int`、`level_count: int`。

**工具與 Autoload**

- 震動:`Haptics.play(&"light" | &"medium" | &"heavy")`(`core/haptics.gd`)。只在手機上震動,遵守 `haptics_on`。用法:light = 介面輕觸、拾取;medium = 金毛被擊中、升級;heavy = 必殺技、頭目重劈、打倒頭目。Android 需要 VIBRATE 權限(D 線)。
- 音樂:`Music.play(&"<曲目>")`、`Music.stop()`、`Music.set_ducked(bool)`、`Music.refresh()`(`ui/audio/music.gd`,C 線)。循環曲目 `title`、`field`、`boss`、`camp`;短曲 `victory`、`fail`、`chapter_clear`。檔案 `assets/music/<id>.ogg` 或 `.wav`,找不到時安靜略過。誰播:B 線在標題、每關開始(1-6 用 `boss`)、過關、失敗、打完第一章時呼叫;D 線的營地自己播 `camp`;暫停選單打開時 B 線呼叫 `set_ducked(true)`。
- 轉場:`ui/transition/transition.tscn`(根節點 CanvasLayer,第 100 層)。B 線開機時加一次,換畫面時 `await cover()` → 換場景 → `await reveal()`。C 線原地替換成更好看的轉場,方法不變。
- 教學提示:`ui/hints/tutorial.tscn`(C 線)。B 線在 1-1 且 `tutorial_done == false` 時加到第 20 層;它自己看觸控輸入決定下一步(不吃掉觸控),完成時發 `finished` 訊號,B 線設 `tutorial_done = true` 並存檔。檔案不存在時 B 線略過。

**新資源(整合工作階段已放佔位版,C 線原地替換)**

- 一次性粒子特效:`assets/fx/particles/<名稱>.tscn`,根節點 `CPUParticles2D`,加進場景樹就噴發一次、播完自己刪除。名稱:`hit_burst`、`straw_bits`(稻草人倒下)、`feathers`(烏鴉倒下)、`confetti`(過關)、`level_up_pillar`、`shockwave`(頭目重劈)、`sparkle`、`ultimate_burst`、`footstep_dust`、`heart`、`star_burst`。
- 新背景:`wheat_field`(1-2 麥田小徑)、`farm_fence`(1-4 稻草人包圍網)、`crow_forest`(1-5 烏鴉之林)。原有的 `sword_stone`(1-1)、`meadow`(1-3)、`bridge`(1-6)。背景場景可以包含 `CanvasModulate` 營造該關的時段氣氛(早晨、黃昏、暴風雨夜)。
- 新增的音效 id(加在 4.9 的清單後面):`crit`、`combo`、`boss_roar`、`star`、`whoosh`、`heal`、`pet`、`perfect`、`countdown`。
- 可選的新動畫名稱:`goldie` 與 `bulldog` 的 `victory`(過關歡呼)。使用前先用 `has_animation()` 確認。

### 4.11 故事與深化合約(v2.3,四條線必讀)

**故事**:唯一依據是 `docs/STORY.md`(角色、插畫清單、全部對白的次序與說話者、播放規則);文字在 `i18n/story.csv`(鍵 `STORY_*`、名牌 `SPEAKER_*`)。

**新訊號**

- `boss_appeared(enemy_id: StringName)`:A 線在頭目或中頭目出場時發出;C 線的頭目血條用 `tr("ENEMY_" + id 大寫)` 顯示名字。
- `dialogue_started(script_id)`、`dialogue_finished(script_id)`:C 線的對白框發出。

**GameState 新欄位(B 線存檔、讀檔)**

- `difficulty`(`&"normal"` 或 `&"hard"`;新遊戲時由標題畫面設定)、`chapter_cleared`(打完第一章,解鎖困難模式)、`story_seen`(看過的對白段落)。`reset_run()` 不會重設。
- 困難模式的最佳星數存在 `best_stars["<關卡 id>:hard"]`。

**資料**

- `DialogueLine`(`speaker`、`expression`、`text_key`、`illustration`)、`DialogueScript`(`id`、`lines`、`skippable`)。B 線依 `docs/STORY.md` 建立 `data/story/<段落 id>.tres`;D 線的營地讀 `data/story/camp1.tres`、`camp2.tres`。
- `LevelData.story_before`、`story_after`。

**對白框**(`ui/dialogue/dialogue_box.tscn`,C 線;整合工作階段已放可用的初版)

- 根節點 CanvasLayer(第 40 層),PROCESS_MODE_ALWAYS,加入群組 `dialogue_box`(測試與試玩機器人靠它自動略過對白);`await play(script)`;`advance()`、`skip()`、`is_active()`;顯示期間擋住全部觸控;結束時把段落 id 記進 `GameState.story_seen`。
- 頭像 `assets/portraits/<speaker>/<expression>.png`(48×48);繪本插畫 `assets/story/<id>.png`(160×120)。

**新角色與敵人(佔位圖已放好,C 線原地替換)**

| 代號 | 格子 | 動畫 | 說明 |
| --- | --- | --- | --- |
| `scarecrow_archer` | 24 | idle、run、attack、hurt、aim | 稻草人弓兵(遠程) |
| `armored_husk` | 24 | idle、run、attack、hurt、dash、down | 空盔甲兵(重裝、推不動) |
| `scarecrow_captain` | 32 | idle、run、attack、hurt、throw、rally、down | 中頭目稻草人隊長(1-4) |
| `merlin` | 24 | idle、run、cast | 梅林(營地與故事) |

投射物特效:`assets/fx/arrow`、`sword_wave`、`pitchfork`(動畫 `default`)。敵人資料 id 與代號相同(`data/enemies/<代號>.tres`,A 線)。

### 4.12 玩法深度合約(v2.4,四條線必讀)

**新訊號**:`chest_collected(tier)`(A 線:拾取寶箱;0 普通、1 精英、2 頭目)、`snack_collected(amount)`(A 線:拾取零食)、`trick_evolved(evolution_id)`(B 線:把戲進化)、`event_offered(event_id, options)`(B 線:抉擇事件;options 是 `Array[Dictionary]`,每項 `{"title": 翻譯鍵, "desc": 翻譯鍵, "icon": 路徑, "tone": "merlin"|"morgana"}`)、`event_chosen(event_id, option_index)`(C 線的事件介面)、`snacks_changed(total)`(B 線)。

**TrickData 新欄位**:`max_level`(預設 5)、`evolution_partner`、`evolves_into`、`is_evolution`。規則:一個把戲到 `max_level`(基本把戲設 3)且擁有 `evolution_partner` 時,下一次升級或寶箱的選項中會出現進化;選了就換成進化把戲(兩個原把戲的效果由進化版取代)。

**GameState 新欄位**:`mode`(`&"story"`、`&"endless"`)、`meta_upgrades`(營地訓練等級)、`endless_best`。`reset_run()` 不重設 `meta_upgrades`、`endless_best`。

**把戲 id(圖示佔位版已放在 `assets/icons/tricks/`)**

| id | 名稱 | 類型 | 效果(初始值) | 進化 |
| --- | --- | --- | --- | --- |
| `pounce` | 撲擊 | 能力 | 停下時若敵人在 60 像素內,先撲過去再揮劍 | + `zoomies` → `meteor_pounce` 流星撲擊 |
| `roll` | 打滾 | 能力 | 開始移動時翻滾 0.3 秒無敵(冷卻 3 秒) | 無 |
| `dig` | 挖寶 | 數值 | 敵人掉零食的機率 +50%,吃到零食回復 2 活力 | 無 |
| `sniff` | 嗅嗅 | 數值 | 拾取範圍 +30%,暴擊率 +8% | 無 |
| `play_dead` | 裝死 | 能力 | 每關一次:活力歸零時改為剩 1 並無敵 2 秒 | 無 |
| `zoomies` | 暴衝 | 能力 | 打倒敵人後 2 秒移動速度 +30% | 見上 |
| `tornado_tail` | 旋風尾 | 進化 | `spin` + `wag`:持續繞身旋轉的旋風 | — |
| `lion_roar` | 獅王吼 | 進化 | `bark` + `sit`:吠叫範圍加倍並造成傷害,震懾時金毛減傷 50% | — |
| `high_five` | 擊掌連打 | 進化 | `shake` + `fetch`:每第 3 下攻擊放出飛向最近敵人的掌印 | — |
| `meteor_pounce` | 流星撲擊 | 進化 | `pounce` + `zoomies`:撲擊落地造成小範圍衝擊 | — |

數值類由 B 線套用,能力類與進化由 A 線實作。

**新資源(佔位版已放好,C 線原地替換)**:寶箱 `assets/sprites/chest/chest_frames.tres`(idle、open,24×24)、零食 `assets/fx/snack/snack_frames.tres`(default)。

**介面新增(場景訊號,補充 4.9)**:失敗畫面 `revive_pressed`(只在結果字典 `can_revive` 為 true 時顯示按鈕);標題 `endless_pressed`(通關後才顯示,按下前設定 `GameState.mode = &"endless"`)與 `training_pressed`(開啟 D 線的訓練介面)。

**營地訓練**:升級 id `vitality`(活力上限)、`strength`(攻擊)、`agility`(速度)、`loyalty`(忠誠度累積)、`luck`(寶箱與零食機率),每項 5 級,資料在 `data/progression/meta_upgrades.tres`(B 線),介面 `game/camp/training.tscn`(D 線,營地與標題都可以打開)。

### 4.13 三章合約(v2.6,四條線必讀)

**章節模式**(像同類型手機遊戲的「章節」):三章,每章 6 關、2 次營地;**每章是獨立的一輪**(等級 1、沒有把戲),營地訓練的永久升級會帶過去。故事、角色與插畫見 `docs/STORY.md` 第 9 至 13 節。

**GameState**

- `chapter`(1 至 3):這一輪的章。標題畫面在發出 `new_game_pressed` 之前設定;`reset_run()` 不改它。B 線存進存檔(「繼續冒險」回到正確的章)。
- `chapters_cleared`(0 至 3,新欄位):已打完的最高章數,隨存檔保存。打完第 N 章時 B 線設 `chapters_cleared = max(chapters_cleared, N)`,並保持 `chapter_cleared = true`(第一章通關仍然是解鎖困難模式與無盡試煉的條件)。舊存檔:`chapter_cleared` 為 true 時視為 `chapters_cleared = 1`。
- 可以選的章:`1` 至 `min(chapters_cleared + 1, 3)`。

**資料(B 線)**

- `data/levels/chapter_<N>.tres`(ChapterData),關卡 `data/levels/level_<N>_<M>.tres`,id `"N-M"`,`display_name` `"LEVEL_N_M"`(翻譯已加)。章名翻譯鍵 `CHAPTER_N`(已加)。
- 對白段落 `data/story/<段落 id>.tres`;第 N 章(N ≥ 2)的段落 id 是 `cN_prologue`、`cNlM_before`、`cNlM_after`、`cN_camp1`、`cN_camp2`、`cN_teaser`。
- `LevelData.music`(新欄位):背景音樂 id;空白時一般關 `field`、頭目關 `boss`。第二章 `field_2`、`boss_2`,第三章 `field_3`、`boss_3`(C 線做音樂)。
- 頭目與最後一關的 id 一律以 `-6` 結尾;中頭目在 `-4`。

**新敵人(A 線,`data/enemies/<id>.tres`;圖 `assets/sprites/<代號>/`,佔位版已放好)**

| id | 圖的代號 | 格子 | 必要動畫 | 說明 |
| --- | --- | --- | --- | --- |
| `gargoyle` | gargoyle | 32 | idle、run、attack、hurt、swoop、stone | 石像鬼:飛行俯衝;每隔一段時間變成石頭(打不動、推不動) |
| `gargoyle_elite` | gargoyle(放大) | — | — | 中頭目石像鬼統領(2-4) |
| `spellbook` | spellbook | 24 | idle、run、attack、hurt、cast | 魔法書:保持距離,射出扇形光球 |
| `foxfire` | foxfire | 16 | idle、run、attack、hurt、burst | 狐火:成群、追蹤;靠近後預警圈再爆開 |
| `shadow_wolf` | shadow_wolf | 32 | idle、run、attack、hurt、dash、down | 影狼:成群繞圈,紅線預警後衝鋒 |
| `phantom_knight` | black_knight(半透明紫色) | — | — | 中頭目幻影黑騎士(3-4):更快、生命較少 |
| `green_knight` | green_knight | 64 | idle、run、attack、hurt、whip、summon、hat_off、down | 第二章頭目綠騎士 |
| `morgana` | morgana | 64 | idle、run、attack、hurt、cast、teleport、down | 最終頭目摩根娜 |

投射物特效(佔位版已放好,C 線原地替換):`assets/fx/magic_orb`、`thorn`、`fox_flame`、`moon_orb`(動畫 `default`)。敵人名字的翻譯鍵 `ENEMY_<ID 大寫>` 已加。

**新同伴**:`lancelot`(柴犬長槍騎士,`data/companions/lancelot.tres`,圖 `assets/sprites/lancelot/`:idle、run、attack、hurt、dash)。`LevelData.companions` 可以同時有兩位同伴(`[&"bulldog", &"lancelot"]`)。

**其他新圖**:`assets/sprites/lady_lake/`(湖中仙女,營地用:idle、run、cast);背景 `castle_town`、`castle_courtyard`、`royal_library`、`castle_wall`、`magic_garden`、`green_chapel`、`misty_lake`、`fairy_forest`、`stone_circle`、`crystal_cave`、`morgana_tower`、`tower_top`;頭像與插畫見 `docs/STORY.md` 第 10、11 節。全部由 `tests/core/test_v26_contract.gd` 檢查。

**難度**:`data/enemies/difficulty_scaling.tres` 增加每章的倍率(A 線),故事模式依 `GameState.chapter` 套用,和每關的遞增相乘。

**標題畫面**:`chapters_cleared ≥ 1` 時顯示選章(左右箭頭或三張章節卡;未解鎖的章顯示鎖頭)。按「新遊戲」前設定 `GameState.chapter`。

**營地**:第 N 章的營地播放 `cN_camp1`、`cN_camp2`(第一章仍是 `camp1`、`camp2`);第三章由湖中仙女代替梅林;蘭斯洛特從第二章第一次營地起出現在營地。

---

## 5. 所有線共同遵守的規則

1. **分支。** 從 `main` 上 Phase 0 完成的那個提交開分支:`line-a/combat`、`line-b/flow`、`line-c/art-ui`、`line-d/camp-mobile`。
2. **只改自己的目錄。** 見第 3 節。發現別線的錯誤,寫進自己的 status 檔,不要動手修。
3. **不等別人。** 需要別線的東西時,在自己的 `tests/line_x/` 內做假的替身(例如假敵人、假 HUD),照合約開發。
4. **合約要改怎麼辦。** 新增 `docs/requests/YYYYMMDD-<線>-<主題>.md`,寫明要改甚麼、為甚麼、影響哪些線。然後繼續做不受影響的部分。不得自行修改 `core/`。
5. **小步提交。** 每完成一個任務就提交並推送;提交訊息以 `[A]`、`[B]`、`[C]`、`[D]` 開頭。每天至少一次把 `main` 合併進自己的分支。
6. **每條線都要有可獨立執行的測試場景**,放在 `tests/line_x/`,不依賴別線的實作也能跑。
7. **每次收工更新 `docs/status/LINE_X.md`**,格式固定:已完成 / 進行中 / 被甚麼卡住 / 下一步 / 需要擁有人決定的事。
8. **PR 之前**執行 `tools/run_tests.sh`,全部通過才開 PR。PR 說明列出完成了哪些任務編號。
9. **數值放資料檔。** 任何可調的數字放在 `.tres` 或常數檔,不寫死。
10. **不要擴大範圍。** 第 1 節「不包含」的東西一律不做;想到好主意寫進 status 檔的「建議」欄。
11. **狗不會受傷。** 任何失敗或受擊表現都要可愛:冒星星、趴下睡著、被毛線纏住。不得出現血或受傷的畫面。這也讓商店的內容分級保持在最低級別。
12. **手機優先。** 每個功能都要在 180×320 直向、只用觸控(桌面以滑鼠模擬)的情況下驗證。不得依賴鍵盤、滑鼠右鍵或滑鼠懸停。
13. **不連網、不收集資料。** 原型的任何程式都不得發出網路請求、讀取裝置識別碼或收集個人資料。
14. **授權清楚。** 任何外部素材(圖、字型、音效、程式碼)使用前先核對授權,記錄在 `docs/licenses.md`。不得使用或模仿其他作品的角色與畫風。亞瑟王傳說屬公有領域,但不要模仿任何電影或動畫改編版本。商店審查會看這些。

---

## 6. 里程碑

| 里程碑 | 內容 | 完成條件 |
| --- | --- | --- |
| M0 地基 | Phase 0:單一工作階段建立骨架與合約 | `main` 上可開啟專案;佔位主角可在空場地移動;`run_tests.sh` 可執行 |
| M1 各線灰盒 | 四條線各自在測試場景中完成功能,用佔位圖 | 每條線的「M1 驗收」全部打勾 |
| M2 整合 | 整合工作階段依序合併四條線,接成完整流程 | 桌面上可從標題玩到打敗黑騎士 |
| M3 實機打磨 | Android 實機(經 Google Play 內部或封閉測試安裝);iPhone 實機(經 TestFlight,已具備條件時);手感調整、修錯 | 第 1 節的「完成定義」全部打勾 |
| M4 上架準備 | 擁有人決定繼續之後:補足上架內容、商店頁面、隱私權政策、內容分級、送審 | 見第 14 節與 `docs/STORE_RELEASE.md` |

**目前進度(2026-11-16):** M0、M1、M2 已完成;M3 進行中:第 15 節的打磨已完成並合併;第 16 節的深化(故事、新敵人、困難模式、美術提升)進行中。還沒有實機試玩。詳見 `docs/integration_report.md`。

時間無法準確預估。請以里程碑為準,不要以日期為準;每個里程碑完成後由擁有人試玩再決定是否繼續。

---

## 7. 合併次序

1. Phase 0 → `main`。
2. M1 期間各線隨時可開 PR,**只要沒有動到別線的目錄就可以合併**,次序不拘。C 線的美術替換可以最常合併。
3. M2 整合時,整合工作階段依 A → B → C → D 的次序檢查並接線:
   - A + B:波次生成器呼叫場地的 `spawn_enemy`;把戲生效。
   - + C:HUD、把戲選擇介面、暫停畫面、正式像素圖。
   - + D:過關後進營地、小遊戲結果影響下一關;Android 與 iOS 匯出。
4. 整合期間四條線暫停新功能,只修整合工作階段回報的錯誤。

---

## 8. A 線:戰鬥核心

**目標:** 在測試場地裡,金毛帶著鬥牛犬打稻草人兵與烏鴉斥候,並能打一場黑騎士頭目戰。全部使用佔位圖也要好玩。

**擁有:** `game/actors/`、`game/combat/`、`data/enemies/`、`data/companions/`、`tests/line_a/`。

### 任務

- [ ] A1 虛擬搖桿與移動:按住任意位置出現搖桿,拖曳移動;放手立刻停下。移動要有極短的加減速,不能滑。只認第一根手指;第二根手指按下或放開都不影響移動。
- [ ] A2 自動攻擊:停下時自動朝最近的敵人揮劍;移動中不攻擊。揮劍有明確的前搖與打擊停頓(hit stop)。
- [ ] A3 活力與受擊:受擊後短暫無敵與閃爍;活力歸零發出 `player_downed`。
- [ ] A4 敵人基礎類別:由 `EnemyData` 設定數值;被擊中有擊退與閃白;死亡發出 `enemy_died` 並掉落經驗珠。
- [ ] A5 稻草人兵:慢速接近,近身揮擊,攻擊前有 0.4 秒預警。
- [ ] A6 烏鴉斥候:在場邊盤旋,鎖定後直線俯衝,俯衝前有預警線。
- [ ] A7 經驗珠:靠近主角(`pickup_radius`)時被吸過去,拾取時通知 B 線(經 EventBus)。
- [ ] A8 同伴鬥牛犬:跟隨主角,自動走向最近的敵人並舉盾;格擋時吸引附近敵人改為攻擊牠;牠不會倒下,只會暈眩 3 秒。
- [ ] A9 忠誠度與必殺技:命中敵人累積忠誠度;滿了之後在畫面上出現按鈕(按鈕外觀由 C 線提供,A 線先做佔位),按下放出王者之劍的大範圍斬擊。按鈕放在拇指搆得到、位於安全區內、不貼螢幕最底的位置。按下按鈕的那根手指不得觸發搖桿。
- [ ] A10 三個能力類把戲:`shake`、`spin`、`bark`(見 4.7)。
- [ ] A11 黑騎士頭目:三種招式(直線衝鋒、原地重劈震波、召喚兩隻稻草人兵),每招都有清楚預警;生命降到一半進入第二階段,招式加快。被打敗時盔甲散落一地,裡面是空的。
- [ ] A12 戰鬥場地 `arena.tscn`:實作 4.4 的三個方法,邊界不可穿越。

### 初始數值(放在資料檔,之後調整)

| 對象 | 生命 | 傷害 | 速度(像素/秒) | 其他 |
| --- | --- | --- | --- | --- |
| 金毛 | 活力 100 | 10 | 70 | 攻擊間隔 0.5 秒,攻擊範圍 28 |
| 鬥牛犬 | 不會倒下 | 6 | 55 | 格擋時減傷 80% |
| 稻草人兵 | 25 | 8 | 28 | 經驗 1 |
| 烏鴉斥候 | 12 | 6 | 俯衝 140 | 經驗 1 |
| 黑騎士 | 450 | 衝鋒 18、重劈 22 | 40 | 經驗 20 |

### M1 驗收

- [ ] `tests/line_a/combat_sandbox.tscn` 可獨立執行:可選擇生成任何敵人與頭目。
- [ ] 連續打 3 分鐘小怪不當機、不卡牆、敵人不重疊成一點。
- [ ] 每種敵人的攻擊在命中前都看得出來。
- [ ] 自動化測試:傷害計算、死亡訊號、把戲能力觸發次數。

---

## 9. B 線:關卡流程與成長

**目標:** 把戰鬥組織成「六關加營地」的完整流程,並完成經驗、升級、把戲三選一、暫停與存檔。

**擁有:** `game/flow/`、`game/progression/`、`data/levels/`、`data/tricks/`、`tests/line_b/`。

### 任務

- [ ] B1 遊戲狀態機:標題 → 關卡 → (升級選擇) → 過關結算 → 營地 → 下一關;失敗 → 結算 → 重試或回標題。場景切換集中在 `game/flow/`。暫停時發 `game_paused`,並處理 `resume_requested`、`quit_to_title_requested`、`back_requested`、`app_backgrounded`(見 4.8)。
- [ ] B2 波次生成器:讀 `LevelData`,依序生成每一波;場上敵人清空才進下一波;最後一波清空發出 `level_completed`。開發時用假場地(實作同一組方法)測試。
- [ ] B3 六個關卡資料檔(見下表)。
- [ ] B4 經驗與升級:收到經驗後累計,達標發出 `leveled_up` 並暫停戰鬥。
- [ ] B5 把戲系統:升級時隨機抽 3 個不同把戲,發出 `trick_offered`;收到 `trick_chosen` 後套用。數值類把戲修改 `GameState.player_stats`。
- [ ] B6 六個把戲資料檔(見 4.7)。
- [ ] B7 過關與失敗結算的資料:用時、擊倒數、取得的把戲。畫面由 C 線做,B 線提供資料。
- [ ] B8 營地銜接:第 2、4 關過關後進營地;離開營地時把 `next_level_bonus` 套用到下一關。營地還沒完成時,用假營地(一個「繼續」按鈕)代替。
- [ ] B9 存檔:只存到達的關卡、零食數量與 `sound_on`,存在 `user://`。在每關開始、過關、切到背景時寫入。先寫暫存檔再改名,避免 App 被系統強制關閉時存檔損毀。關掉遊戲再開,可以從該關繼續。
- [ ] B10 難度參數集中在一個資料檔,方便 M3 調整。

### 關卡表(初始設計)

| 關 | 波次 | 內容 | 目的 |
| --- | --- | --- | --- |
| 1-1 | 2 | 稻草人兵 3,然後 4 | 學會移動與停下攻擊 |
| 1-2 | 3 | 稻草人兵 4;烏鴉 2;兩者混合 | 認識烏鴉。過關後進營地 |
| 1-3 | 3 | 混合,數量增加;鬥牛犬在此關開頭加入 | 認識同伴 |
| 1-4 | 3 | 大量稻草人兵包圍 | 逼玩家走位。過關後進營地 |
| 1-5 | 4 | 精英稻草人兵(生命 3 倍)加烏鴉群 | 檢驗把戲搭配 |
| 1-6 | 頭目 | 黑騎士 | 頭目戰 |

升級所需經驗(初始值):第 2 級 5,之後每級增加 3。目標是一關內升 1 至 2 級。

### M1 驗收

- [ ] `tests/line_b/flow_sandbox.tscn` 可獨立執行:用假場地與假敵人(點一下就死)跑完六關與兩次營地。
- [ ] 升級時戰鬥確實暫停,選完繼續。
- [ ] 模擬「切到背景」與「返回鍵」:戰鬥暫停、存檔已寫入、暫停選單出現。
- [ ] 自動化測試:波次順序、升級門檻、把戲抽選不重複、把戲套用後數值正確、存檔讀檔(含寫到一半中斷時舊存檔仍可讀)。

---

## 10. C 線:像素美術、介面與音效

**目標:** 提供全部像素圖與動畫、HUD 與各個畫面、字型與音效、App 圖示,並且原地替換佔位資源。

**擁有:** `assets/`、`ui/`、`tools/pixel/`、`tests/line_c/`。

### 美術方向

可愛、明亮、輪廓清楚。參考設計畫布上的「像素角色設定」與 App 圖示:金毛是奶油金色、垂耳、大眼睛,拿英式長劍,紅披風。中世紀童話風,不要黑暗寫實。全遊戲共用一個約 32 色的調色盤,放在 `assets/palette.png`。

### 任務

- [ ] C1 調色盤與像素生成工具:用程式把字元網格或資料轉成 PNG 與 `SpriteFrames`,放在 `tools/pixel/`,讓每張圖都可以重新生成。
- [ ] C2 金毛 `goldie`(24×24):`idle` 2 格、`run` 4 格、`attack` 3 格、`hurt` 1 格,另加 `sleep` 2 格(失敗時)。
- [ ] C3 鬥牛犬 `bulldog`(24×24):`idle`、`run`、`attack`、`hurt`,另加 `guard`(舉盾)。
- [ ] C4 稻草人兵 `scarecrow`(24×24)、烏鴉斥候 `crow`(16×16):四個基本動畫。
- [ ] C5 黑騎士 `black_knight`(48×48):`idle`、`run`、`attack`、`hurt`、`charge`、`slam`、`down`。
- [ ] C6 第一章場地圖塊(16×16):草地、石橋、城牆、裝飾;石中劍的石頭作為第一關背景物。每個場地背景至少畫到 200×440(見 4.6)。
- [ ] C7 特效:揮劍弧光、命中火花、經驗珠、預警圈與預警線、必殺技斬擊。
- [ ] C8 HUD:活力條、經驗條、等級、忠誠度條與必殺技按鈕、波次提示。只聽 EventBus。依 `core/safe_area.gd` 排列,不被瀏海或挖孔遮住;必殺技按鈕在拇指範圍內,但避開螢幕最底的系統手勢區。
- [ ] C9 把戲選擇介面:三張卡片,顯示圖示、名稱、一行說明;點選後發出 `trick_chosen`。六個把戲圖示(16×16)。
- [ ] C10 畫面:標題、過關結算、失敗結算(金毛睡著)、暫停(照 4.4 合約,含音效開關)、製作名單與授權(列出 Godot 引擎、字型及其他開源素材的授權聲明;這些授權要求在遊戲內列出)。
- [ ] C11 介面主題與字型:選一款支援繁體中文、授權允許商用的像素字型(候選:俐方體 11 號 Cubic 11;**使用前必須核對授權條款**並記錄在 `docs/licenses.md`)。
- [ ] C12 音效:揮劍、命中、受擊、拾取、升級、吠叫、頭目預警、過關。可用程式生成的 8-bit 音效;任何外部素材都要記錄授權。背景音樂原定暫不做,v2.2 起由第 15 節 CP6 製作。音效要遵守 `GameState.sound_on`。
- [ ] C13 App 圖示與啟動畫面:由 `tools/pixel/` 從同一張母圖生成,放在 `assets/app_icon/`。需要:1024×1024 母圖(iOS 用,不可透明,不要自己畫圓角,系統會裁);Android 自適應圖示的前景、背景、單色三層(各 432×432,主體放在中央約 60% 的圓內,避免被裁掉);Google Play 的 512×512 圖示與 1024×500 宣傳圖;啟動畫面。像素圖放大時一律用整數倍、不平滑。

### 規則

- 按 4.6 的路徑與動畫名稱原地替換佔位資源,不得改路徑或名稱。
- 觸控目標至少 24×24 邏輯像素,按鈕之間至少留 4 邏輯像素的間隔。在 1080 像素寬的手機上,24 邏輯像素約等於 Android 建議的 48dp,也約等於 iOS 建議的 44pt。文字與背景的對比要足夠。
- 介面文字先只做繁體中文,所有字串集中在一個檔案,方便日後翻譯。

### M1 驗收

- [ ] `tests/line_c/gallery.tscn` 可獨立執行:列出所有角色的所有動畫循環播放。
- [ ] `tests/line_c/ui_sandbox.tscn`:用按鈕模擬 EventBus 訊號,HUD、把戲選擇介面與暫停畫面有正確反應;開啟「模擬瀏海」後,HUD 不被遮住。
- [ ] 所有佔位圖都已被正式圖取代,A 線場景不需修改即可顯示新圖。
- [ ] `docs/licenses.md` 列出每個外部素材的來源與授權。

---

## 11. D 線:營地、小遊戲與手機建置

**目標:** 完成營地與「拉扯王室卷軸」小遊戲,並讓整個專案能在 Android 與 iPhone 實機上執行、能上傳到兩家商店的測試管道。

**擁有:** `game/camp/`、`game/minigames/`、`platform/`、`export/`、`export_presets.cfg`、`android/`、`store/`、`tests/line_d/`。開工前另讀 `docs/STORE_RELEASE.md`。

### 任務

- [ ] D1 營地場景:圓桌旁的營火,金毛卸下盔甲做回普通的狗(趴著、搖尾巴)。有三個入口:小遊戲、(預留)同伴、繼續冒險。預留入口顯示為「即將開放」。
- [ ] D2 小遊戲「拉扯王室卷軸」:金毛咬住卷軸一端,玩家快速向下滑動把卷軸拉出來,15 秒內拉得越長分數越高;卷軸上會經過墨水漬,滑到要停一下否則扣時間。結束時金毛被卷軸纏住。向下滑動的範圍不要碰到螢幕最底的系統手勢區(否則會誤觸回到主畫面)。
- [ ] D3 評分與獎勵:依長度給 0 至 3 級評價;回復活力(25% / 50% / 75% / 100%),提高滿意度,並設定 `next_level_bonus`(0 / 5% / 10% / 15% 攻擊加成)。發出 `minigame_finished`。
- [ ] D4 小遊戲框架:`game/minigames/` 內做一個共同基底(開始、計時、結束、回報),讓第二個小遊戲(圓桌盛宴大胃王)日後可以直接加入。小遊戲中切到背景時計時要暫停。**原型不做大胃王。**
- [ ] D5 觸控與螢幕適配:不同長寬比的手機(16:9 到 20:9,以及較寬的 iPhone)都保持整數倍放大,並向外延伸填滿畫面(第 2 節;縮放計算已由 Phase 0 的 `ScreenFit` 處理,D 線負責在各種比例與實機上驗證);處理瀏海與安全區;鎖定直向;iOS 隱藏狀態列、靜音鍵開著時不發聲;高更新率手機鎖 60 FPS。把需要的專案設定寫成申請,交整合工作階段套用。
- [ ] D6 Android 匯出:建立 Android 匯出設定,用 Gradle 建置。產出 AAB(上傳 Google Play)與除錯版 APK(實機測試)。target API 要符合 Google Play 現行要求(2026-08-31 起是 API 36),並確認支援 16 KB 記憶體分頁。寫 `export/README.md`:建置步驟、上傳金鑰(upload key)怎樣產生和備份、Play 應用程式簽署(Play App Signing)、怎樣上傳到「內部測試」。需要擁有人在本機安裝或提供的東西(Android SDK、JDK、金鑰、Play Console 帳號)逐項列清楚。
- [ ] D7 平台介面預留:`platform/` 內定義廣告、內購、分析三個介面的空實作(只印出記錄,不連網)。之後接真實外掛時不需改動遊戲程式。在 `platform/README.md` 註明:日後接真實服務時,商店的隱私問卷要重填;若目標玩家包含兒童,只能用符合 Google Play 家庭政策的服務。
- [ ] D8 最基本的遊玩記錄:每關的用時、勝負、所選把戲,寫到本機記錄檔,供 M3 調整難度。不含任何裝置識別碼,不上傳。
- [ ] D9 效能檢查:場上 40 個敵人時,在中階 Android 手機維持 60 FPS;提供一個壓力測試場景。
- [ ] D10 iOS 匯出:建立 iOS 匯出設定(只支援 iPhone、直向)。寫 `export/IOS.md`:擁有人在 Mac 上用 Xcode 26 或以上建置、簽署、上傳 TestFlight 的逐步說明,以及沒有 Mac 時的替代方案(例如 GitHub Actions 的 macOS 機器)。Linux 工作環境做不出 iOS 安裝檔,所以要列明已驗證與未驗證的步驟。
- [ ] D11 商店素材草稿(低優先,M4 前完成即可):在 `store/` 內準備:繁體中文商店說明草稿;隱私權政策草稿(內容是「不收集任何資料」);Google Play「資料安全」與 Apple「App 隱私」問卷的建議答案;內容分級問卷的建議答案;一個自動截圖場景,按商店要求的尺寸輸出遊戲截圖。

### M1 驗收

- [ ] `tests/line_d/camp_sandbox.tscn` 可獨立執行:進營地、玩小遊戲、拿到評價、離開。
- [ ] 小遊戲不需文字說明,5 秒內看得懂要做甚麼。
- [ ] 桌面上以多種視窗比例測試(至少 16:9、19.5:9、20:9,以及 iPhone 的寬度),畫面不變形、不裁切、沒有明顯黑邊。
- [ ] `export/README.md` 的步驟可以照著做出 AAB 與 APK(若工作環境沒有 Android SDK,列明已驗證與未驗證的步驟)。
- [ ] iOS 匯出設定已建立,`export/IOS.md` 已完成(未在 Mac 上驗證的步驟要標明)。

---

## 12. 整合工作階段(M2、M3、M4)

- 依第 7 節的次序把四條線接起來,修正接縫問題。
- 唯一可以修改 `core/`、`project.godot`、`docs/STORE_RELEASE.md` 的工作階段;處理 `docs/requests/` 內已獲擁有人同意的申請。
- M2 交付:桌面可完整遊玩的版本,加一份 `docs/integration_report.md`(已知問題、各線需要修的項目)。
- M3 交付:上傳到 Google Play 內部或封閉測試的 AAB;已具備條件時,TestFlight 建置;手感與難度調整建議;下一階段(第二章、第二位同伴、大胃王小遊戲)的工作量估計。
- M4 交付:照第 14 節與 `docs/STORE_RELEASE.md` 的清單送審。

---

## 13. 風險與對策

| 風險 | 對策 |
| --- | --- |
| 四條線互相覆蓋檔案 | 目錄擁有權;`core/` 與 `project.godot` 凍結 |
| 一條線等另一條線 | 合約先行;各線用替身測試場景獨立開發 |
| 合約想得不周全 | 合約變更申請流程,由擁有人決定,整合工作階段統一修改 |
| 核心手感不好玩 | A 線優先做 A1、A2、A4、A5,盡早請擁有人試玩;不好玩就先停下其他線 |
| 像素圖品質不足 | C1 的生成工具讓每張圖可以重畫;必要時改用外部像素畫工具或美術人員,檔案合約不變 |
| Android 建置卡住 | D6 盡早開始;卡住不影響其他線,桌面版照樣可以驗證玩法 |
| 範圍膨脹 | 第 1 節「不包含」清單;新想法只記錄不實作 |
| Google Play 個人帳號要 12 人連續 14 天封閉測試才能上架 | 盡早申請帳號;M3 試玩直接用封閉測試管道進行,一次滿足兩件事 |
| 沒有 Mac,做不出 iOS 版 | Android 先行;iOS 用雲端 Mac 或延到 M4。程式與設定從一開始就跨平台,不寫只限 Android 的東西 |
| 商店規定每年都會提高(Google 每年 8 月提高 target API;Apple 每年春天提高 Xcode 要求) | 規定集中記錄在 `docs/STORE_RELEASE.md`;整合工作階段每次送審前重新核對,必要時經擁有人同意升級 Godot |
| 送審被拒 | 不把試玩版公開上架;不收集資料;素材授權清楚;送審前照 `docs/STORE_RELEASE.md` 清單自查 |
| 套件識別碼或 App 名稱日後想改 | M3 前定案;第一次上傳後套件識別碼不能改,App 名稱也要先在兩家商店查重 |

---

## 14. 上架(M4,原型通過試玩之後)

**進入條件:** 擁有人試玩過 M3 版本,決定繼續。M4 開工前,擁有人要先決定以下幾件事(建議與選項的利弊見 `docs/STORE_RELEASE.md` 第 4 節):

1. 上架版本的內容量:只有現在的 6 關,還是先補足更多內容。內容太少容易被玩家評低分。
2. 收費模式:付費下載、免費加廣告,或免費加內購。這會影響隱私問卷、內容分級,以及要接哪些平台服務。
3. 目標年齡:是否包含 13 歲以下兒童。包含的話,要遵守 Google Play 家庭政策,廣告與分析服務會受到很多限制。
4. 上架地區:中國大陸的 App Store 上架遊戲需要版號,手續繁複,建議第一次上架先不包括。

**工作內容:** 照 `docs/STORE_RELEASE.md` 的清單完成商店頁面、截圖、隱私權政策網址、內容分級、封閉測試(如未完成),然後送審。第 1 節「不包含」清單在 M4 由擁有人重新檢討,需要時發出 v3 計劃。

---

## 15. M3 打磨(v2.2)

**目標:** 擁有人要求「遊玩性高、觀賞性更高級、遊戲體驗達致頂級」。原型已經可以由頭玩到尾,本輪把它打磨成像正式上架遊戲的品質。範圍仍是第 1 節的內容(第一章六關、一位同伴、兩種小怪、一個頭目、一個小遊戲),**不加新角色、新關卡或第 1 節「不包含」的東西**,只把現有的東西做得更好看、更好玩。

### 品質標準(所有線)

1. **每個動作都有回饋。** 按下、命中、受擊、拾取、升級、過關:同一格內要有畫面回饋,大部分有音效,重要的在手機上有震動(`Haptics`)。
2. **一眼看懂。** 危險的東西(預警)永遠是最顯眼的;特效不可以蓋住預警或金毛。
3. **有節奏。** 關卡有開場(標題卡)、高潮(最後一波或頭目)、收尾(慶祝),不會突然開始或突然結束。
4. **有個性。** 金毛和鬥牛犬要可愛、有表情;失敗也要可愛。
5. **效能。** 中階手機 60 FPS:粒子用 `CPUParticles2D`、數量節制;同時存在的特效有上限。
6. **全部可調。** 新增的數值(震動強度、連擊時限、星級門檻、粒子數量)放在資料檔。

### A 線(戰鬥手感)

- [ ] AP1 鏡頭:以「震動量」累積的畫面震動(受擊、重劈、必殺技、打倒精英);揮劍時鏡頭輕微推向攻擊方向。數值放資料檔。
- [ ] AP2 命中回饋:傷害數字(像素字,跳起再落下;握手的雙倍傷害用大字和不同顏色,配 `crit` 音效);被擊中的敵人擠壓變形;`hit_burst` 粒子;稻草人倒下噴 `straw_bits`、烏鴉倒下噴 `feathers`。
- [ ] AP3 金毛手感:跑步時 `footstep_dust`、身體微微前傾;揮劍有拖尾、上下交替揮;修正「單獨一隻稻草人兵永遠打不中金毛」(縮小普通攻擊的擊退,或讓稻草人的攻擊距離稍長)。
- [ ] AP4 連擊:2 秒內連續打倒敵人累積連擊,發 `combo_changed`;5、10、20 連擊時加忠誠度並播 `combo`。數值放資料檔。
- [ ] AP5 頭目演出:出場時從橋頭城門走進來(約 1.5 秒,這段時間頭目無敵、不攻擊),出場時發 `boss_hp_changed`;進入第二階段時怒吼(`boss_roar`)、盔甲發紅光、震動、短暫無敵;被打倒時短暫慢動作、白光閃、盔甲散落、頭盔滾動,停約 1 秒才讓 B 線過關。
- [ ] AP6 必殺技演出:畫面短暫變暗、金毛舉劍、光柱、`ultimate_burst`、大震動、`Haptics.play(&"heavy")`;所有敵人短暫停頓。
- [ ] AP7 敵人與預警:預警圈改為脈動的地面圖案,快命中時變亮;敵人出場改為從地面冒出(配 `footstep_dust`);稻草人會分散包圍,不會排成一條線;精英稻草人有光環;烏鴉偶爾兩隻接連俯衝。
- [ ] AP8 鬥牛犬個性:舉盾時頭上冒「汪!」對話泡泡;跟隨時一蹦一跳;過關時跳起歡呼(有 `victory` 動畫就用)。
- [ ] AP9 震動:金毛被擊中 `medium`、必殺技 `heavy`、頭目重劈 `heavy`、打倒頭目 `heavy`。
- [ ] AP10 過關慶祝:收到 `level_completed` 後,金毛停止攻擊並做歡呼動作。
- [ ] AP11 測試:連擊計時與里程碑、`boss_hp_changed` 發出時機、頭目出場與第二階段無敵、震動呼叫、特效數量上限。

### B 線(節奏與成長)

- [ ] BP1 關卡開場:發 `level_started` 後等 `intro_duration`(約 1.6 秒,放 difficulty.tres)才開始第一波,讓 HUD 播標題卡;這段時間金毛可以走動。
- [ ] BP2 轉場:所有畫面切換都經過 `ui/transition/transition.tscn`(檔案不存在就直接切換)。
- [ ] BP3 星級:依 4.10 計算 ★1 至 ★3;結算資料加入 4.10 的新鍵;最佳星數存進存檔並寫回 `GameState.best_stars`;六關都要設定合理的 `par_time` 與 `damage_budget`。
- [ ] BP4 教學提示:1-1 且未看過時加入 `ui/hints/tutorial.tscn`,完成後記錄並存檔。
- [ ] BP5 音樂:依 4.10 在各狀態呼叫 `Music`;暫停時壓低音量。
- [ ] BP6 存檔:加入 `music_on`、`haptics_on`、`tutorial_done`、`best_stars`;舊版存檔可以讀(缺的欄位用預設值)。
- [ ] BP7 波次設計:善用 `SpawnEntry.pattern`,讓每關有自己的特色和起伏(1-1 溫和;1-2 認識烏鴉;1-3 同伴登場;1-4 被包圍、要走位;1-5 精英加烏鴉群;最後一波是高潮);中間安排喘息時間。
- [ ] BP8 難度:用 `tests/integration/playthrough_bot.tscn`(全部正式零件)量度。目標:機器人每關 50 至 75 秒,偶爾受傷但不倒下;頭目約 45 秒。
- [ ] BP9 測試:星級計算、存檔向下相容、教學只出現一次、開場等待、轉場不會卡住流程、音樂呼叫次序。

### C 線(觀賞性:美術、介面、音樂)

- [ ] CP1 角色動畫升級:更多格數(金毛 idle 4 格含眨眼與搖尾巴、run 6、attack 4 有預備與收招、hurt 2、sleep 2 有 Zzz);明暗與高光一致;鬥牛犬、稻草人、烏鴉、黑騎士同樣升級(格子大小不變)。可加 `victory` 動畫。
- [ ] CP2 背景:六個背景(含三個新的),每關有自己的時段與氣氛:1-1 早晨陽光、1-2 金黃麥田、1-3 花草原、1-4 傍晚農場圍欄、1-5 黃昏烏鴉森林、1-6 暴風雨夜的石橋。加入會動的元素(草搖動、水波、旗幟、花瓣、螢火蟲、雨),但不可以干擾戰鬥的可讀性。
- [ ] CP3 特效:原地替換 4.10 的十一個粒子特效與 4.9 的六個特效,質感統一;經驗珠發光帶尾巴。
- [ ] CP4 HUD:血條平滑變化,受擊時有一段白色殘影;低活力時心跳閃爍;升級彈出「等級 N!」;連擊數(`combo_changed`)彈跳放大;頭目血條(`boss_hp_changed`,第二階段變色);關卡標題卡(`level_started`:章節名與關卡名滑入滑出);過關慶祝(`level_completed`:大橫幅與 `confetti`);必殺技切入畫面(`ultimate_used`:金毛半身像劃過畫面約 0.6 秒)。
- [ ] CP5 畫面:標題會動(雲、金毛呼吸、劍閃光、標誌彈跳、花瓣);按鈕按下有擠壓動畫;結算畫面的星星逐顆亮起(`star` 音效)、數字遞增、「新紀錄!」;失敗畫面的睡覺動畫;把戲卡片翻入、發光,顯示已學幾層(由 `GameState.active_tricks` 數);暫停畫面加入音樂與震動開關;製作名單自動捲動。
- [ ] CP6 背景音樂:程式生成的 8-bit 音樂:`title`(輕快的英雄主題)、`field`(冒險進行曲)、`boss`(緊張、小調、較快)、`camp`(溫柔的搖籃曲)、`victory`、`fail`、`chapter_clear`。循環曲目要無縫循環;用 Godot 的 QOA 壓縮匯入控制檔案大小;完成 `ui/audio/music.gd`(交叉淡入淡出、壓低音量、遵守 `music_on`)。
- [ ] CP7 音效:加入 4.10 的新音效,原有音效加厚層次(命中更有力、升級更有成就感)。
- [ ] CP8 轉場與教學:原地替換 `ui/transition/transition.tscn`(例如狗掌印擦拭),製作 `ui/hints/tutorial.tscn`(手指拖曳動畫 → 「放手攻擊」提示 → 完成)。
- [ ] CP9 App 圖示、啟動畫面、商店宣傳圖配合新畫風更新。
- [ ] CP10 測試:新 HUD 元件對訊號的反應、教學流程、轉場方法、每個音樂與音效 id 都有檔案、文字鍵都存在。

### D 線(營地、小遊戲、手機)

- [ ] DP1 營地氣氛:營火有粒子與閃爍的光、星空閃爍與偶爾的流星、螢火蟲;金毛呼吸、搖尾巴;**點金毛可以摸摸頭**(冒 `heart`、`pet` 音效、輕震動、滿意度小幅增加,每次營地有上限);第 3 關以後鬥牛犬坐在營火旁;營地自己播 `camp` 音樂。
- [ ] DP2 小遊戲手感:拉卷軸時紙張有速度線與 `scroll` 音效;剛好在墨水漬停住給「完美!」(`perfect`、加分);倒數有大數字與 `countdown`;結束時金毛被卷軸包成可愛的樣子;評價星星逐顆亮起。重新調整評分門檻。
- [ ] DP3 震動權限:Android 匯出設定加 VIBRATE 權限;更新 `store/` 的權限與隱私說明(震動不涉及任何資料)。
- [ ] DP4 效能:壓力測試加入新的粒子特效(40 隻敵人 + 特效),仍維持 60 FPS(headless 量度),建議各特效的數量上限。
- [ ] DP5 商店截圖:打磨完成後用 `store/screenshots/capture.gd` 重新產生,更新商店說明文字的賣點。
- [ ] DP6 測試:摸頭的上限與滿意度、完美停住的判定、VIBRATE 權限在匯出設定中。

---

## 16. 深化(v2.3)

**目標:** 回答擁有人的三個問題。(1)**故事**:由「幾乎沒有」變成完整、溫暖、好笑、有懸念的第一章。(2)**挑戰**:敵人不再太容易,而且需要不同的打法;通關後有困難模式。(3)**畫面**:由「乾淨可愛」提升到「有氣氛、有層次、有感情」的像素遊戲。第 15 節的品質標準繼續適用。

### A 線(敵人與挑戰)

- [ ] AS1 稻草人弓兵 `scarecrow_archer`(生命 18、箭傷害 7、速度 24、經驗 2):保持 60 至 90 像素距離;瞄準時畫紅線 0.7 秒再射箭(箭速約 120 像素/秒,射程約 160,看得見、躲得開);金毛靠近時後退。**鬥牛犬舉盾時擋得住箭**(同伴的價值)。
- [ ] AS2 空盔甲兵 `armored_husk`(生命 70、傷害 12、速度 22、經驗 4):不會被擊退、吠叫只震懾一半時間;約每 4 秒用盾衝撞一次(紅線預警 0.6 秒,衝約 60 像素);倒下時盔甲散開、一縷藍色火光飛走(呼應黑騎士)。
- [ ] AS3 中頭目稻草人隊長 `scarecrow_captain`(32×32,生命約 320、經驗 12):出場發 `boss_appeared` 與 `boss_hp_changed`;招式:乾草叉橫掃(扇形預警)、號令稻草人(紫圈預警後召喚 3 隻)、擲乾草叉(直線預警,會飛回來);一半生命後加快;倒下時散成稻草,一根紫色羽毛慢慢飄落(故事伏筆)。
- [ ] AS4 黑騎士新招式:出場時發 `boss_appeared`;第二階段重劈後放出劍氣(直線預警的弧形投射物),召喚改為 2 隻空盔甲兵。
- [ ] AS5 投射物系統:箭、劍氣、乾草叉共用;都有預警;鬥牛犬的盾擋得住;數值放資料檔。
- [ ] AS6 難度:`data/enemies/difficulty_scaling.tres`,依 `GameState.difficulty` 在 `spawn_enemy` 套用(生命、傷害、預警時間、速度、攻擊間隔)。困難模式大約:生命 ×1.5、傷害 ×1.4、預警 ×0.8。
- [ ] AS7 一般模式的整體挑戰提高:後段關卡的敵人更會合作(例如同時進攻的數量上限隨關卡增加、弓兵配合近戰)。用 `tests/integration/playthrough_bot.tscn` 調整:一般模式機器人在 1-1 至 1-3 不倒下,1-5、1-6 偶爾倒下(五個種子之中一至兩次);困難模式機器人每輪倒下數次但能過關。
- [ ] AS8 新增 `ENEMY_SCARECROW_ARCHER`、`ENEMY_ARMORED_HUSK`、`ENEMY_SCARECROW_CAPTAIN` 文字;測試(新敵人行為、投射物被盾擋下、難度倍率、`boss_appeared`)。

### B 線(故事流程與關卡)

- [ ] BS1 依 `docs/STORY.md` 建立 `data/story/` 全部段落,設定六關的 `story_before`、`story_after`。
- [ ] BS2 依 `docs/STORY.md` 第 8 節播放:開場繪本、每關前後、重試不重播、結局、第二章預告。對白期間場地停止運作,HUD 的關卡標題卡在對白之後才出現。
- [ ] BS3 結局:1-6 慶祝 → `l6_after` → 結算(第一章完)→ `teaser` → 設定 `chapter_cleared` 並存檔 → 標題。
- [ ] BS4 困難模式:標題畫面設定 `GameState.difficulty`;困難模式的最佳星數分開存;結算資料加 `difficulty`;困難模式可以多加少量敵人(放 difficulty.tres)。
- [ ] BS5 關卡重新設計:1-3 引入弓兵(鬥牛犬同時加入,示範盾擋箭);1-4 最後一波是稻草人隊長(播 `boss` 音樂);1-5 空盔甲兵、精英、烏鴉、弓兵混合;每關仍是 60 至 90 秒。
- [ ] BS6 存檔第 3 版:`difficulty`、`chapter_cleared`、`story_seen`,舊存檔可讀。
- [ ] BS7 測試:對白次序、重試不重播、結局次序、困難模式星數分開、存檔向下相容。

### C 線(畫面與介面)

- [ ] CS1 正式對白框(原地替換,方法不變):羊皮紙與精緻像素框;頭像左右分邊(金毛、貝德維爾在左,其他在右);名牌;逐字顯示並有說話音效(每個角色音高不同);點一下先顯示整句、再點下一句;右上角「略過」;有插畫的句子用繪本頁模式(翻頁效果)。
- [ ] CS2 頭像:`docs/STORY.md` 第 3 節全部角色與表情,48×48,細緻的明暗;原創設計(梅林是西施犬法師;摩根娜只是紫色剪影)。
- [ ] CS3 繪本插畫:第 4 節八張,160×120,統一的繪本像素風格(抖色漸層、有限色板),與頭像一致。
- [ ] CS4 新角色圖與投射物(原地替換佔位圖):弓兵、空盔甲兵(藍色魔法光)、稻草人隊長(32×32,紫色羽毛)、梅林(24×24);箭、劍氣、乾草叉。
- [ ] CS5 高級像素畫面:光影(用加亮混合的光暈圖做火把、閃電、營火、魔法、黑騎士眼睛、必殺技;手機效能允許才用 Light2D);景深(場地以外的前景枝葉、草叢、雨幕);角色投影、邊緣光、次要動作(披風飄動、耳朵晃動)、揮劍殘影、閒置小動作;各關色調與輕微暗角(不可遮住戰鬥)。
- [ ] CS6 標題:加入梅林的主視覺;`chapter_cleared` 時出現難度選擇(設定 `GameState.difficulty` 後才發 `new_game_pressed`)。
- [ ] CS7 失敗畫面放梅林頭像與隨機 `STORY_TIP_*`;結算畫面顯示「困難」標記;頭目血條改用 `boss_appeared` 的名字。
- [ ] CS8 音效與音樂:說話音效、翻頁、射箭、盔甲碰撞、隊長吶喊、魔法;新增 `story` 音樂(溫柔的繪本主題,開場與結局用)。
- [ ] CS9 測試。

### D 線(營地與手機)

- [ ] DS1 營地故事:第一次進營地播 `camp1`,第二次播 `camp2`(用自己的對白框),播完才顯示選單。
- [ ] DS2 營地的梅林:坐在圓桌旁(偶爾施法閃星星);點他說一句 `CAMP_MERLIN_01` 至 `06`(D 線撰寫,語氣同 `docs/STORY.md`)。
- [ ] DS3 小遊戲包裝:卷軸上有《王室守則》的小字條目;結束時梅林問「讀完了嗎?」。
- [ ] DS4 效能:光暈、投射物、對白插畫加入後的壓力測試;重建並驗證 APK。
- [ ] DS5 商店:說明文字加入故事賣點;截圖工具加入對白與繪本畫面。
- [ ] DS6 測試。

---

## 17. 玩法深度(v2.4)

**目標:** 讓「再玩一局」的動力來自自己的選擇與成長。品質標準同第 15 節。各線**不建 APK**,只做必要的截圖。

### A 線(戰鬥)

- [ ] AV1 六個新把戲中的能力類(撲擊、打滾、裝死、暴衝)與四個進化把戲(4.12);數值放資料檔;進化要有明顯不同的畫面效果。
- [ ] AV2 寶箱:精英、中頭目、頭目必掉;一般敵人極少機率掉(`luck` 會提高);寶箱落地有光,金毛碰到就打開(發 `chest_collected`)。
- [ ] AV3 零食:敵人有機率掉零食(挖寶、`luck` 提高),被吸向金毛,拾取發 `snack_collected`。
- [ ] AV4 復活:B 線呼叫 `player.revive()` 時要可愛地醒來(星星、短暫無敵、震開附近敵人)。
- [ ] AV5 測試。

### B 線(流程與成長)

- [ ] BV1 六個新把戲與四個進化的資料檔;進化規則;升級與寶箱的三選一會在條件達成時出現進化選項(標「進化!」)。
- [ ] BV2 寶箱獎勵:普通 = 回復或零食;精英與頭目 = 一次把戲三選一(可能是進化)。
- [ ] BV3 抉擇事件:每關一次,在中段兩波之間發 `event_offered`:「梅林的祝福」(例如回滿活力 / 下一個把戲升兩級)與「摩根娜的誘惑」(例如攻擊 +30% 但活力上限 −20%)。選項表放資料檔,每關不同;遊戲暫停到選完。介面不存在時自動選第一項。
- [ ] BV4 零食經濟:擊倒、寶箱、星級都給零食,發 `snacks_changed`;倒下時可以花零食復活一次(每關一次,價格放資料檔)。結果字典加 `revive_cost`、`can_revive`;失敗畫面的新訊號 `revive_pressed`(見 4.12 介面)→ 扣零食、`player.revive()`、回到戰鬥。
- [ ] BV5 營地訓練資料 `data/progression/meta_upgrades.tres` 與套用:新遊戲 `reset_run()` 之後套用 `GameState.meta_upgrades`;存檔第 4 版(`meta_upgrades`、`endless_best`、零食)。
- [ ] BV6 無盡試煉(`mode = &"endless"`):通關後在標題選擇;隨機背景;一波接一波,越來越強,每 5 波一個中頭目或頭目,每 10 波一個抉擇事件;倒下就結束,紀錄最佳波數與獲得零食。
- [ ] BV7 用機器人調整:一般模式難度維持 v2.3 的目標;進化在第一章大約能完成一至兩次。
- [ ] BV8 測試。

### C 線(介面與美術)

- [ ] CV1 新把戲與進化的圖示(原地替換);把戲卡片的「進化!」樣式。
- [ ] CV2 進化演出(`trick_evolved`):兩個圖示合體的短動畫與音效。
- [ ] CV3 抉擇事件介面 `ui/event_choice/event_choice.tscn`:聽 `event_offered`,兩張卡片(梅林:藍色、溫暖;摩根娜:紫色、神秘),選了發 `event_chosen`;遊戲暫停時可用。
- [ ] CV4 寶箱與零食的美術(原地替換);寶箱打開的光與音效。
- [ ] CV5 HUD:零食數;無盡模式的波數與最佳紀錄。失敗畫面:「用 N 個零食復活」按鈕(發 `revive_pressed`,只在 `can_revive` 時出現)。標題:通關後的「無盡試煉」按鈕(設定 `GameState.mode` 後發新訊號 `endless_pressed`)與「訓練」按鈕(發 `training_pressed`)。
- [ ] CV6 新音效:`chest_open`、`evolve`、`snack`、`revive`、`event`。
- [ ] CV7 測試。

### D 線(營地訓練與手機)

- [ ] DV1 營地訓練介面 `game/camp/training.tscn`:五項升級、等級、價格、零食數;買得起才可以按;買了有升級演出;營地選單加「訓練」入口;標題的 `training_pressed` 也開啟它(由 B 線加到流程)。
- [ ] DV2 小遊戲獎勵加入零食(依評價)。
- [ ] DV3 效能:寶箱、零食、進化特效加入壓力測試。
- [ ] DV4 測試。

---

## 18. 美術全面重畫(v2.5,擁有人選擇「程式重畫、提高解析度」)

**背景:** 擁有人認為畫面不夠好。Claude 不能生成圖片,擁有人選擇由程式重畫並提高解析度;日後換成專業美術時,檔案可以原地替換(規格見 `docs/ART_BRIEF.md`)。只由 C 線執行(節省 Token),整合工作階段處理接縫。

**尺寸(合約測試已放寬)**:金毛、鬥牛犬 32×32;稻草人、弓兵、空盔甲兵、梅林 32×32;烏鴉 24×24 以內;稻草人隊長 48×48;黑騎士 64×64;頭像 48×48、插畫 160×120 不變。動畫名稱不變;格數可以增加。角色在畫面上會比以前大約 25%,這是刻意的(更有存在感)。

### C 線任務

- [ ] CR1 全部角色重畫:更高解析度、更多細節(毛髮質感、盔甲反光、布料皺摺)、一致的光源(左上)、2 至 3 層明暗、彩色描邊(不是全黑)、每格腳底對齊。
- [ ] CR2 全部背景重畫:更多層次(遠景、中景、前景)、材質細節、不同時段的光;戰鬥區保持清楚。
- [ ] CR3 介面重畫:框、按鈕、血條、卡片、圖示,統一而精緻。
- [ ] CR4 標題主視覺與 App 圖示重畫。
- [ ] CR5 特效重畫:配合新尺寸。
- [ ] CR6 截圖比較(重畫前、重畫後),並確認全部合約測試通過。

## 19. 三章與背景、標題再修(v2.6)

**背景:** 擁有人要求「至少 3 章」、「頭目再加強」、「再修一輪背景和標題」,並問玩法是否跟隨同類型的熱門作品。決定:保留「移動閃避、停下自動攻擊」的核心,沿用同類型作品的「章節」結構(每章獨立一輪、逐章解鎖、章節越後越難),但保留我們的特色(近戰、故事、同伴、營地,沒有抽卡)。合約見 4.13;故事見 `docs/STORY.md` 第 9 至 13 節。**不要建置 APK**(擁有人要求到最後才建置)。

C 線這次分成兩個工作階段:**C 世界**(背景、標題、插畫、音樂、失敗提示)與 **C 角色**(角色圖、頭像、投射物特效)。兩者都在 `line-c` 的目錄內工作,但只改各自的檔案;`tools/pixel/build_all.py` 由整合工作階段合併。

### A 線任務

- [ ] AV1 `gargoyle` 石像鬼:飛行、紅線預警後俯衝;每約 4 秒變成石頭 1.5 秒(播 `stone`,打不動、推不動、受擊顯示「鏘」);生命約烏鴉的 2.5 倍。
- [ ] AV2 `spellbook` 魔法書:與金毛保持 70 至 110 像素;預警後射出 3 顆(困難或後段 5 顆)扇形光球(`magic_orb`),光球之間留有可以鑽過的空隙。
- [ ] AV3 `foxfire` 狐火:3 至 5 隻成群生成、追蹤、很脆(一下打倒);接近金毛或追了 4 秒後停下,地上亮預警圈 0.6 秒再爆開(打倒的不會爆)。
- [ ] AV4 `shadow_wolf` 影狼:成群在外圍繞圈,輪流以紅線預警後直線衝鋒;倒下播 `down` 後散成落葉(不是受傷)。
- [ ] AV5 中頭目:`gargoyle_elite`(2-4,石像鬼放大 1.5 倍、生命高、半血時召喚 2 隻石像鬼)與 `phantom_knight`(3-4,沿用黑騎士行為,速度 ×1.3、預警 ×0.8、生命約黑騎士 60%、半透明紫色)。兩者都發出 `boss_appeared`。
- [ ] AV6 `green_knight` 綠騎士(2-6):藤鞭(長紅線預警後橫掃)、荊棘環(8 至 12 根 `thorn` 放射)、召喚 2 隻稻草人;半血時播 `hat_off`(葉子帽掉下,可愛不受傷),之後速度 +25%、藤鞭連續兩次。
- [ ] AV7 `morgana` 摩根娜(3-6,最終頭目,三個階段):瞬間移動(目的地先亮月光圈 0.7 秒)、狐火雨(5 至 8 個預警圈後落下 `fox_flame`)、扇形 `moon_orb`;66% 起召喚 2 個鏡像分身(一下打散,只會射較弱的光球);33% 起加入旋轉的月光束(紅線預警)。倒下播 `down`(坐在地上,不是受傷)。
- [ ] AV8 同伴 `lancelot`:每約 3 秒向最近的敵人突刺(`dash`)再回到金毛身邊;和貝德維爾可以同時在場、互不重疊;不會被打倒(同貝德維爾的規則)。
- [ ] AV9 每章難度:`difficulty_scaling.tres` 加 `chapter_hp_mult`、`chapter_damage_mult`(初始值 1.0、1.3、1.6 與 1.0、1.2、1.4),故事模式依 `GameState.chapter` 套用;測試。
- [ ] AV10 每個新敵人與頭目在測試場地可以被打倒;頭目各有至少一個「看到預警就躲得開」的測試。

### B 線任務

- [ ] BV1 `chapter_2.tres`、`chapter_3.tres` 與 12 關(背景、同伴、波次、`par_time`、`damage_budget`、`music`、對白)。關卡表:

| 關 | 背景 | 同伴 | 主要敵人 |
| --- | --- | --- | --- |
| 2-1 | castle_town | 貝德維爾 | 石像鬼(教學)、稻草人、烏鴉 |
| 2-2 | castle_courtyard | 貝德維爾 | 石像鬼、空盔甲兵、弓兵 |
| 2-3 | royal_library | 貝德維爾、蘭斯洛特 | 魔法書(教學)、石像鬼 |
| 2-4 | castle_wall | 同上 | 中頭目石像鬼統領 + 弓兵 |
| 2-5 | magic_garden | 同上 | 魔法書、石像鬼、精英稻草人 |
| 2-6 | green_chapel | 同上 | 綠騎士 |
| 3-1 | misty_lake | 同上 | 狐火(教學)、烏鴉 |
| 3-2 | fairy_forest | 同上 | 影狼(教學)、狐火 |
| 3-3 | stone_circle | 同上 | 影狼、魔法書、石像鬼 |
| 3-4 | crystal_cave | 同上 | 中頭目幻影黑騎士 + 狐火 |
| 3-5 | morgana_tower | 同上 | 全部混合(最難的一般關) |
| 3-6 | tower_top | 同上 | 摩根娜 |

- [ ] BV2 依 `docs/STORY.md` 第 12 節建立第二、三章的 `data/story/*.tres`(沿用 BS1 的產生器)。
- [ ] BV3 流程:依 `GameState.chapter` 載入章;每章的開場繪本、結局、預告;打完第 N 章更新 `chapters_cleared`;存檔記住章(存檔版本 +1,舊存檔轉換);「繼續冒險」回到正確的章與關。
- [ ] BV4 每關的音樂用 `LevelData.music`(空白時沿用 `field`、`boss`;音樂檔不存在時退回 `field`、`boss`)。
- [ ] BV5 無盡試煉:`chapters_cleared ≥ 2` 時加入第二章的敵人與背景,`≥ 3` 時加入第三章的。
- [ ] BV6 結算與章節進度的文字依章顯示(不要寫死「第一章」);`stub_title` 沙盒加選章。
- [ ] BV7 測試:三章各自可以從第 1 關玩到結局(用測試替身快轉);存檔轉換。

### C 世界任務(背景、標題、插畫、音樂、失敗畫面)

- [ ] CW1 **第一章背景再修**(擁有人要求):6 張背景的遠景、中景、前景重畫,更有層次;石橋鋪面降低亮度與雜訊,不要搶走角色;戰鬥區保持清楚。
- [ ] CW2 12 張新背景(4.13 的清單),每張有不同的色調與時段,並有會動的細節(旗幟飄動、書本浮動、螢火蟲、湖霧、水晶閃光、塔頂閃電)。第二章偏暖色石造城堡,第三章偏冷色月光與迷霧。
- [ ] CW3 **標題再修**(擁有人要求):修正山的條紋明暗;標題主視覺更精緻;選章介面(4.13);標題背景隨最高已解鎖的章改變(第一章山丘、第二章城堡、第三章湖上高塔)。
- [ ] CW4 11 張新插畫(`docs/STORY.md` 第 11 節)。
- [ ] CW5 音樂 `field_2`、`boss_2`、`field_3`、`boss_3`(`tools/pixel/music_gen.py`),風格分別是城堡、綠騎士(輕快)、迷霧湖(神秘)、摩根娜(緊張而有點悲傷)。
- [ ] CW6 失敗畫面的提示依章選(第二章用 1 至 10、13;第三章用全部);結算與 HUD 的章名不要寫死。

### C 角色任務(角色圖、頭像、特效)

- [ ] CC1 8 個新角色圖(4.13 的表),畫風與 v2.5 一致(左上光源、彩色描邊、2 至 3 層明暗、每格腳底對齊)。頭目要一眼認得:綠騎士的圓灌木葉子帽、摩根娜的紫斗篷與新月法杖。
- [ ] CC2 5 位新說話者的頭像(`docs/STORY.md` 第 10 節),`morgana_true` 是第一次露出真面目的摩根娜。
- [ ] CC3 投射物特效 `magic_orb`、`thorn`、`fox_flame`、`moon_orb`;石像鬼變石頭的「石屑」與影狼散成落葉的粒子(`assets/fx/particles/`)。
- [ ] CC4 黑騎士的每格往上移 8 像素(擁有人回報黑騎士太貼近場地下緣),確認動畫腳底仍然對齊。
- [ ] CC5 `docs/ART_BRIEF.md` 由整合工作階段更新;C 角色只需在 status 檔列出新檔案。

### D 線任務

- [ ] DV1 營地依章播放對白(4.13);第三章由湖中仙女代替梅林(圖 `assets/sprites/lady_lake/`),點她說 `CAMP_LADY_01` 至 `CAMP_LADY_04`;第二章起營地多了蘭斯洛特,點他說 `CAMP_LANCELOT_01` 至 `CAMP_LANCELOT_04`(D 線撰寫,語氣見 `docs/STORY.md`)。
- [ ] DV2 營地的場景依章變化(第一章草地夜空、第二章城牆下的營火、第三章湖邊洞口與月光),用程式畫的元素即可。
- [ ] DV3 新小遊戲一個,在第二、三章的營地輪流出現,例如「叫醒騎士」(依節奏點擊打瞌睡的騎士)或「湖面跳石」;結果一樣影響下一關加成。
- [ ] DV4 手機檢查:頭目與分身同時在場時的效能(在 `tests/line_d/` 量測節點數與每幀時間),不需要建置 APK。

### 整合工作階段

- [ ] 合併五個工作階段;試玩機器人擴充為三章各打一次;依數據調整每章倍率;更新 `docs/ART_BRIEF.md`、`docs/integration_report.md`;PR 合併到 `main`。
