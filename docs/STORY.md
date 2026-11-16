# 《金毛騎士》第一章「石中劍」故事設定與對白

版本:v2.3,2026-11-16,整合工作階段撰寫。擁有人要求「故事要夠豐富、好玩」。

本文件是故事的唯一依據:角色設定(C 線畫頭像與插畫)、對白腳本(B 線轉成 `data/story/*.tres`,D 線在營地播放)。對白文字全部在 `i18n/story.csv`,鍵名與下表一致。改對白只改 `i18n/story.csv`;改次序或說話者要同時改本文件與 `data/story/`。

## 1. 基調

- 亞瑟王傳說(公有領域)的狗狗版:可愛、溫暖、帶點傻氣的幽默,但主線認真。
- 對白短:每句不超過 26 個中文字,手機上一頁就讀完;每段 2 至 7 句,隨時可以跳過。
- 狗不會受傷:任何畫面都不可以有血或受傷;黑騎士是「空盔甲」,倒下時散成碎片。
- **原創設計**:不要模仿任何電影或動畫版本的亞瑟王、梅林或石中劍(例如不要讓梅林有貓頭鷹助手、不要用「此路不通」之類的著名台詞)。

## 2. 世界

狗狗的王國「卡美洛」失去了國王。城外山丘上出現了插在石頭裡的寶劍:「拔出此劍者,即為卡美洛之王。」驕傲的騎士都拔不出來,卻被一隻追樹枝的金毛尋回犬當成樹枝拔了出來。狐狸女巫摩根娜想奪取王國,用魔法操縱稻草人、烏鴉和空盔甲阻止金毛前往卡美洛城。

## 3. 角色(C 線畫頭像 48×48;B、D 線用 speaker 代號)

| speaker 代號 | 名字(名牌) | 設定 | 頭像表情 |
| --- | --- | --- | --- |
| `goldie` | 金毛 | 主角。農家的金毛尋回犬,奶油金色、垂耳、大眼睛、紅披風、英式長劍。純真、樂觀、最愛撿樹枝;認真起來很可靠。 | `normal`、`happy`、`surprised`、`serious`、`tired` |
| `bulldog` | 貝德維爾 | 英國鬥牛犬騎士,圓盾上有藍色十字。金毛的兒時玩伴,忠心、嘴硬心軟、愛吃香腸。 | `normal`、`happy`、`serious` |
| `merlin` | 梅林 | 年邁的西施犬魔法師:長長的白毛像鬍子,藍色星星法師帽與長袍,小圓眼鏡,手杖頂端有發光的星星。有點健忘、愛自誇,但很有智慧。 | `normal`、`surprised`、`proud`、`worried` |
| `black_knight` | 黑騎士 | 守橋的巨大黑盔甲,面罩縫隙發紫光。說話低沉、簡短。其實裡面是空的。 | `normal` |
| `morgana` | 神秘的聲音 | 狐狸女巫摩根娜。第一章只以**紫色剪影**出現:狐狸耳朵、發光的眼睛、新月法杖。優雅、狡猾。 | `smirk` |
| `scarecrow_captain` | 稻草人隊長 | 戴隊長帽、插著紫色羽毛的大稻草人,拿乾草叉。說話帶「沙沙」聲。 | `angry` |
| `crow` | 烏鴉 | 摩根娜的探子,小而吵。 | `normal` |
| `narrator` | (不顯示名牌) | 旁白,只用在繪本頁。 | (沒有頭像) |

## 4. 繪本插畫(C 線,`assets/story/<id>.png`,160×120)

| id | 畫面 |
| --- | --- |
| `prologue_1` | 夜色中的卡美洛城,王座空著,王冠放在絨布枕上 |
| `prologue_2` | 晨光中山丘上的大石頭,寶劍插在上面發出微光 |
| `prologue_3` | 各種驕傲的狗狗騎士排隊拔劍,一個個拔得滿頭大汗 |
| `prologue_4` | 一根樹枝劃過天空,遠處一隻金毛興奮地追過來 |
| `ending_1` | 石橋上散落的黑盔甲,一縷紫色魔法火光從頭盔飄走 |
| `ending_2` | 月光下城牆上的狐狸剪影,紫色眼睛發光 |
| `ending_3` | 卡美洛城門打開,狗狗們揮旗歡呼,金毛與貝德維爾、梅林站在前面 |
| `teaser_1` | 圓桌與一圈空椅子,桌上放著石中劍(第二章「圓桌騎士」預告) |

## 5. 對白腳本

格式:`鍵 | speaker | 表情 | 插畫`(插畫空白 = 不換插畫;旁白一定有插畫)。文字見 `i18n/story.csv`。

### `prologue`:開場繪本(新遊戲時,1-1 之前)

| 鍵 | speaker | 表情 | 插畫 |
| --- | --- | --- | --- |
| STORY_PROLOGUE_01 | narrator | | prologue_1 |
| STORY_PROLOGUE_02 | narrator | | prologue_2 |
| STORY_PROLOGUE_03 | narrator | | prologue_2 |
| STORY_PROLOGUE_04 | narrator | | prologue_3 |
| STORY_PROLOGUE_05 | narrator | | prologue_4 |
| STORY_PROLOGUE_06 | narrator | | prologue_4 |

### `l1_before`:1-1 開打前

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_L1_BEFORE_01 | goldie | happy |
| STORY_L1_BEFORE_02 | merlin | surprised |
| STORY_L1_BEFORE_03 | merlin | proud |
| STORY_L1_BEFORE_04 | goldie | surprised |
| STORY_L1_BEFORE_05 | merlin | worried |
| STORY_L1_BEFORE_06 | merlin | normal |

### `l1_after`

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_L1_AFTER_01 | merlin | normal |
| STORY_L1_AFTER_02 | goldie | normal |
| STORY_L1_AFTER_03 | merlin | proud |
| STORY_L1_AFTER_04 | goldie | happy |
| STORY_L1_AFTER_05 | merlin | worried |

### `l2_before`

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_L2_BEFORE_01 | goldie | happy |
| STORY_L2_BEFORE_02 | merlin | worried |
| STORY_L2_BEFORE_03 | crow | normal |
| STORY_L2_BEFORE_04 | merlin | normal |

### `l2_after`

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_L2_AFTER_01 | goldie | tired |
| STORY_L2_AFTER_02 | merlin | normal |

### `camp1`:第一次營地(D 線,進營地時播放一次)

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_CAMP1_01 | merlin | proud |
| STORY_CAMP1_02 | merlin | proud |
| STORY_CAMP1_03 | merlin | normal |
| STORY_CAMP1_04 | goldie | surprised |
| STORY_CAMP1_05 | merlin | normal |

### `l3_before`:貝德維爾登場

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_L3_BEFORE_01 | bulldog | serious |
| STORY_L3_BEFORE_02 | goldie | happy |
| STORY_L3_BEFORE_03 | merlin | surprised |
| STORY_L3_BEFORE_04 | goldie | happy |
| STORY_L3_BEFORE_05 | bulldog | serious |
| STORY_L3_BEFORE_06 | merlin | normal |

### `l3_after`

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_L3_AFTER_01 | bulldog | normal |
| STORY_L3_AFTER_02 | merlin | worried |

### `l4_before`:稻草人隊長

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_L4_BEFORE_01 | bulldog | serious |
| STORY_L4_BEFORE_02 | scarecrow_captain | angry |
| STORY_L4_BEFORE_03 | goldie | serious |
| STORY_L4_BEFORE_04 | bulldog | happy |

### `l4_after`

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_L4_AFTER_01 | merlin | worried |
| STORY_L4_AFTER_02 | bulldog | serious |
| STORY_L4_AFTER_03 | merlin | normal |

### `camp2`:第二次營地

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_CAMP2_01 | bulldog | normal |
| STORY_CAMP2_02 | goldie | normal |
| STORY_CAMP2_03 | bulldog | happy |
| STORY_CAMP2_04 | merlin | proud |

### `l5_before`

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_L5_BEFORE_01 | merlin | normal |
| STORY_L5_BEFORE_02 | crow | normal |
| STORY_L5_BEFORE_03 | bulldog | serious |

### `l5_after`

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_L5_AFTER_01 | goldie | surprised |
| STORY_L5_AFTER_02 | merlin | worried |

### `l6_before`:黑騎士

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_L6_BEFORE_01 | black_knight | normal |
| STORY_L6_BEFORE_02 | black_knight | normal |
| STORY_L6_BEFORE_03 | bulldog | serious |
| STORY_L6_BEFORE_04 | goldie | serious |

### `l6_after`:結局

| 鍵 | speaker | 表情 | 插畫 |
| --- | --- | --- | --- |
| STORY_L6_AFTER_01 | narrator | | ending_1 |
| STORY_L6_AFTER_02 | merlin | worried | |
| STORY_L6_AFTER_03 | morgana | smirk | ending_2 |
| STORY_L6_AFTER_04 | morgana | smirk | |
| STORY_L6_AFTER_05 | narrator | | ending_3 |
| STORY_L6_AFTER_06 | merlin | proud | |
| STORY_L6_AFTER_07 | goldie | happy | |

### `teaser`:第二章預告(結局之後、回標題之前)

| 鍵 | speaker | 表情 | 插畫 |
| --- | --- | --- | --- |
| STORY_TEASER_01 | narrator | | teaser_1 |

## 6. 失敗提示(C 線的失敗畫面隨機顯示一句)

`STORY_TIP_01` 至 `STORY_TIP_08`,由梅林說(失敗畫面可以放梅林的小頭像)。

## 7. 營地裡的梅林(D 線)

點營地裡的梅林會說一句:`CAMP_MERLIN_01` 至 `CAMP_MERLIN_06`(D 線在 `i18n/strings.csv` 撰寫,語氣同上)。

## 8. 播放規則(B 線、D 線)

- 新遊戲:`prologue` → 1-1 場地出現 → `l1_before` → 關卡標題卡 → 第一波。
- 每關:場地出現(轉場露出)→ `story_before`(若有)→ 標題卡 → 波次;過關慶祝 → `story_after`(若有)→ 結算。
- **重試同一關時不再播放** `story_before`。從存檔「繼續冒險」時播放該關的 `story_before`。
- 營地:第一次進入營地播 `camp1`,第二次播 `camp2`(每次營地只播一次)。
- 1-6 過關:慶祝 → `l6_after`(結局,含插畫)→ 結算(第一章完)→ `teaser` → 回標題。
- 每段對白都可以點「略過」;已看過的段落記在 `GameState.story_seen`(存檔),但再玩一次時仍然播放(玩家可以略過)。
