# 《金毛騎士》上 Steam 的可行性分析:AI 製作的遊戲與 Steam 爆紅案例

> **用途**:徵求第二意見。本文件整理了專案現況、Steam 市場數據、AI 製作遊戲的現況與爆紅案例,以及我們的初步結論和建議。歡迎直接挑戰任何一點。第 10 節列出最想得到意見的問題。
>
> **撰寫**:Claude(AI,本專案的開發助理),2026-11-18。市場數據來自網上搜尋(第 11 節列出來源);部分數字來自第三方估算或彼此矛盾,文中已註明。**撰寫者參與了這個遊戲的開發,評分可能偏寬鬆。**

---

## 1. 一頁摘要

- **《金毛騎士》**是一款像素風動作輪迴(roguelite)手機遊戲:金毛尋回犬把石中劍當樹枝拔了出來,成為騎士。玩法參考《Archero》(移動閃避、停下自動攻擊、升級三選一),加上完整故事、同伴與營地。
- **製作方式**:擁有人不寫程式;全部程式、像素美術(由程式逐點繪製)與音樂(由程式生成)都由 AI(Claude)製作。
- **現況**:六章 36 關的完整原型,自動測試與自動試玩機器人可以從頭玩到結局;**還沒有真人試玩、還沒有實機測試**;只有繁體中文;手機直向、只支援觸控。
- **最近的觸發點**:韓國一人開發、自稱「100% 程式由 AI 生成」的 **Slotbound** 在 2026 年 11 月登上 Steam,同時在線最高約 2.95 萬人,評價「大多好評」。擁有人因此考慮把《金毛騎士》放上 Steam。
- **初步結論**:
  1. Slotbound 證明「不會寫程式 + AI」可以做出 Steam 熱門遊戲,但它成功的關鍵是**一句話就懂的新奇玩法**與**上市前幾個月的宣傳**(預告片爆紅 → 免費試玩版 → Steam 新品節 → 上市前超過 10 萬願望清單),不是內容量。
  2. 《金毛騎士》的強項(技巧為主、故事、角色、頭目設計)正好是 Slotbound 被批評的地方(太靠運氣、平衡差、太被動);但我們**缺一個屬於自己的玩法鉤子**,也**完全沒有開始宣傳**。
  3. 照現狀放上 Steam 會被淹沒;需要先定下鉤子、做 Steam 版的基本要求、用免費試玩版測試市場。

---

## 2. 專案現況

| 項目 | 現況 |
| --- | --- |
| 引擎與平台 | Godot 4.7.2;目標 iOS 與 Android,直向 180×320 像素整數放大;Android 建置已驗證(2026 年的商店規定) |
| 製作方式 | 擁有人提出方向與決定;AI 負責全部程式(約 3.7 萬行 GDScript)、美術、音樂、文字;約 290 個提交 |
| 故事 | 六章(石中劍、圓桌騎士、湖中仙女、沉沒之國、紅龍與白龍、卡姆蘭之戰);372 句對白;38 張繪本插畫;18 位說話角色、43 個頭像 |
| 關卡 | 36 關、36 張背景(每章 6 張)、18 首音樂 |
| 敵人 | 15 種一般敵人、6 個中頭目、6 場頭目戰(包括雙龍同時登場、三階段的最終頭目);所有危險攻擊都有地面預警 |
| 構築 | 12 個把戲(技能)+ 4 個進化;中途二選一事件(祝福或誘惑);寶箱 |
| 同伴 | 4 位狗騎士同伴,各有不同攻擊(盾牌、長槍突刺、豎琴遠程、大鐵鎚震暈) |
| 其他 | 營地(3 個小遊戲、對白、永久升級);困難模式;無盡試煉;星級評分 |
| 品質 | 770 個自動測試全部通過;自動試玩機器人可以打通六章 |
| **沒有的** | 真人試玩、實機測試、英文與簡體中文、橫向畫面與手把操作、成就與每日挑戰、收費設計、專業美術與作曲 |

自動試玩機器人(會閱讀全部地面預警並閃避)的結果:每關約 60 至 150 秒;每章倒下 0 至 2 次。**機器人閃避比真人準,真實難度要靠真人試玩確認。**

---

## 3. 自我評分(10 分滿分)

撰寫者沒有真人試玩、聽不到音樂;分數依據程式、截圖與自動試玩數據。

| 部分 | 分數 | 理由 |
| --- | --- | --- |
| 核心玩法手感 | 6.5 | 驗證過的玩法、預警清楚;近戰「停下才揮劍」遇到繞圈或舉盾的敵人會卡手 |
| 構築深度與重玩性 | 5 | 只有 12 個把戲、4 個進化,幾輪就熟悉;**最大弱點** |
| 敵人與頭目設計 | 7.5 | 敵人各有機制;頭目有階段變化,是亮點 |
| 內容量 | 7 | 手機上充足;故事約 3 至 4 小時(估計) |
| 故事與角色 | 7.5 | 溫暖幽默、主線一致(每個反派都有理由,結局是「邀請」而不是「消滅」);同類型少見 |
| 美術 | 6.5 | 統一、可愛;以程式繪圖來說很好,但不及頂級像素作品 |
| 音樂音效 | 5(推測) | 程式生成,大概「夠用」但不易記住 |
| 介面與操作 | 6.5 | 觸控友善、流程完整;畫面像素很小 |
| 技術品質 | 7 | 測試完整;未經實機驗證 |
| 長期留存系統 | 4.5 | 只有營地永久升級;沒有成就、每日挑戰、收集 |
| 語言 | 3 | 只有繁體中文 |
| 原創性與話題性 | 6 | 題材可愛(狗狗 + 亞瑟王),玩法類型常見 |
| **總分** | **手機版約 6.5;照現狀放上 Steam 約 4.5** | |

---

## 4. Steam 市場現況

- **供應過剩**:2025 年 Steam 上架了約 19,000 款遊戲(2024 年約 18,500 款),其中近一半的評論不到 10 則。
- **收入**:各來源都指出獨立遊戲收入的中位數非常低(有分析指只有幾百美元);一半付費遊戲收入少於約 4,000 美元。數字因方法不同而差很遠,但方向一致。
- **類型擁擠**:有分析指 roguelike/roguelite 每年上架數由 2021 年約 400 款增加到 2025 年接近 2,000 款,其中最多的是動作輪迴與《Vampire Survivors》式的「自動攻擊打一大群敵人」遊戲。
- **語言**:在 Steam 硬體調查的部分月份,簡體中文是最多人使用的語言(例如 2025 年 2 月;調查方法有爭議,數字波動很大),英文第二。**英文與簡體中文是 Steam 的必要語言。**

---

## 5. AI 與 Steam 遊戲的現況

**兩種「AI 遊戲」**

1. **用 AI 製作的遊戲**(開發過程用 AI 寫程式、畫圖、作曲;玩家玩到的是一般遊戲)。Slotbound 與《金毛騎士》屬於這一類。
2. **以 AI 為玩法的遊戲**(遊戲中的角色或內容由 AI 即時生成),例如 Whispers from the Star、AI2U、AI Roguelite。這類遊戲幾乎都是獨立作品;一份 2026 年的整理列出 AI2U 約 1,900 則評論、88% 好評,Whispers from the Star 約 1,660 則評論、80% 好評(第三方整理,未獨立核實)。

**數據**

- 2025 年在 Steam 上架的遊戲中,約五分之一申報使用了生成式 AI;到 2025 年 7 月,整個 Steam 目錄約 7% 有申報(約 7,800 款)。
- 公開申報使用生成式 AI 的 Steam 遊戲在一年內合計收入約 6.6 億美元,但主要來自大作(例如《使命召喚》、《Stellaris》、《inZOI》)。
- 2026 年 Steam 新品節最熱門的 100 個試玩版中,約 10% 申報使用生成式 AI。

**規定與玩家態度**

- Valve 修訂了申報規則:開發者需要申報**玩家看得到或聽得到**的 AI 生成內容(美術、音樂等);開發工具(例如寫程式)不在此限。
- 玩家反應**偏負面**:不少玩家表示會直接忽略申報 AI 的遊戲;SteamDB 已加入「排除 AI 內容」的篩選;有大作因玩家反彈而移除 AI 內容。也有評論認為 AI 標籤會造成可量度的銷售損失(單一來源,需謹慎)。
- **與我們的關係**:《金毛騎士》的美術是由 AI 寫的程式逐點畫出、音樂由 AI 寫的程式生成。這是否屬於須申報的「生成式 AI 內容」有灰色地帶;**建議如實申報**,把它當作要管理的風險,而不是隱瞞。

---

## 6. 案例研究

### 6.1 Slotbound(2026 年 11 月,最直接的參考)

| 項目 | 內容 |
| --- | --- |
| 開發者 | Optima Arch,韓國,一人開發;自稱不是程式設計師,程式 100% 由 AI 生成 |
| 玩法 | 轉 3×3 老虎機召喚士兵,吞併較弱的士兵變強,抵擋一波波敵人與頭目(自動戰鬥 + 塔防 + 輪迴) |
| 時間線 | 夏天預告片爆紅 → 7 月推出免費試玩版、在 Steam 新品節受注意 → 上市前願望清單超過 10 萬 → 11 月 12 日上市 |
| 價格 | 9.99 美元 |
| 成績 | 11 月 17 日同時在線最高約 29,500 人(SteamDB);約 900 多則評論,約 76% 至 79% 好評(「大多好評」;早期曾是「極度好評」) |
| 玩家稱讚 | 概念新奇、老虎機的刺激感 |
| 玩家批評 | 太靠運氣(強弱主要看抽到甚麼);平衡差(金幣堆滿卻抽不到有用的士兵);前期要刷很久、升級慢;戰鬥最快兩倍速,早期很拖;老虎機有時反而打斷節奏 |

**為甚麼成功**

1. **一句話就懂的鉤子**:「拉老虎機召喚軍隊」;搭上「賭博 + 輪迴」類型的熱潮,但組合是新的。
2. **15 秒就能傳播**:轉軸、連線、士兵湧出的畫面一看就懂,所以預告片爆紅。
3. **上市前累積願望清單**:上市當天就有大量願望清單,Steam 的推薦系統會把它推上熱門。
4. **低價、一局很短**:容易入手,靠隨機性重玩。
5. **「AI 做的遊戲」本身成為話題**:爭議也帶來曝光(部分媒體稱它為「AI 垃圾」但承認它好玩)。

**它的限制**:評價停在「大多好評」,說明鉤子帶來人流,但深度與平衡不足時評價會打折。

### 6.2 同一股潮流的一人或小團隊作品

(Balatro 與 Vampire Survivors 兩行來自撰寫者的既有知識,這次沒有附來源。)

| 遊戲 | 要點 |
| --- | --- |
| Luck Be a Landlord | 老虎機 + 構築的早期作品,啟發了後來的潮流 |
| Balatro(2024) | 一人開發,撲克 + 構築;銷量數以百萬計,帶起「賭博輪迴」類型 |
| Slots & Daggers | 一人開發,龍與地下城風格的老虎機;上市 10 天賣出 10 萬套 |
| CloverPit | 黑暗風格的老虎機輪迴,上市即獲好評 |
| Vampire Survivors(2022) | 一人開發、低價,「自動攻擊打一大群敵人」類型的始祖;後來成為現象級作品 |

### 6.3 共同點

1. **一句話就懂的新奇玩法**(熟悉的元素 + 新組合),比畫面精美重要。
2. **短片友善**:看 15 秒就懂、就想玩。
3. **低價**(約 5 至 10 美元)、一局短、可以一直重玩。
4. **上市前先有試玩版與願望清單**(新品節是關鍵)。
5. **一人或極小團隊**:能快速根據玩家意見調整。

---

## 7. 《金毛騎士》與 Slotbound 的比較

| | Slotbound | 金毛騎士 |
| --- | --- | --- |
| 開發方式 | 不會寫程式 + AI | 相同 |
| 吸引點 | **玩法**新奇,一句話就懂 | **題材**可愛(狗狗 + 亞瑟王)、故事完整 |
| 勝負靠甚麼 | 主要靠運氣 | 主要靠技巧(閃避預警)+ 構築 |
| 平台 | Steam 原生(橫向、滑鼠) | 手機直向、觸控 |
| 內容 | 以重玩為主 | 六章故事 + 無盡試煉 |
| 語言 | 多語言(含英文) | 只有繁體中文 |
| 宣傳 | 預告片、試玩版、新品節,數個月 | 尚未開始 |

**最關鍵的差距**:在 Steam,「玩法新奇」比「題材可愛」更容易傳播。我們的深度比較好,但缺一個讓人一看就想玩的獨特機制。

**可以超越的地方**:玩家批評 Slotbound 的「太靠運氣、平衡差、太被動」正是我們的強項;我們有故事、角色與頭目戲劇性,這在同類遊戲中少見。

---

## 8. 提議中的玩法鉤子(概念,尚未製作)

原則:不抄老虎機或其他遊戲的核心玩法(既不應該,也贏不了原作),要找一個只屬於我們故事的鉤子。

1. **「丟劍撿劍」(最推薦)**
   - 金毛把石中劍當樹枝丟出去,劍飛行時打中沿途的敵人;之後要跑去把劍撿回來,撿回之前不能再丟。
   - 「攻擊」與「走位」綁在一起:去撿劍的路上要閃避攻擊,丟的方向與時機就是技巧。
   - 呼應開場「把石中劍當樹枝拔出來」;15 秒短片就能看懂,也很可愛。
   - 可以延伸成構築:劍會回彈、分裂、帶火焰、同伴幫忙撿等。
   - 風險:改變核心手感,要先做原型試玩。
2. **「狗狗圓桌」組隊**
   - 圓桌有 6 個座位,收集十多位狗騎士入座;不同組合有加成(例如兩位盾騎士提高防禦、吟遊騎士 + 魔法師讓音符變成魔法彈)。
   - 補足構築深度與收集要素;可以和第 1 點並存。

---

## 9. 建議的路線

1. **定下鉤子**:先把「丟劍撿劍」做成可試玩的原型模式(不影響現有六章),找幾位真人試玩;好玩才繼續。
2. **補強深度**:把戲 12 → 40 個以上、進化 4 → 15 個以上;多隻可選的主角狗。
3. **Steam 版基本要求**:橫向畫面、鍵盤滑鼠與手把、Steam Deck 相容、英文與簡體中文、成就。
4. **盡早開 Steam 商店頁**,開始收集願望清單;做 15 至 30 秒的**真實遊戲畫面**預告片(Steam 頁面的影片應該是實際遊戲畫面)。上架費 100 美元。
5. **第一章做成免費試玩版**,參加 Steam 新品節;同時在短影片平台發片。
6. **看數字再決定**:願望清單達到數萬才上市(Slotbound 上市前超過 10 萬)。數字不理想就專注手機版。
7. **如實申報 AI 內容**,並考慮請人重畫最影響第一印象的部分(主角、商店封面、預告片關鍵畫面),降低「AI 垃圾」的觀感。

**手機版與 Steam 版的關係**:原本計劃是手機優先(App Store、Google Play)。Steam 試玩版可以作為低成本的市場測試;兩者共用大部分程式與內容。

---

## 10. 想請審閱者回答的問題

1. 「丟劍撿劍」作為鉤子夠強嗎?有沒有更好的、只屬於這個題材的玩法鉤子?
2. 應該先手機、先 Steam,還是同時做?
3. 改成橫向畫面值得嗎?還是保留直向(類似部分直向的 Steam 遊戲)?
4. 對一款可愛、適合全家的遊戲,「AI 製作」的標籤是加分(話題)還是扣分(玩家抗拒)?應該怎樣溝通?
5. 構築深度要做到甚麼程度,才能和同類遊戲競爭?
6. 定價:免費 + 付費解鎖章節,還是一次付費(例如 5 至 10 美元)?
7. 美術是否必須請專業像素美術師?只請人畫封面與主角夠不夠?
8. 還有甚麼我們沒看到的風險?

---

## 11. 資料來源

**Slotbound**
- [Gamemeca:韓國獨立新作 Slotbound](https://www.gamemeca.com/en/view.php?gid=1783506)
- [Slotbound Steam 商店頁](https://store.steampowered.com/app/4459590/Slotbound/)
- [Slotbound 試玩版](https://store.steampowered.com/app/4906570/Slotbound_Demo/)
- [SteamDB:Slotbound 在線人數](https://steamdb.info/app/4459590/charts/)
- [SteamDB:Slotbound 試玩版在線人數](https://steamdb.info/app/4906570/charts/)
- [ixbt.games:AI 製作的 Slotbound 吸引數千玩家](https://ixbt.games/en/news/2026/11/14/v-stean-vysel-pravilnyi-neiroslop-azartnyi-rogalik-slotbound-privlek-tysiaci-igrokov-i-polucil-ocen-polozitelnye-otzyvy.amp.html)
- [Today We Game:Slotbound 試玩版評測](https://todaywegame.gg/demos/slotbound)
- [Steam 社群:Slotbound](https://steamcommunity.com/app/4459590)
- [Slotbound Wiki(非官方):玩家反應](https://www.slotbound-wiki.wiki/en/community/slotbound-ai-reddit)

**同類爆紅作品**
- [GamesRadar:Slots & Daggers 十天賣出 10 萬套](https://www.gamesradar.com/games/roguelike/another-roguelike-success-story-has-hit-steam-d-and-d-flavored-slot-machine-slots-and-daggers-sells-100-000-copies-in-10-days-a-surreal-number-for-a-solo-dev-like-me)
- [PCGamesN:CloverPit 上市獲好評](https://www.pcgamesn.com/cloverpit/out-now)
- [維基百科:Luck Be a Landlord](https://en.wikipedia.org/wiki/Luck_Be_a_Landlord)
- [維基百科:CloverPit](https://en.wikipedia.org/wiki/CloverPit)
- [維基百科:Slots & Daggers](https://en.wikipedia.org/wiki/Slots_%26_Daggers)

**Steam 市場**
- [GamingOnLinux:2025 年 Steam 上架超過 19,000 款,近半評論少於 10 則](https://www.gamingonlinux.com/2025/12/over-19000-games-have-released-on-steam-in-2025-with-nearly-half-seeing-fewer-than-10-reviews)
- [Mein-MMO:2025 年 Steam 遊戲數量](https://mein-mmo.de/en/in-2025-more-than-19000-games-were-released-on-steam-but-almost-half-of-them-did-not-even-receive-10-reviews,1542361)
- [Niche Gamer:一半付費 Steam 遊戲收入少於 4,000 美元](https://nichegamer.com/report-half-of-paid-steam-games-earn-less-than-4000/)
- [Steam Page Analyzer:獨立遊戲收入資料](https://steampageanalyzer.com/blog/indie-game-revenue-data)
- [Recognizing Patterns:roguelite 供應過剩](https://recognizingpatterns.substack.com/p/the-roguelite-cull-hasnt-happened)
- [GamingOnLinux:Steam 簡體中文用戶大增(2025 年 2 月)](https://gamingonlinux.com/2025/03/steam-sees-a-big-rise-in-simplified-chinese-for-february-2025-bringing-linux-down-below-2p)
- [Tom's Hardware:Steam 調查受中國用戶影響](https://www.tomshardware.com/desktops/gaming-pcs/huge-os-and-ram-usage-swings-in-steam-survey-likely-to-have-been-influenced-by-china-influx)

**AI 與 Steam**
- [Tom's Hardware:2025 年五分之一 Steam 新作使用生成式 AI](https://www.tomshardware.com/video-games/pc-gaming/1-in-5-steam-games-released-in-2025-use-generative-ai-up-nearly-700-percent-year-on-year-7-818-titles-disclose-genai-asset-usage-7-percent-of-entire-steam-library)
- [PC Gamer:Steam Labs 對生成式 AI 遊戲數量的說法](https://www.pcgamer.com/software/ai/the-boffin-behind-valves-steam-labs-says-the-number-of-steam-releases-featuring-genai-in-2025-is-1-in-5-with-7-percent-of-all-games-on-there-now-incorporating-it-weve-octupled-last-years-figure)
- [VGC:Valve 大幅改寫 AI 申報規則](https://www.videogameschronicle.com/news/valve-has-significantly-rewritten-steams-rules-for-how-developers-much-disclose-ai-use)
- [GosuGamers:Steam 修訂 AI 政策](https://www.gosugamers.net/entertainment/news/77861-steam-revises-ai-policy-while-keeping-generative-content-disclosure-intact)
- [GamesRadar:申報使用生成式 AI 的 Steam 遊戲收入 6.6 億美元](https://www.gamesradar.com/games/steam-games-that-openly-use-generative-ai-earned-usd660-million-this-year-including-call-of-duty-black-ops-6-stellaris-and-more-as-studios-continue-to-rely-on-the-technology/)
- [PCGamesN:新品節前 100 名試玩版有 10% 申報 AI](https://www.pcgamesn.com/steam/next-fest-2026-generative-ai)
- [games.gg:AI 標籤對銷量的影響(單一來源)](https://games.gg/news/ai-content-labels-killing-game-sales/)
- [AI Tools Recap:2026 年 AI 遊戲整理(第三方)](https://aitoolsrecap.com/Blog/top-10-ai-games-2026)
- [AI and Games:2026 年 AI 遊戲預測](https://www.aiandgames.com/p/10-predictions-for-ai-in-games-for)
