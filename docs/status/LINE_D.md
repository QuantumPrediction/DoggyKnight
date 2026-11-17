# D 線(營地、小遊戲與手機建置)狀態報告

最後更新:2026-11-17(v2.6 三章:DV1 至 DV4 全部完成;沒有建置 APK)

## 怎樣試玩(不用寫程式)

1. 用 Godot 4.7.2 開啟專案,打開 `tests/line_d/camp_sandbox.tscn`,按「執行目前場景」(F6)。
2. **第二章營地(新)**:按「第二章營地(蘭斯洛特)」。
   - 先播第二章第一次營地的對白 `c2_camp1`(蘭斯洛特、貝德維爾、金毛、梅林)。
   - 場景是**城牆下的營火**:石砌城牆與雉堞、右邊的塔樓(窗裡有燈、塔頂的圓桌旗在飄)、牆上兩支火把、兩面長旗、左下角殘留的紫色荊棘(午睡咒),地上是石板。
   - 圓桌後面:左邊梅林、**右邊蘭斯洛特**。**點蘭斯洛特**:他轉一下長槍、槍尖閃光、對話泡泡說一句(四句輪流,不會連續重複)。鬥牛犬一開始就在火旁。
   - 小遊戲按鈕變成「**叫醒打瞌睡的騎士**」(見第 4 點)。
3. **第三章營地(新)**:按「第三章營地(湖中仙女)」。
   - 播 `c3_camp1`。場景是**湖邊洞口與月光**:又大又圓的滿月、湖面上一閃一閃的月光倒影與水波、飄過湖面的霧、遠方小島上的摩根娜之塔(窗口有紫光)、左邊的岩石洞口(水晶會閃)、湖邊的蘆葦與鵝卵石;螢火蟲變成藍色的小水光。
   - **梅林被抓走了,湖中仙女坐在他的位置**。點她:水光閃一下,說一句(四句輪流)。蘭斯洛特也在。
   - 這次的小遊戲輪到「拉扯王室卷軸」。
4. **新小遊戲「叫醒打瞌睡的騎士」**:三位中了午睡咒的騎士趴在圓桌上打瞌睡(頭上冒 z、鼻子吹泡泡)。
   - 有彩色圈圈從大縮小,**縮到某位騎士頭上的那一刻,點他那一欄**(點騎士或下面同色的大按鈕墊都可以)。
   - 點得準:「完美!」,騎士跳起來、眼睛圓圓、耳朵豎起;差一點:「好!」;太早點或沒點:「呼嚕……」。連續叫醒有「連擊」,每 5 下多加分。
   - 騎士之間的蠟燭每一拍跳一下、有很小聲的「嗒」,速度越來越快,後半段偶爾有半拍。15 秒。
   - 分數是 0 至 100 分;35 / 60 / 85 分是一、二、三顆星。三顆星時大家醒來一起「汪!」。獎勵和卷軸一樣(活力、滿意度、下一關攻擊加成、零食)。
5. **頭目壓力測試(新)**:按「頭目壓力測試」。左上角顯示 FPS、節點數、投射物數與每格 CPU 時間。
6. 第一章的營地(「進入營地」「第二次營地」)和以前一樣。

截圖(雲端,180×320):`/tmp/claude-0/-home-user-DoggyKnight/57ffada0-312e-56a3-b741-46cd2a8c3697/scratchpad/shots/`(`c2.png` 第二章、`c3.png` 第三章、`talk_pair.png` 蘭斯洛特與湖中仙女說話、`wake_pair.png`、`wake_pair2.png` 叫醒騎士與評價)。雲端資料夾會被清掉,需要時重新截。

## 已完成(v2.6 三章,DEV_PLAN 4.13、第 19 節)

- **DV1 營地依章**(`game/camp/camp.gd`、`camp_config.gd/.tres`)
  - 對白:第一章仍是 `camp1`、`camp2`;第 N 章(N ≥ 2)第一次營地 `cN_camp1`、第二次 `cN_camp2`(依 `GameState.chapter` 與 `level_index` 1、3)。路徑格式與「第幾次營地」都在 `camp_config.tres`(`chapter_story_path_format`、`camp_numbers`)。
  - 第二章起:蘭斯洛特(新類別 `CampLancelot`,`game/camp/camp_lancelot.gd`)站在圓桌右後方,點他說 `CAMP_LANCELOT_01` 至 `04`;鬥牛犬從第一次營地就在(`bulldog_from_chapter = 2`)。
  - 第三章:湖中仙女(`assets/sprites/lady_lake/`)坐在梅林的位置,點她說 `CAMP_LADY_01` 至 `04`(`lady_from_chapter = 3`)。
  - 梅林、仙女、蘭斯洛特共用一個對話泡泡;各自有自己的「抽籤袋」(一輪說完才重複,不連續重複)。兩人的點擊範圍從中間切開,不重疊,也不碰到金毛、鬥牛犬和選單(四種手機尺寸都測過)。
  - 營地新訊號 `lancelot_spoke(key)`;新方法 `tap_lancelot()`、`is_lancelot_visible()`、`is_lady_present()`、`camp_number()`、`story_path()`、`current_minigame_scene()`。
  - 新文字(只加不改,`i18n/strings.csv`):
    - 蘭斯洛特:「我從不睡午覺，所以今晚的守夜交給我。」「貝德維爾的香腸？我只是幫他試吃而已。」「尾巴捲起來是因為驕傲，才不是開心！」「別碰我的羽飾！……好吧，只能摸一下。」
    - 湖中仙女:「湖水記得很多往事，也會記得你的笑聲。」「小水珠喜歡你呢，牠們在你頭上跳舞。」「梅林小時候在這裡玩水，還跌進湖裡呢。」「薩摩耶的毛不怕水……只是很難吹乾。」
- **DV2 場景依章**(`game/camp/camp_scenery.gd`,全部程式畫):第一章草地夜空(不變)、第二章城牆下的營火、第三章湖邊洞口與月光(內容見上面「怎樣試玩」)。顏色在 `camp_config.tres` 的 `chapter_palettes`(章 → 顏色),可以不改程式調色。
- **DV3 新小遊戲「叫醒騎士」**(`game/minigames/wake/`,類別 `WakeMinigame`,繼承 `MinigameBase`)
  - 數值全在 `wake_config.tres`(速度 88 → 116 拍、休息與半拍機率、判定窗口 ±0.07 / ±0.15 秒、點數、連擊加分)與 `wake_grading.tres`(門檻 35 / 60 / 85 分,獎勵同卷軸)。
  - 營地輪流:`camp_config.tres` 的 `minigame_rotation = [卷軸, 叫醒騎士]`,第 N 章第 K 次營地用第 (N + K) % 2 個 → **2 章第 1 次叫醒騎士、第 2 次卷軸;3 章第 1 次卷軸、第 2 次叫醒騎士**。第一章不變。按鈕文字跟著換。
  - 只用觸控(點一下)、直向;按鈕墊離底邊 28 像素(避開手勢區),每個至少 54×30;切到背景就暫停(計時與節拍一起停)。
  - 防亂點:太早點(提早 0.15 至 0.3 秒)算沒叫醒;附近沒有圈圈時亂點會打斷連擊。
  - 結果發 `EventBus.minigame_finished(&"wake", 分數, 評價)`,獎勵經 `MinigameGrading` 套用到 `GameState`(和卷軸完全一樣)。
- **DV4 頭目戰效能量測**(`tests/line_d/boss_stress_test.tscn`,數字見下表)。
- **測試**:新增 32 個(`test_camp_chapters.gd` 14 個、`test_wake_minigame.gd` 14 個、`test_boss_stress.gd` 4 個)。D 線共 140 個,全部通過。全部 608 個測試中只有 B 線的 `test_story_data.gd::test_story_md_has_the_expected_scripts` 失敗(整合工作階段在 `docs/STORY.md` 加了第二、三章的段落,B 線的測試還在更新中;與 D 線無關)。

### v2.6 頭目戰效能(DV4,雲端無畫面模式,4 核 CPU,每種跑 20 秒)

場景模擬最重的情況:摩根娜第三階段(瞬間移動 + 2 個鏡像分身 + 旋轉月光束)、狐火雨 8 個、扇形月光球(頭目 5 顆、每個分身 3 顆,都帶加亮光暈)、荊棘環 10 根、小怪 12 隻(狐火 6、影狼 4、石像鬼 2)、金毛與兩位同伴、命中與閃光特效。A 線的新頭目還沒合併,全部用替身(圖用 C 線的佔位圖),場地、主角與貝德維爾用 A 線正式的。

| 情況 | 最多節點 | 最多投射物 | 每格 CPU 平均 | 最慢 1% |
| --- | --- | --- | --- | --- |
| 1 倍(預設,3 次) | 312 | 44 | 1.4 至 1.5 毫秒 | 2.4 至 2.6 毫秒 |
| 1 倍,沒有分身與月光束 | 258 | 32 | 1.9 毫秒 | 5.4 毫秒 |
| 1 倍,沒有光暈 | 285 | 44 | 1.9 毫秒 | 5.7 毫秒 |
| 2 倍 | 520 | 88 | 1.8 毫秒 | 3.4 毫秒 |
| 4 倍 | 936 | 176 | 3.5 毫秒 | 7.7 毫秒 |
| 8 倍 | 1768 | 352 | 7.1 毫秒 | 10.8 毫秒 |
| 1 倍,不鎖 60 FPS | 327 | 48 | 1.9 毫秒 | 6.0 毫秒(平均 143 FPS) |

一格的上限是 16.7 毫秒(60 FPS)。**結論**:頭目與分身同時在場的負擔很輕,1 倍時 CPU 只用了一格的 1/10;到 8 倍(1700 多個節點、350 支投射物)最慢的一格仍在 11 毫秒以內。各情況之間 1 至 3 毫秒的差別是雲端機器的誤差(「沒有分身」反而比較慢就是誤差)。v2.4 的 40 隻敵人壓力測試是 4.8 毫秒,所以**一般關的大群敵人比頭目戰重**。
**注意**:雲端沒有 GPU,量不到畫圖(加亮光暈、半透明分身疊在一起)的負擔;手機上要在實機看(擁有人說最後才建置,所以這次沒有建 APK)。
**建議上限**(給 A、C 線):同時的敵方投射物 ≤ 60 支、加亮光暈 ≤ 20 個、分身 ≤ 4 個;頭目戰時小怪 ≤ 15 隻。目前的設計(摩根娜 + 2 分身 + 召喚)遠低於這些數字。

用法:`godot --headless --path . res://tests/line_d/boss_stress_test.tscn -- --bench-seconds=20 --quit-when-done`;`--load=N` 全部數量乘 N,`--no-clones`、`--no-beam`、`--no-glow`、`--no-minions`、`--uncapped-fps`。

## 以前完成:v2.4 玩法深度(DEV_PLAN 第 17 節)

- **DV1 營地訓練介面** `game/camp/training.tscn`(`game/camp/training.gd`,類別 `CampTraining`)
  - 根節點是全螢幕的 `Control`(PROCESS_MODE_ALWAYS),自己畫半透明夜色底,營地裡和標題上都能用;訊號 `closed()`、`upgraded(id, new_level)`。
  - 買得起才可以按 → `GameState.snacks -= 價格`、`GameState.meta_upgrades[id] += 1`、`EventBus.snacks_changed.emit(總數)`、升級演出(`star_burst`、`sparkle`、`Sfx level_up`、`Haptics light`)。
  - 收到別處發的 `snacks_changed` 會自動更新;收到 `back_requested` 自己關閉(`close_on_back`);`free_on_close` 可讓它關閉時自己刪除(預設由打開的一方移除)。
  - 規則與讀資料在 `game/camp/training_shop.gd`(`TrainingShop`,和畫面分開);外觀與演出數值在 `game/camp/training_config.tres`。
  - 營地選單:中間一列「訓練 | 同伴」各佔一半(選單高度不變,不擠到營火);營地右上角顯示零食數;訓練開著時不能開小遊戲、離開、摸頭、點梅林。營地新訊號 `training_opened`、`training_closed`、`training_upgraded(id, level)`。
- **DV2 小遊戲的零食獎勵**:`MinigameGrading.snack_reward`(`scroll_grading.tres`:`[0, 3, 6, 10]`)。獎勵直接加到 `GameState.snacks`,有零食時發 `snacks_changed`;評價畫面顯示「零食 +N」。
- **DV3 效能**:壓力測試加入寶箱(C 線的 `chest_frames`,輪流打開、底下有光暈)、零食(`snack_frames`,從敵人身上掉、被吸向金毛)、進化(6 道繞身劍氣 + 每 5 秒一次光柱與星星);`--no-loot` 可關掉對照。
- **DV4 測試**:新增 23 個(`test_training.gd` 21 個、`test_grading.gd` 1 個、`test_stress_scene.gd` 1 個),`test_camp.gd` 的版面測試加上「訓練」按鈕。D 線共 109 個;全部 482 個測試通過。

### 升級表的形狀(和 B 線約定)

B 線的 `data/progression/meta_upgrades.tres`:一個 Resource(B 線的 `MetaUpgradeTable`),欄位 `entries: Array`,每項(B 線的 `MetaUpgrade`)有
`id: StringName`、`name_key: String`(`TRAINING_<ID>_NAME`)、`desc_key: String`(`TRAINING_<ID>_DESC`)、`max_level: int`(5)、`costs: Array[int]`(每級一個價格,`costs[0]` = 買第 1 級)、`per_level: float`。
訓練介面**依欄位名稱讀**(不檢查類別,每項也可以是 Dictionary),所以兩邊不用共用類別。B 線的檔案不存在時用 D 線的替身 `game/camp/training_upgrades.tres`(類別 `TrainingUpgradeTable` / `TrainingUpgrade`,形狀相同、名字不同,合併時不會撞名)。
效果文字:`desc_key` 的文字裡的 `%s` 換成「+20%→+30%」;`per_level` 小於 1 當作百分比(0.1 = 每級 +10%),1 以上當作點數(10 = 每級 +10)。

D 線替身的數值(B 線可以照抄或改):

| id | 名稱 | 效果 | per_level | 價格(第 1 至 5 級) |
| --- | --- | --- | --- | --- |
| vitality | 活力 | 活力上限 | 0.10 | 10、20、35、55、80 |
| strength | 力量 | 攻擊力 | 0.08 | 10、20、35、55、80 |
| agility | 敏捷 | 移動速度 | 0.05 | 8、16、28、45、65 |
| loyalty | 忠誠 | 忠誠累積 | 0.10 | 8、16、28、45、65 |
| luck | 幸運 | 寶箱與零食機率 | 0.15 | 12、24、40、60、90 |

全部升滿共 950 個零食。

### v2.4 效能數字(DV3,雲端無畫面模式,40 隻敵人,每種跑 3 次取中間值)

| 情況 | 每格 CPU(腳本 + 物理) | 最慢 1% CPU |
| --- | --- | --- |
| 不加寶箱、零食、進化(`--no-loot`) | 1.4 + 3.4 = 4.7 毫秒 | 9.2 毫秒 |
| 加上 3 個寶箱、12 個零食、6 道劍氣、進化演出(新的預設) | 1.5 + 3.3 = 4.8 毫秒 | 10.6 毫秒 |

一格的上限是 16.7 毫秒(60 FPS),平均都在 58 FPS 以上;差別在誤差之內。**建議上限**(給 A、C 線):場上同時的零食不超過約 12 至 15 個(多的可以合併成一個「大零食」);寶箱光暈同時不超過 3 個;進化的繞身特效用 6 個左右的精靈圖就夠,不要用粒子一直噴。

## 以前完成:v2.3 深化(DEV_PLAN 第 16 節)

- **DS1 營地故事**(`game/camp/camp.gd`)
  - 第一次營地(`GameState.level_index` = 1)播 `data/story/camp1.tres`,第二次(= 3)播 `camp2.tres`。對應表在 `game/camp/camp_config.tres` 的 `story_paths`。
  - 用營地自己的對白框:C 線 `ui/dialogue/dialogue_box.tscn` 的實例(第 40 層、群組 `dialogue_box`,所以自動試玩機器人和整合測試會自動略過)。
  - 對白播完(或略過)選單才出現;對白期間不能開小遊戲、不能離開、不能摸頭、梅林不說話(對白框本身也擋住全部觸控)。
  - 每次進營地只播一次(玩完小遊戲回來不會再播);對白檔不存在時安靜略過,直接顯示選單。
- **DS2 營地的梅林**(`game/camp/camp_merlin.gd`)
  - 用 C 線的 `assets/sprites/merlin/merlin_frames.tres`(idle、cast),畫在夜空與地面之間,所以圓桌蓋住他的下半身,看起來是坐在桌子後面讀卷軸。
  - 平常呼吸;每 6 至 11 秒施法一次(cast 動畫、杖頂加亮光暈、`sparkle` 閃光)。
  - 點他:施法、`magic` 音效(C 線新增;檔案還沒有時安靜略過)、`Haptics.play(&"light")`、對話泡泡說一句 `CAMP_MERLIN_01` 至 `06`;0.6 秒內連點不算。
  - 新的像素對話泡泡 `game/minigames/minigame_speech_bubble.gd`:白底墨框、尾巴指向說話的人、彈出動畫、自動換行(每行字數平均,逗號句號不會放在行首,「……」不會被拆開)、不會超出安全區。
  - **梅林的六句話**(D 線撰寫,`i18n/strings.csv`,每句 18 至 19 字):
    1. 老夫年輕時，一個咒語就能點亮整座城！
    2. 咦，老夫的眼鏡呢？……原來戴在臉上。
    3. 好騎士也要好好休息，多讓人摸摸頭吧。
    4. 營火、星星和好朋友，就是最好的魔法。
    5. 別看老夫這樣，老夫可是會飛的……大概。
    6. 《王室守則》第一條：國王要早點睡覺。
- **DS3 小遊戲包裝**(`game/minigames/scroll/`)
  - 卷軸上有《王室守則》:開頭的標題(`MINIGAME_SCROLL_TITLE`)、淡淡的條目編號(`MINIGAME_SCROLL_RULE`「第%d條」)與字線;條目跟著紙一起往下走。
  - 時間到:梅林跑進來站在卷軸右邊,0.6 秒後問「讀完了嗎？」(`MINIGAME_MERLIN_ASK`),一直問到評價畫面關掉。
  - 順手修正:卷軸上的第二段字線以前會超出紙的右邊。
  - 全部數值在 `scroll_config.tres` 的「王室守則與梅林(DS3)」。
- **DS4 效能**(`tests/line_d/stress_test.gd`、`stress_projectile.gd`)
  - 壓力測試加入:一直保持 16 支投射物(箭、劍氣、乾草叉的圖;先畫 0.7 秒紅色預警線再飛,用 Area2D 偵測主角與同伴,和 A 線同樣的負擔);17 個加亮混合的光暈(12 個跟著敵人、4 個火把、必殺技時一個大光暈);`--dialogue` 再蓋上一個正在顯示繪本插畫的對白框。
  - A 線的弓兵、空盔甲兵資料合併後,會自動混進 40 隻敵人裡(弓兵射真正的箭);C 線的光暈圖(檔名含 glow 或 light)合併後會自動改用。
  - 重新建置除錯版 APK 與沙盒 APK 並核對(結果見下方)。
- **DS5 商店**(`store/`)
  - 商店說明加入故事賣點:卡美洛、石中劍、西施犬梅林、貝德維爾、黑騎士,以及摩根娜的伏筆(紫色羽毛、紫色火光、月光下的狐狸眼睛);新敵人與困難模式;營地的梅林與《王室守則》。新的副標題、簡短說明、宣傳文字、關鍵字(不再重複 App 名稱裡的字)、截圖順序與說明文字。內容分級的說明加上 v2.3 的新內容(仍是同一級)。
  - `store/screenshots/capture.gd` 多截三張:`04_dialogue.png`(石中劍之丘,梅林自我介紹)、`05_storybook.png`(開場繪本頁)、`06_camp_merlin.png`(梅林在圓桌後面說話)。三種尺寸各六張,已在雲端執行過。
- **DS6 測試**:新增 20 個(`test_camp_story.gd` 16 個、`test_minigame.gd` 2 個、`test_stress_scene.gd` 2 個),更新 1 個(第二次營地的鬥牛犬測試先略過對白)。D 線共 86 個測試;全部 393 個測試通過。另外用暫時的 `data/story/camp1.tres`、`camp2.tres`(模擬 B 線,沒有提交)試過:整合測試、自動試玩機器人(略過 2 段營地對白,PLAYTHROUGH COMPLETE)與沙盒都正常。

### v2.3 效能數字(DS4,雲端無畫面模式,40 隻敵人,每種設定跑 3 次取中間值)

| 情況 | 每格 CPU(腳本 + 物理) | 最慢 1% | 說明 |
| --- | --- | --- | --- |
| 只有敵人 | 1.2 + 3.4 = 4.6 毫秒 | 6.9 毫秒 | 對照 |
| 加粒子特效(M3 的設定) | 1.6 + 3.4 = 5.0 毫秒 | 7.2 毫秒 | 同時最多 28 個特效、255 顆粒子 |
| 再加 16 支投射物 + 17 個光暈(新的預設) | 1.4 + 3.1 = 4.5 毫秒 | 9.5 毫秒 | 和上一行的差別在誤差之內 |
| 再加對白框與繪本插畫 | 1.6 + 3.5 = 5.1 毫秒 | 9.6 毫秒 | 最壞情況(真正的遊戲在對白時戰鬥會停) |
| 特效不設上限 | 1.6 + 3.5 = 5.0 毫秒 | 13.9 毫秒 | 最壞情況 |

一格的時間上限是 16.7 毫秒(60 FPS),平均都在 59 FPS。今天雲端同時有其他線在跑測試,數字有起伏(偶爾一次會跳到 30 毫秒以上),所以取中間值。投射物與光暈在 CPU 上幾乎不花時間;**光暈的負擔主要在顯示卡(加亮混合要多畫一層)**,雲端沒有顯示卡,要在手機上用「Android Sandbox」→「壓力測試」看。

**建議的上限**(給 A、C 線參考):同時存在的投射物不超過約 16 至 20 支;光暈圖每個不大於 32×32 像素、畫面上同時不超過約 20 個,另外最多一個全畫面大小的光暈(必殺技、閃電);M3 的粒子上限照舊(畫面上的粒子總數最好不超過約 250 顆)。

### v2.3 APK 核對(2026-11-16,v2.3)

`export/build_android.sh debug` 與 `sandbox` 各約 61 MB;`export/build_android.sh verify`:`com.doggyknight.prototype`、versionCode 1、minSdk 24、targetSdk 36、App 名稱「金毛騎士」、**唯一的權限 `android.permission.VIBRATE`**、zipalign 16 KB 通過、arm64-v8a 的 `libgodot_android.so` 與 `libc++_shared.so` LOAD 對齊 16384。新的梅林、對話泡泡、對白框、故事翻譯都在安裝檔裡。

### v2.4 的試玩說明(仍然有效)

1. 用 Godot 4.7.2 開啟專案,打開 `tests/line_d/camp_sandbox.tscn`,按「執行目前場景」(F6)。
2. **營地訓練(新)**:按「訓練(送 50 個零食)」——像從標題打開一樣,單獨打開訓練畫面,先送你 50 個零食。
   - 五項訓練:**活力**(活力上限)、**力量**(攻擊力)、**敏捷**(移動速度)、**忠誠**(忠誠累積)、**幸運**(寶箱與零食)。
   - 每一列:左邊是圖示(愛心、劍、羽毛、狗掌印、四葉草),名稱旁邊 5 格是等級,右上角的牌子是價格,下面一行是效果「現在 → 下一級」。
   - **整列就是按鈕**(手指好按)。買得起的列有金色外框、價格牌是橘色;買不起是灰色,按了沒反應;5 級滿了顯示「滿級」。
   - 買了:那一列閃白光、圖示跳一下、星星噴出來、新的等級格亮起、冒出「Lv.N！」,最上面的零食數往下數,旁邊冒「-N」;播升級音效,手機輕震一下。
   - 按「返回」(或 Android 的返回鍵)關掉。
3. **營地裡也有**:按「進入營地」或「第二次營地」→ 看完對白 → 選單中間一列左邊是新的「訓練」(右邊是原本的「同伴」)。營地右上角現在顯示零食數。
4. **小遊戲給零食(新)**:拉完卷軸,評價畫面多一行「零食 +N」(0 星 0 個、1 星 3 個、2 星 6 個、3 星 10 個);回到營地時右上角的零食數會跳一下、冒「+N」。
5. 壓力測試照舊(「壓力測試」按鈕);現在場上多了 3 個會打開的寶箱、12 個被吸向金毛的零食、繞著金毛轉的 6 道劍氣(像「旋風尾」進化)與定時的進化光柱。

截圖(雲端,180×320):`/tmp/line_d_shots/v24/`(營地選單、訓練畫面、剛升級、零食不夠、小遊戲評價)。

## 以前完成(摘要)

- M1 至 M3:營地(營火、星空、摸摸頭、鬥牛犬、營地音樂)、「拉扯王室卷軸」(完美停住、評價星星、被卷軸包起來)、小遊戲框架、評分與獎勵、遊玩記錄、平台介面預留、Android 匯出(APK / AAB、16 KB 分頁、VIBRATE 權限)、iOS 匯出說明、商店素材草稿與自動截圖、壓力測試。詳見 git 記錄與 `export/README.md`、`export/IOS.md`、`store/README.md`。

## 進行中

- (無)

## 被甚麼卡住

- 沒有。雲端沒有手機,「叫醒騎士」的節拍手感(判定窗口、音效延遲)還沒在實機上試過。

## 給其他線與整合工作階段(v2.6)

- **整合(必做)**:沒有新的接線。營地自己讀 `GameState.chapter` 與 `level_index`,依章播對白、換場景、換人、輪流小遊戲;B 線只要和以前一樣在第 2、4 關之後(`level_index` 1、3)開營地,並在新遊戲前設好 `GameState.chapter`。新的小遊戲一樣發 `EventBus.minigame_finished`(id `&"wake"`),獎勵已套用到 `GameState`。
- **整合(擴充試玩機器人到三章時必做)**:`tests/integration/playthrough_bot.gd` 約第 188 行把營地小遊戲當成 `ScrollMinigame`(`scroll.ink_state`)。第二章第一次與第三章第二次營地開的是 `WakeMinigame`,那一行會出錯。請先判斷 `minigame is WakeMinigame`,照 `tests/line_d/camp_sandbox.gd` 的 `_bot_wake()` 在圈圈到時呼叫 `tap_lane(lane)`(或乾脆等時間到)。
- **B 線**:`test_story_data.gd` 的「STORY.md 第 5 節的段落」測試目前因 STORY.md 多了第二、三章的段落而失敗(不是 D 線改的)。
- **C 線**:營地用 `assets/sprites/lancelot/lancelot_frames.tres`(`idle`、被點時 `attack`)與 `assets/sprites/lady_lake/lady_lake_frames.tres`(`idle`、`cast`),原地替換即可;兩人都放大 2 倍、圖朝右畫(蘭斯洛特在營地翻成朝左)。佔位圖是整格的方塊,正式圖每格四周留透明時看起來會更好(點擊範圍不受影響)。新文字:`CAMP_LANCELOT_*`、`CAMP_LADY_*`、`UI_CAMP_MINIGAME_WAKE`、`MINIGAME_WAKE_*`、`CAMP_SANDBOX_C2`、`CAMP_SANDBOX_C3`、`CAMP_SANDBOX_BOSS`。
- **A 線**:頭目的效能數字見上表;新頭目合併後可以把 `boss_stress_test.gd` 的替身換成 `arena.spawn_enemy(&"morgana", …)` 再量一次(場景已經會用正式的場地與同伴)。

### 以前的交接(v2.4,仍然有效)

- **B 線**:
  - 標題的 `training_pressed`:實例化 `game/camp/training.tscn`,放在第 30 層的 CanvasLayer 之下;收到 `closed` 後移除(或設 `free_on_close = true`)。**訓練開著時,標題的返回鍵請不要開「離開遊戲」對話框**——訓練自己會用 `back_requested` 關閉(和製作名單同樣處理)。
  - 訓練會改 `GameState.snacks` 與 `meta_upgrades` 並發 `snacks_changed`;**請在收到 `snacks_changed`(或訓練關閉)時存檔**,不然買完立刻關 App 會失去這次購買(切到背景時你本來就會存)。
  - 營地裡買的升級只寫進 `GameState.meta_upgrades`;要不要在這一局立刻生效由 B 線決定(可以聽營地的 `training_upgraded(id, level)`)。我建議「下一次新遊戲才生效」照 4.12,但在訓練畫面的提示寫的是「效果永遠保留」,不會誤導。
  - 小遊戲直接把零食加到 `GameState.snacks` 並發 `snacks_changed`,B 線不用再加。
  - 請在 `meta_upgrades.tres` 的 `name_key` / `desc_key` 用 `TRAINING_<ID>_NAME` / `TRAINING_<ID>_DESC`(文字 D 線已寫好,`DESC` 裡有 `%s`)。
- **C 線**:訓練畫面的圖示是程式畫的 8×8 像素圖;想換正式圖,填 `game/camp/training_config.tres` 的 `icons`(升級 id → 16×16 圖),不用改程式。價格牌與零食數用 `assets/fx/snack/snack_frames.tres` 的第一格。新文字:`TRAINING_*`、`CAMP_TRAINING`、`MINIGAME_REWARD_SNACKS`、`CAMP_SANDBOX_TRAINING`。
- **A 線**:壓力測試用 `assets/sprites/chest/chest_frames.tres` 的 `idle`、`open` 與 `assets/fx/sword_wave/` 當繞身劍氣;數字見上表。

## 下一步

- A 線的摩根娜與綠騎士合併後,用正式的頭目再跑一次 `boss_stress_test`。
- 在手機上試「叫醒騎士」的節拍與判定;如果覺得太難,調 `wake_config.tres` 的 `good_window_sec`(0.15 → 0.18)或 `bpm_end`(116 → 108)。
- C 線換上正式的蘭斯洛特與湖中仙女後,看一眼營地的位置(`camp_config.tres` 的 `lancelot_offset`、`merlin_offset`)。

## 需要擁有人決定的事(我先替你決定了,想改只要改資料檔或文字檔)

1. **新小遊戲選了「叫醒騎士」**(呼應第二章的午睡咒);名字「叫醒打瞌睡的騎士」。另一個候選「湖面跳石」沒做。
2. **輪流的方式**:第二章第一次營地先玩新的「叫醒騎士」,之後卷軸與叫醒騎士交替(2 章:叫醒、卷軸;3 章:卷軸、叫醒)。改 `camp_config.tres` 的 `minigame_rotation` 次序就能換。
3. **難度**:三顆星要 85 分(大約八成以上「完美!」);全部「好!」是兩顆星。改 `wake_grading.tres`。
4. **蘭斯洛特與湖中仙女的八句話**(見上面);改 `i18n/strings.csv` 的 `CAMP_LANCELOT_*`、`CAMP_LADY_*`。
5. **第三章的營地**:按 DEV_PLAN 放在「湖邊洞口與月光」;湖中仙女坐在梅林的位置,蘭斯洛特和貝德維爾都在。
6. 以前的決定仍然有效(訓練的名稱與價格、每次營地一次小遊戲、摸頭上限 5 下等)。

## 建議(只記錄,未實作)

- 第三章 3-5 過關後梅林回來了;如果日後想在最後一次營地讓梅林與湖中仙女同時出現,把 `lady_from_chapter` 改成依關卡判斷即可(現在第三章兩次營地都在 3-5 之前,所以不需要)。
- 營地的「同伴」入口日後可以做成和鬥牛犬、蘭斯洛特互動(餵香腸、比賽跑步),同樣用 `MinigameBase` 框架。
- 32 位元(armeabi-v7a)的程式庫讓 APK 大了約一半;若測試者都用 64 位元手機,可以在匯出設定關掉它。
