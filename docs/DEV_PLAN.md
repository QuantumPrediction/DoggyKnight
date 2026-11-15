# 《金毛騎士》原型開發計劃(給 Claude Code)

版本:v1,2026-11-15。工作名稱《金毛騎士》,repo 建議名稱 `golden-knight`。

這份文件是四個 Claude Code 工作階段(下稱「線」)同時開發的唯一依據。每條線開工前必須讀完第 1 至 5 節,以及自己那一線的章節。

---

## 0. 給專案擁有人的操作步驟

1. 建立一個新的獨立 repo(不要放進三國專案的 repo)。把 `CLAUDE.md`、`docs/DEV_PLAN.md`、`docs/KICKOFF_PROMPTS.md` 放進去並推上 `main`。
2. 開 **一個** Claude Code 工作階段,貼上 `KICKOFF_PROMPTS.md` 的「Phase 0」指示。等它完成並合併到 `main`。**Phase 0 未合併前不要開四條線。**
3. 開四個工作階段,分別貼上 A、B、C、D 線的指示。
4. 每條線每次收工都會更新 `docs/status/LINE_X.md` 並開 PR。合併次序見第 7 節。
5. 四條線都到達里程碑 M1 後,開一個「整合」工作階段(指示在 `KICKOFF_PROMPTS.md`)。
6. 任何一線提出「合約變更申請」(`docs/requests/`)時,由你決定是否接受,再交給整合工作階段修改 `core/`。

---

## 1. 原型的目標與範圍

**要回答的問題只有一個:「金毛帶著同伴打小怪、升級選把戲、打頭目」這個核心循環好不好玩。**

### 包含

- 第一章「石中劍」的第 1 至 5 關,加第 6 關頭目戰:守橋的黑騎士(被魔法驅動的空盔甲)。
- 主角金毛騎士:拖曳移動、停下自動揮劍、必殺技。
- 一位同伴:貝德維爾的英國鬥牛犬(自動跟隨、舉盾格擋)。
- 兩種小怪:稻草人兵(近戰)、烏鴉斥候(快速、俯衝)。
- 升級三選一,共 6 個「把戲」。
- 一個營地小遊戲:拉扯王室卷軸。
- 流程:標題 → 關卡 → 升級選擇 → 過關結算 → 營地 → 下一關;失敗 → 結算 → 重試。
- Android 可安裝的測試版(APK)。

### 不包含(任何一線都不要做)

商店、抽卡、內購、廣告、帳號、雲端存檔、劇情動畫、第二章以後的內容、其他同伴、多語言切換、iOS 建置。只預留介面,不寫實作。

### 完成定義(整個原型)

- [ ] 在 Android 實機上從標題畫面玩到打敗黑騎士,全程不當機。
- [ ] 一關 60 至 90 秒;失敗後 2 秒內可以重試。
- [ ] 沒看過遊戲的人不需任何文字教學,10 秒內懂得移動與攻擊。
- [ ] 所有測試腳本通過(`tools/run_tests.sh`)。

---

## 2. 技術基礎

| 項目 | 決定 |
| --- | --- |
| 引擎 | Godot 4 穩定版。Phase 0 以實際安裝的版本為準(建議與三國專案相同),把確切版本號寫進 `CLAUDE.md`,之後所有線不得升級 |
| 語言 | GDScript,全部加型別標註 |
| 畫面 | 直向;邏輯解析度 180×320;整數倍放大;像素不做平滑(nearest) |
| 格子 | 地圖格 16×16;金毛與同伴 24×24;小怪 16 至 24;頭目 48 至 64 |
| 場地 | 每關一個單畫面場地,不捲動。可戰鬥區域約 11×14 格,上方留給 HUD |
| 輸入 | 只有觸控:按住任意位置出現虛擬搖桿,拖曳移動;放手即停下並自動攻擊。桌面測試時滑鼠等同觸控 |
| 資料 | 敵人、關卡、把戲、同伴全部用 `Resource`(`.tres`)描述,數值不寫死在程式裡 |
| 外掛 | 原型階段不裝任何第三方外掛 |

---

## 3. 目錄與擁有權

**每條線只能修改自己擁有的目錄。** 別線的目錄只能讀,不能改。

| 路徑 | 擁有者 | 內容 |
| --- | --- | --- |
| `project.godot`、`core/`、`CLAUDE.md`、`docs/DEV_PLAN.md`、`tools/run_tests.sh` | Phase 0 / 整合 | 專案設定、事件匯流排、全域狀態、資料類別。**四條線一律不得修改** |
| `game/actors/`、`game/combat/`、`data/enemies/`、`data/companions/`、`tests/line_a/` | A 線 | 角色、敵人、同伴、戰鬥 |
| `game/flow/`、`game/progression/`、`data/levels/`、`data/tricks/`、`tests/line_b/` | B 線 | 關卡流程、波次、經驗、把戲、存檔 |
| `assets/`、`ui/`、`tools/pixel/`、`tests/line_c/` | C 線 | 像素圖、動畫、介面、字型、音效 |
| `game/camp/`、`game/minigames/`、`platform/`、`export/`、`tests/line_d/` | D 線 | 營地、小遊戲、手機建置 |
| `docs/status/LINE_X.md` | 各線自己 | 進度報告 |
| `docs/requests/` | 任何線可新增檔案 | 合約變更申請 |

Godot 特有的衝突點:`project.godot`(Autoload、輸入對應、圖層名稱)只由 Phase 0 與整合工作階段修改。需要新增設定時提出申請,不要自己改。

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

# 營地與小遊戲(D 線發出)
signal camp_entered()
signal minigame_finished(minigame_id: StringName, score: int, grade: int)  # grade 0 至 3
signal camp_left()
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
func reset_run() -> void
```

### 4.3 資料類別(`core/data/`)

- `StatBlock`:`max_vigor`、`move_speed`、`attack_damage`、`attack_interval`、`attack_range`、`damage_taken_mult`、`pickup_radius`、`exp_mult`。
- `EnemyData`:`id`、`display_name`、`scene: PackedScene`、`max_hp`、`contact_damage`、`move_speed`、`exp_value`。
- `CompanionData`:`id`、`display_name`、`scene`、`role`。
- `TrickData`:`id`、`display_name`、`description`、`icon`、`stat_modifiers: Dictionary`、`is_ability: bool`。
- `LevelData`:`id`、`display_name`、`waves: Array[WaveData]`、`is_boss: bool`、`arena_scene`。
- `WaveData`:`spawns: Array[SpawnEntry]`(`enemy_id`、`count`、`delay`)。

### 4.4 場景與介面合約

| 項目 | 路徑 | 合約 |
| --- | --- | --- |
| 主角 | `game/actors/player/player.tscn` | 根節點 `CharacterBody2D`,在群組 `player`;提供 `take_damage(amount: int)`、`heal(amount: int)` |
| 同伴 | `game/actors/companions/bulldog.tscn` | 群組 `companion` |
| 敵人 | 由 `EnemyData.scene` 指定 | 群組 `enemy`;提供 `setup(data: EnemyData)`、`take_damage(amount: int)` |
| 戰鬥場地 | `game/combat/arena.tscn` | 提供 `spawn_enemy(enemy_id: StringName, at: Vector2) -> Node`、`get_spawn_points() -> Array[Vector2]`、`clear() -> void` |
| HUD | `ui/hud/hud.tscn` | 只聽 EventBus,不讀取任何戰鬥節點 |
| 把戲選擇 | `ui/trick_choice/trick_choice.tscn` | 聽 `trick_offered`,玩家選擇後發出 `trick_chosen` |
| 營地 | `game/camp/camp.tscn` | 進入時發 `camp_entered`,離開時發 `camp_left` |

### 4.5 碰撞圖層與角色代號

圖層:1 場地、2 主角、3 同伴、4 敵人、5 我方攻擊判定、6 敵方攻擊判定、7 掉落物。

角色代號(檔名、資料 id、動畫資源都用同一個):`goldie`、`bulldog`、`scarecrow`、`crow`、`black_knight`。

### 4.6 美術合約

- 圖檔:`assets/sprites/<代號>/<代號>.png`;動畫資源:`assets/sprites/<代號>/<代號>_frames.tres`(`SpriteFrames`)。
- 動畫名稱固定:`idle`、`run`、`attack`、`hurt`;頭目另加 `charge`、`slam`、`down`。
- 只畫朝右,朝左用鏡像。
- Phase 0 會先放純色方塊的佔位動畫資源,路徑與名稱完全相同。C 線日後**原地替換檔案**,不改路徑、不改名稱,A 線因此不需要改任何程式。

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
11. **狗不會受傷。** 任何失敗或受擊表現都要可愛:冒星星、趴下睡著、被毛線纏住。不得出現血或受傷的畫面。

---

## 6. 里程碑

| 里程碑 | 內容 | 完成條件 |
| --- | --- | --- |
| M0 地基 | Phase 0:單一工作階段建立骨架與合約 | `main` 上可開啟專案;佔位主角可在空場地移動;`run_tests.sh` 可執行 |
| M1 各線灰盒 | 四條線各自在測試場景中完成功能,用佔位圖 | 每條線的「M1 驗收」全部打勾 |
| M2 整合 | 整合工作階段依序合併四條線,接成完整流程 | 桌面上可從標題玩到打敗黑騎士 |
| M3 實機打磨 | Android 實機測試、手感調整、修錯 | 第 1 節的「完成定義」全部打勾 |

時間無法準確預估。請以里程碑為準,不要以日期為準;每個里程碑完成後由擁有人試玩再決定是否繼續。

---

## 7. 合併次序

1. Phase 0 → `main`。
2. M1 期間各線隨時可開 PR,**只要沒有動到別線的目錄就可以合併**,次序不拘。C 線的美術替換可以最常合併。
3. M2 整合時,整合工作階段依 A → B → C → D 的次序檢查並接線:
   - A + B:波次生成器呼叫場地的 `spawn_enemy`;把戲生效。
   - + C:HUD、把戲選擇介面、正式像素圖。
   - + D:過關後進營地、小遊戲結果影響下一關。
4. 整合期間四條線暫停新功能,只修整合工作階段回報的錯誤。

---

## 8. A 線:戰鬥核心

**目標:** 在測試場地裡,金毛帶著鬥牛犬打稻草人兵與烏鴉斥候,並能打一場黑騎士頭目戰。全部使用佔位圖也要好玩。

**擁有:** `game/actors/`、`game/combat/`、`data/enemies/`、`data/companions/`、`tests/line_a/`。

### 任務

- [ ] A1 虛擬搖桿與移動:按住任意位置出現搖桿,拖曳移動;放手立刻停下。移動要有極短的加減速,不能滑。
- [ ] A2 自動攻擊:停下時自動朝最近的敵人揮劍;移動中不攻擊。揮劍有明確的前搖與打擊停頓(hit stop)。
- [ ] A3 活力與受擊:受擊後短暫無敵與閃爍;活力歸零發出 `player_downed`。
- [ ] A4 敵人基礎類別:由 `EnemyData` 設定數值;被擊中有擊退與閃白;死亡發出 `enemy_died` 並掉落經驗珠。
- [ ] A5 稻草人兵:慢速接近,近身揮擊,攻擊前有 0.4 秒預警。
- [ ] A6 烏鴉斥候:在場邊盤旋,鎖定後直線俯衝,俯衝前有預警線。
- [ ] A7 經驗珠:靠近主角(`pickup_radius`)時被吸過去,拾取時通知 B 線(經 EventBus)。
- [ ] A8 同伴鬥牛犬:跟隨主角,自動走向最近的敵人並舉盾;格擋時吸引附近敵人改為攻擊牠;牠不會倒下,只會暈眩 3 秒。
- [ ] A9 忠誠度與必殺技:命中敵人累積忠誠度;滿了之後在畫面上出現按鈕(按鈕外觀由 C 線提供,A 線先做佔位),按下放出王者之劍的大範圍斬擊。
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

**目標:** 把戰鬥組織成「六關加營地」的完整流程,並完成經驗、升級、把戲三選一與存檔。

**擁有:** `game/flow/`、`game/progression/`、`data/levels/`、`data/tricks/`、`tests/line_b/`。

### 任務

- [ ] B1 遊戲狀態機:標題 → 關卡 → (升級選擇) → 過關結算 → 營地 → 下一關;失敗 → 結算 → 重試或回標題。場景切換集中在 `game/flow/`。
- [ ] B2 波次生成器:讀 `LevelData`,依序生成每一波;場上敵人清空才進下一波;最後一波清空發出 `level_completed`。開發時用假場地(實作同一組方法)測試。
- [ ] B3 六個關卡資料檔(見下表)。
- [ ] B4 經驗與升級:收到經驗後累計,達標發出 `leveled_up` 並暫停戰鬥。
- [ ] B5 把戲系統:升級時隨機抽 3 個不同把戲,發出 `trick_offered`;收到 `trick_chosen` 後套用。數值類把戲修改 `GameState.player_stats`。
- [ ] B6 六個把戲資料檔(見 4.7)。
- [ ] B7 過關與失敗結算的資料:用時、擊倒數、取得的把戲。畫面由 C 線做,B 線提供資料。
- [ ] B8 營地銜接:第 2、4 關過關後進營地;離開營地時把 `next_level_bonus` 套用到下一關。營地還沒完成時,用假營地(一個「繼續」按鈕)代替。
- [ ] B9 存檔:只存到達的關卡與零食數量,存在 `user://`。關掉遊戲再開可以從該關繼續。
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
- [ ] 自動化測試:波次順序、升級門檻、把戲抽選不重複、把戲套用後數值正確、存檔讀檔。

---

## 10. C 線:像素美術、介面與音效

**目標:** 提供全部像素圖與動畫、HUD 與各個畫面、字型與音效,並且原地替換佔位資源。

**擁有:** `assets/`、`ui/`、`tools/pixel/`、`tests/line_c/`。

### 美術方向

可愛、明亮、輪廓清楚。參考設計畫布上的「像素角色設定」與 App 圖示:金毛是奶油金色、垂耳、大眼睛,拿英式長劍,紅披風。中世紀童話風,不要黑暗寫實。全遊戲共用一個約 32 色的調色盤,放在 `assets/palette.png`。

### 任務

- [ ] C1 調色盤與像素生成工具:用程式把字元網格或資料轉成 PNG 與 `SpriteFrames`,放在 `tools/pixel/`,讓每張圖都可以重新生成。
- [ ] C2 金毛 `goldie`(24×24):`idle` 2 格、`run` 4 格、`attack` 3 格、`hurt` 1 格,另加 `sleep` 2 格(失敗時)。
- [ ] C3 鬥牛犬 `bulldog`(24×24):`idle`、`run`、`attack`、`hurt`,另加 `guard`(舉盾)。
- [ ] C4 稻草人兵 `scarecrow`(24×24)、烏鴉斥候 `crow`(16×16):四個基本動畫。
- [ ] C5 黑騎士 `black_knight`(48×48):`idle`、`run`、`attack`、`hurt`、`charge`、`slam`、`down`。
- [ ] C6 第一章場地圖塊(16×16):草地、石橋、城牆、裝飾;石中劍的石頭作為第一關背景物。
- [ ] C7 特效:揮劍弧光、命中火花、經驗珠、預警圈與預警線、必殺技斬擊。
- [ ] C8 HUD:活力條、經驗條、等級、忠誠度條與必殺技按鈕、波次提示。只聽 EventBus。
- [ ] C9 把戲選擇介面:三張卡片,顯示圖示、名稱、一行說明;點選後發出 `trick_chosen`。六個把戲圖示(16×16)。
- [ ] C10 畫面:標題、過關結算、失敗結算(金毛睡著)、暫停。
- [ ] C11 介面主題與字型:選一款支援繁體中文、授權允許商用的像素字型(候選:俐方體 11 號 Cubic 11;**使用前必須核對授權條款**並記錄在 `docs/licenses.md`)。
- [ ] C12 音效:揮劍、命中、受擊、拾取、升級、吠叫、頭目預警、過關。可用程式生成的 8-bit 音效;任何外部素材都要記錄授權。背景音樂暫不做。

### 規則

- 按 4.6 的路徑與動畫名稱原地替換佔位資源,不得改路徑或名稱。
- 觸控目標至少 44 像素(以實際螢幕計);文字與背景對比要足夠。
- 介面文字先只做繁體中文,所有字串集中在一個檔案,方便日後翻譯。

### M1 驗收

- [ ] `tests/line_c/gallery.tscn` 可獨立執行:列出所有角色的所有動畫循環播放。
- [ ] `tests/line_c/ui_sandbox.tscn`:用按鈕模擬 EventBus 訊號,HUD 與把戲選擇介面有正確反應。
- [ ] 所有佔位圖都已被正式圖取代,A 線場景不需修改即可顯示新圖。
- [ ] `docs/licenses.md` 列出每個外部素材的來源與授權。

---

## 11. D 線:營地、小遊戲與手機建置

**目標:** 完成營地與「拉扯王室卷軸」小遊戲,並讓整個專案能在 Android 實機上執行。

**擁有:** `game/camp/`、`game/minigames/`、`platform/`、`export/`、`tests/line_d/`。

### 任務

- [ ] D1 營地場景:圓桌旁的營火,金毛卸下盔甲做回普通的狗(趴著、搖尾巴)。有三個入口:小遊戲、(預留)同伴、繼續冒險。預留入口顯示為「即將開放」。
- [ ] D2 小遊戲「拉扯王室卷軸」:金毛咬住卷軸一端,玩家快速向下滑動把卷軸拉出來,15 秒內拉得越長分數越高;卷軸上會經過墨水漬,滑到要停一下否則扣時間。結束時金毛被卷軸纏住。
- [ ] D3 評分與獎勵:依長度給 0 至 3 級評價;回復活力(25% / 50% / 75% / 100%),提高滿意度,並設定 `next_level_bonus`(0 / 5% / 10% / 15% 攻擊加成)。發出 `minigame_finished`。
- [ ] D4 小遊戲框架:`game/minigames/` 內做一個共同基底(開始、計時、結束、回報),讓第二個小遊戲(圓桌盛宴大胃王)日後可以直接加入。**原型不做大胃王。**
- [ ] D5 觸控與螢幕適配:不同長寬比的手機(由 16:9 到 20:9)都保持整數倍放大並置中;處理瀏海與安全區。把需要的專案設定寫成申請,交整合工作階段套用。
- [ ] D6 Android 匯出:建立匯出設定與建置說明(`export/README.md`),產出除錯版 APK。需要擁有人在本機安裝的東西(Android SDK、金鑰)逐項列清楚。
- [ ] D7 平台介面預留:`platform/` 內定義廣告、內購、分析三個介面的空實作(只印出記錄)。之後接真實外掛時不需改動遊戲程式。
- [ ] D8 最基本的遊玩記錄:每關的用時、勝負、所選把戲,寫到本機記錄檔,供 M3 調整難度。
- [ ] D9 效能檢查:場上 40 個敵人時在中階 Android 手機維持 60 FPS;提供一個壓力測試場景。

### M1 驗收

- [ ] `tests/line_d/camp_sandbox.tscn` 可獨立執行:進營地、玩小遊戲、拿到評價、離開。
- [ ] 小遊戲不需文字說明,5 秒內看得懂要做甚麼。
- [ ] 桌面上以多種視窗比例測試,畫面不變形、不裁切。
- [ ] `export/README.md` 的步驟可以照著做出 APK(若工作環境沒有 Android SDK,列明已驗證與未驗證的步驟)。

---

## 12. 整合工作階段(M2、M3)

- 依第 7 節的次序把四條線接起來,修正接縫問題。
- 唯一可以修改 `core/` 與 `project.godot` 的工作階段;處理 `docs/requests/` 內已獲擁有人同意的申請。
- M2 交付:桌面可完整遊玩的版本,加一份 `docs/integration_report.md`(已知問題、各線需要修的項目)。
- M3 交付:Android APK、手感與難度調整建議、下一階段(第二章、第二位同伴、大胃王小遊戲)的工作量估計。

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
