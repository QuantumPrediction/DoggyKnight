# 《金毛騎士》故事設定與對白(第一章「石中劍」、第二章「圓桌騎士」、第三章「湖中仙女」)

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

---

# 第二章「圓桌騎士」與第三章「湖中仙女」(v2.6)

版本:v2.6,2026-11-17,整合工作階段撰寫。擁有人要求「至少 3 章」。基調、對白長度、「狗不會受傷」等規則同第 1 節。

## 9. 三章的大綱

| 章 | 名稱 | 一句話 | 頭目 | 新同伴 |
| --- | --- | --- | --- | --- |
| 1 | 石中劍 | 金毛拔出石中劍,前往卡美洛,在石橋打敗黑騎士 | 黑騎士 | 貝德維爾(1-3 起) |
| 2 | 圓桌騎士 | 摩根娜用「百年午睡咒」讓全城沉睡;金毛叫醒騎士、坐滿圓桌 | 綠騎士(中頭目:石像鬼統領) | 蘭斯洛特(2-3 起) |
| 3 | 湖中仙女 | 梅林被抓;湖中仙女帶路,渡過迷霧湖,登上摩根娜之塔 | 摩根娜(中頭目:幻影黑騎士) | (貝德維爾與蘭斯洛特一起) |

**結局的意思**:金毛沒有「消滅」摩根娜,而是邀請她一起玩撿樹枝。她一直很孤單:圓桌從來沒有邀請過她。這呼應金毛在第一章營地說的「我只想大家都可以安心地玩撿樹枝」。

**每章是獨立的一輪**(像同類型手機遊戲的「章節」):從等級 1、沒有把戲開始;營地訓練(永久升級)會帶過去。打完第 N 章解鎖第 N+1 章;標題畫面可以選章。

## 10. 第二、三章的新角色(C 線畫頭像 48×48)

| speaker 代號 | 名字(名牌) | 設定 | 頭像表情 |
| --- | --- | --- | --- |
| `lancelot` | 蘭斯洛特 | 柴犬騎士,銀色輕甲、藍色羽飾頭盔、長槍。驕傲、快、嘴巴壞,但重視榮譽;第二章 2-3 起成為第二位同伴。 | `normal`、`happy`、`serious`、`surprised` |
| `gargoyle` | 石像鬼統領 | 城牆上的大石像鬼,灰色石頭身體、小翅膀、長角;被控制時眼睛發紫光,清醒後變回溫和的守護者。 | `normal` |
| `green_knight` | 綠騎士 | 花園的守護者,樹籬修剪成的巨大騎士,頭上戴著一頂「葉子帽」(圓圓的灌木),手拿藤鞭。豪爽、愛笑、愛玩遊戲。中咒時葉子帽上插著紫色荊棘。 | `normal` |
| `lady_lake` | 湖中仙女 | 白色薩摩耶,穿著像水波一樣的淡藍長裙,身邊有小水珠繞著飄。溫柔、知道很多往事。 | `normal`、`smile`、`worried` |
| `morgana_true` | 摩根娜 | 第三章第一次露出真面目的狐狸女巫:紅褐色毛、九分優雅一分寂寞、紫色斗篷、新月法杖。第二章與 3-5 之前仍用 `morgana`(紫色剪影,名牌「神秘的聲音」)。 | `normal`、`angry`、`sad`、`smile` |

## 11. 第二、三章的繪本插畫(C 線,`assets/story/<id>.png`,160×120)

| id | 畫面 |
| --- | --- |
| `c2_prologue_1` | 清晨的卡美洛城,紫色荊棘爬滿城牆,街上的狗狗睡成一團 |
| `c2_prologue_2` | 圓桌旁的騎士們趴在桌上睡覺,頭上冒著「Zzz」 |
| `c2_ending_1` | 綠騎士的紫色荊棘碎成光點,花園開滿花 |
| `c2_ending_2` | 騎士們伸懶腰醒來,圓桌坐滿,金毛在中間 |
| `c2_ending_3` | 夜晚,紫色的霧從窗戶飄進梅林的房間(梅林睡著,只見帽子) |
| `teaser_2` | 迷霧湖與湖中央小島上的高塔(第三章預告) |
| `c3_prologue_1` | 清晨的迷霧湖,遠方小島上有一座尖塔 |
| `c3_prologue_2` | 湖面發光,白色薩摩耶仙女從水中升起 |
| `c3_ending_1` | 塔頂,摩根娜坐在地上,法杖落地;金毛叼著一根樹枝遞給她 |
| `c3_ending_2` | 加冕禮:金毛戴上王冠,圓桌坐滿騎士,摩根娜也坐在其中一個位子 |
| `c3_ending_3` | 夕陽下的草地,大家(包括摩根娜)一起玩撿樹枝 |

## 12. 第二、三章的對白腳本

格式同第 5 節。文字見 `i18n/story.csv`。第一章的 `teaser` 文字改為「第二章已經開啟」。

### `c2_prologue`:第二章開場繪本(第二章新遊戲時,2-1 之前)

| 鍵 | speaker | 表情 | 插畫 |
| --- | --- | --- | --- |
| STORY_C2_PROLOGUE_01 | narrator |  | c2_prologue_1 |
| STORY_C2_PROLOGUE_02 | narrator |  | c2_prologue_1 |
| STORY_C2_PROLOGUE_03 | narrator |  | c2_prologue_2 |
| STORY_C2_PROLOGUE_04 | narrator |  | c2_prologue_2 |
| STORY_C2_PROLOGUE_05 | narrator |  | c2_prologue_2 |

### `c2l1_before`:2-1 城下町

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_C2L1_BEFORE_01 | goldie | surprised |
| STORY_C2L1_BEFORE_02 | merlin | worried |
| STORY_C2L1_BEFORE_03 | bulldog | serious |
| STORY_C2L1_BEFORE_04 | merlin | normal |

### `c2l1_after`

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_C2L1_AFTER_01 | goldie | normal |
| STORY_C2L1_AFTER_02 | merlin | worried |
| STORY_C2L1_AFTER_03 | bulldog | serious |

### `c2l2_before`:2-2 城堡中庭:蘭斯洛特登場

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_C2L2_BEFORE_01 | lancelot | serious |
| STORY_C2L2_BEFORE_02 | goldie | happy |
| STORY_C2L2_BEFORE_03 | lancelot | serious |
| STORY_C2L2_BEFORE_04 | bulldog | serious |
| STORY_C2L2_BEFORE_05 | lancelot | normal |

### `c2l2_after`:蘭斯洛特加入(2-3 起成為第二位同伴)

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_C2L2_AFTER_01 | lancelot | surprised |
| STORY_C2L2_AFTER_02 | goldie | happy |
| STORY_C2L2_AFTER_03 | lancelot | happy |
| STORY_C2L2_AFTER_04 | merlin | proud |

### `c2_camp1`:第二章第一次營地

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_C2_CAMP1_01 | lancelot | normal |
| STORY_C2_CAMP1_02 | bulldog | happy |
| STORY_C2_CAMP1_03 | goldie | tired |
| STORY_C2_CAMP1_04 | merlin | normal |

### `c2l3_before`:2-3 王家書庫

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_C2L3_BEFORE_01 | merlin | surprised |
| STORY_C2L3_BEFORE_02 | lancelot | serious |
| STORY_C2L3_BEFORE_03 | merlin | normal |
| STORY_C2L3_BEFORE_04 | goldie | serious |

### `c2l3_after`

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_C2L3_AFTER_01 | merlin | proud |
| STORY_C2L3_AFTER_02 | merlin | worried |
| STORY_C2L3_AFTER_03 | lancelot | normal |
| STORY_C2L3_AFTER_04 | bulldog | serious |

### `c2l4_before`:2-4 城牆之上:石像鬼統領

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_C2L4_BEFORE_01 | crow | normal |
| STORY_C2L4_BEFORE_02 | gargoyle | normal |
| STORY_C2L4_BEFORE_03 | gargoyle | normal |
| STORY_C2L4_BEFORE_04 | goldie | serious |
| STORY_C2L4_BEFORE_05 | lancelot | serious |

### `c2l4_after`

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_C2L4_AFTER_01 | gargoyle | normal |
| STORY_C2L4_AFTER_02 | goldie | happy |
| STORY_C2L4_AFTER_03 | merlin | normal |

### `c2_camp2`:第二章第二次營地

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_C2_CAMP2_01 | lancelot | normal |
| STORY_C2_CAMP2_02 | goldie | normal |
| STORY_C2_CAMP2_03 | lancelot | happy |
| STORY_C2_CAMP2_04 | bulldog | happy |

### `c2l5_before`:2-5 魔法花園

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_C2L5_BEFORE_01 | merlin | worried |
| STORY_C2L5_BEFORE_02 | goldie | surprised |
| STORY_C2L5_BEFORE_03 | lancelot | serious |

### `c2l5_after`

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_C2L5_AFTER_01 | goldie | surprised |
| STORY_C2L5_AFTER_02 | merlin | worried |

### `c2l6_before`:2-6 綠色禮拜堂:綠騎士

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_C2L6_BEFORE_01 | green_knight | normal |
| STORY_C2L6_BEFORE_02 | goldie | happy |
| STORY_C2L6_BEFORE_03 | green_knight | normal |
| STORY_C2L6_BEFORE_04 | green_knight | normal |
| STORY_C2L6_BEFORE_05 | lancelot | serious |
| STORY_C2L6_BEFORE_06 | goldie | serious |

### `c2l6_after`:第二章結局

| 鍵 | speaker | 表情 | 插畫 |
| --- | --- | --- | --- |
| STORY_C2L6_AFTER_01 | narrator |  | c2_ending_1 |
| STORY_C2L6_AFTER_02 | green_knight | normal |  |
| STORY_C2L6_AFTER_03 | narrator |  | c2_ending_2 |
| STORY_C2L6_AFTER_04 | lancelot | happy |  |
| STORY_C2L6_AFTER_05 | merlin | proud |  |
| STORY_C2L6_AFTER_06 | narrator |  | c2_ending_3 |
| STORY_C2L6_AFTER_07 | morgana | smirk |  |

### `c2_teaser`:第三章預告

| 鍵 | speaker | 表情 | 插畫 |
| --- | --- | --- | --- |
| STORY_C2_TEASER_01 | narrator |  | teaser_2 |

### `c3_prologue`:第三章開場繪本(第三章新遊戲時,3-1 之前)

| 鍵 | speaker | 表情 | 插畫 |
| --- | --- | --- | --- |
| STORY_C3_PROLOGUE_01 | narrator |  | c3_prologue_1 |
| STORY_C3_PROLOGUE_02 | narrator |  | c3_prologue_1 |
| STORY_C3_PROLOGUE_03 | narrator |  | c3_prologue_2 |
| STORY_C3_PROLOGUE_04 | lady_lake | normal | c3_prologue_2 |

### `c3l1_before`:3-1 迷霧湖畔:湖中仙女

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_C3L1_BEFORE_01 | lady_lake | normal |
| STORY_C3L1_BEFORE_02 | goldie | serious |
| STORY_C3L1_BEFORE_03 | lady_lake | worried |
| STORY_C3L1_BEFORE_04 | bulldog | serious |

### `c3l1_after`

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_C3L1_AFTER_01 | lancelot | normal |
| STORY_C3L1_AFTER_02 | lady_lake | normal |

### `c3l2_before`:3-2 妖精森林

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_C3L2_BEFORE_01 | goldie | surprised |
| STORY_C3L2_BEFORE_02 | lady_lake | worried |
| STORY_C3L2_BEFORE_03 | lancelot | serious |

### `c3l2_after`

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_C3L2_AFTER_01 | bulldog | normal |
| STORY_C3L2_AFTER_02 | goldie | normal |
| STORY_C3L2_AFTER_03 | lady_lake | normal |

### `c3_camp1`:第三章第一次營地

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_C3_CAMP1_01 | lady_lake | normal |
| STORY_C3_CAMP1_02 | goldie | normal |
| STORY_C3_CAMP1_03 | lady_lake | worried |
| STORY_C3_CAMP1_04 | lancelot | serious |
| STORY_C3_CAMP1_05 | lady_lake | normal |

### `c3l3_before`:3-3 月光石陣

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_C3L3_BEFORE_01 | lady_lake | normal |
| STORY_C3L3_BEFORE_02 | crow | normal |
| STORY_C3L3_BEFORE_03 | goldie | serious |

### `c3l3_after`

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_C3L3_AFTER_01 | lancelot | surprised |
| STORY_C3L3_AFTER_02 | lady_lake | normal |
| STORY_C3L3_AFTER_03 | goldie | surprised |

### `c3l4_before`:3-4 水晶洞窟:幻影黑騎士

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_C3L4_BEFORE_01 | goldie | surprised |
| STORY_C3L4_BEFORE_02 | black_knight | normal |
| STORY_C3L4_BEFORE_03 | bulldog | serious |
| STORY_C3L4_BEFORE_04 | lady_lake | worried |

### `c3l4_after`

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_C3L4_AFTER_01 | black_knight | normal |
| STORY_C3L4_AFTER_02 | goldie | serious |
| STORY_C3L4_AFTER_03 | lady_lake | normal |

### `c3_camp2`:第三章第二次營地

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_C3_CAMP2_01 | bulldog | normal |
| STORY_C3_CAMP2_02 | goldie | normal |
| STORY_C3_CAMP2_03 | lancelot | surprised |
| STORY_C3_CAMP2_04 | goldie | happy |
| STORY_C3_CAMP2_05 | lady_lake | smile |

### `c3l5_before`:3-5 摩根娜之塔

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_C3L5_BEFORE_01 | morgana | smirk |
| STORY_C3L5_BEFORE_02 | morgana | smirk |
| STORY_C3L5_BEFORE_03 | lancelot | serious |

### `c3l5_after`

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_C3L5_AFTER_01 | merlin | worried |
| STORY_C3L5_AFTER_02 | goldie | happy |

### `c3l6_before`:3-6 塔頂:摩根娜(最終頭目)

| 鍵 | speaker | 表情 |
| --- | --- | --- |
| STORY_C3L6_BEFORE_01 | morgana_true | normal |
| STORY_C3L6_BEFORE_02 | morgana_true | angry |
| STORY_C3L6_BEFORE_03 | merlin | worried |
| STORY_C3L6_BEFORE_04 | goldie | serious |
| STORY_C3L6_BEFORE_05 | merlin | normal |

### `c3l6_after`:最終結局

| 鍵 | speaker | 表情 | 插畫 |
| --- | --- | --- | --- |
| STORY_C3L6_AFTER_01 | narrator |  | c3_ending_1 |
| STORY_C3L6_AFTER_02 | morgana_true | sad |  |
| STORY_C3L6_AFTER_03 | goldie | happy |  |
| STORY_C3L6_AFTER_04 | morgana_true | sad |  |
| STORY_C3L6_AFTER_05 | merlin | proud |  |
| STORY_C3L6_AFTER_06 | narrator |  | c3_ending_2 |
| STORY_C3L6_AFTER_07 | goldie | happy |  |
| STORY_C3L6_AFTER_08 | morgana_true | smile |  |
| STORY_C3L6_AFTER_09 | narrator |  | c3_ending_3 |
| STORY_C3L6_AFTER_10 | narrator |  | c3_ending_3 |

### `c3_teaser`:全破之後(結算之後、回標題之前)

| 鍵 | speaker | 表情 | 插畫 |
| --- | --- | --- | --- |
| STORY_C3_TEASER_01 | narrator |  | c3_ending_3 |

## 13. 第二、三章的失敗提示與播放規則

- 失敗提示增加 `STORY_TIP_09` 至 `STORY_TIP_14`(新敵人與頭目)。失敗畫面可以只抽目前這一章用得上的提示,也可以全部隨機。
- 播放規則同第 8 節,段落 id 換成這一章的:第 N 章新遊戲 → `cN_prologue`(第一章是 `prologue`)→ N-1 場地 → `cNl1_before` → ……;營地第一次 `cN_camp1`、第二次 `cN_camp2`;最後一關過關 → `cNl6_after` → 結算 → `cN_teaser` → 回標題。
- 營地與故事裡的梅林:第三章 3-5 過關之前梅林不在隊伍裡(被抓走了),營地改由湖中仙女站在梅林的位置;第三章營地點她會說 `CAMP_LADY_01` 至 `CAMP_LADY_04`(D 線撰寫)。
