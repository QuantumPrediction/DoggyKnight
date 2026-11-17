# D 線(營地、小遊戲與手機建置)狀態報告

最後更新:2026-11-17(v2.4 玩法深度:DV1 至 DV4 全部完成)

## 怎樣試玩(不用寫程式)

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

## 已完成(v2.4 玩法深度,DEV_PLAN 第 17 節)

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

## 以前完成(摘要)

- M1 至 M3:營地(營火、星空、摸摸頭、鬥牛犬、營地音樂)、「拉扯王室卷軸」(完美停住、評價星星、被卷軸包起來)、小遊戲框架、評分與獎勵、遊玩記錄、平台介面預留、Android 匯出(APK / AAB、16 KB 分頁、VIBRATE 權限)、iOS 匯出說明、商店素材草稿與自動截圖、壓力測試。詳見 git 記錄與 `export/README.md`、`export/IOS.md`、`store/README.md`。

## 進行中

- (無)

## 被甚麼卡住

- 沒有。雲端沒有手機,訓練畫面的手感(整列按鈕、捲動)與震動還沒在實機上試過。

## 給其他線與整合工作階段(v2.4)

- **B 線**:
  - 標題的 `training_pressed`:實例化 `game/camp/training.tscn`,放在第 30 層的 CanvasLayer 之下;收到 `closed` 後移除(或設 `free_on_close = true`)。**訓練開著時,標題的返回鍵請不要開「離開遊戲」對話框**——訓練自己會用 `back_requested` 關閉(和製作名單同樣處理)。
  - 訓練會改 `GameState.snacks` 與 `meta_upgrades` 並發 `snacks_changed`;**請在收到 `snacks_changed`(或訓練關閉)時存檔**,不然買完立刻關 App 會失去這次購買(切到背景時你本來就會存)。
  - 營地裡買的升級只寫進 `GameState.meta_upgrades`;要不要在這一局立刻生效由 B 線決定(可以聽營地的 `training_upgraded(id, level)`)。我建議「下一次新遊戲才生效」照 4.12,但在訓練畫面的提示寫的是「效果永遠保留」,不會誤導。
  - 小遊戲直接把零食加到 `GameState.snacks` 並發 `snacks_changed`,B 線不用再加。
  - 請在 `meta_upgrades.tres` 的 `name_key` / `desc_key` 用 `TRAINING_<ID>_NAME` / `TRAINING_<ID>_DESC`(文字 D 線已寫好,`DESC` 裡有 `%s`)。
- **C 線**:訓練畫面的圖示是程式畫的 8×8 像素圖;想換正式圖,填 `game/camp/training_config.tres` 的 `icons`(升級 id → 16×16 圖),不用改程式。價格牌與零食數用 `assets/fx/snack/snack_frames.tres` 的第一格。新文字:`TRAINING_*`、`CAMP_TRAINING`、`MINIGAME_REWARD_SNACKS`、`CAMP_SANDBOX_TRAINING`。
- **A 線**:壓力測試用 `assets/sprites/chest/chest_frames.tres` 的 `idle`、`open` 與 `assets/fx/sword_wave/` 當繞身劍氣;數字見上表。

## 下一步

- B 線合併 `meta_upgrades.tres` 後,確認訓練畫面讀到正式的價格與效果(畫面不用改)。
- 在手機上試訓練畫面:整列按鈕好不好按、短手機(有瀏海)上列表捲動是否順。

## 需要擁有人決定的事(我先替你決定了,想改只要改資料檔或文字檔)

1. **訓練的名稱與說明**:活力 / 力量 / 敏捷 / 忠誠 / 幸運;說明「活力上限」「攻擊力」「移動速度」「忠誠累積」「寶箱零食」。畫面標題「營地訓練」,提示「用零食訓練，效果永遠保留！」。改 `i18n/strings.csv` 的 `TRAINING_*`。
2. **小遊戲給的零食**:0 / 3 / 6 / 10 個(`game/minigames/scroll/scroll_grading.tres` 的 `snack_reward`)。
3. **替身價格**(上表):B 線的正式資料會取代它;全部升滿約 950 個零食,讓訓練成為好幾局的目標。
4. **營地選單**:「訓練」和「同伴」並排各佔一半,選單仍是三列,不會擠到營火和金毛。
5. **整列是按鈕**(而不是右邊一顆小按鈕):手機上更好按,文字也有地方完整顯示「現在 → 下一級」。
6. **買不起的列**變灰、按了沒反應(不跳提示),跟 DEV_PLAN「買得起才可以按」一致。
7. 以前的決定仍然有效(梅林的六句話、每次營地一次小遊戲、摸頭上限 5 下、門檻 70 / 150 / 230 公分、套件識別碼是佔位)。

## 建議(只記錄,未實作)

- 營地的「同伴」入口日後可以做成和鬥牛犬互動(餵香腸、丟球),同樣用 `MinigameBase` 框架。
- 梅林的話日後可以依章節或通關次數換一組(例如打完第一章後說摩根娜的事)。
- 32 位元(armeabi-v7a)的程式庫讓 APK 大了約一半;若測試者都用 64 位元手機,可以在匯出設定關掉它。
