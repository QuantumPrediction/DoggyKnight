# Golden Knight：市場與玩法策略

更新：2026-11-19（香港）。目前基礎為三職業版本、六章 36 關及繪本美術，見 [PR #11](https://github.com/QuantumPrediction/DoggyKnight/pull/11)。

完整的程式證據、設計方案、測試門檻與平台路線，統一見 [下一輪開發方案](GOLDEN_KNIGHT_NEXT_DEVELOPMENT_ZH.md)。

## 當前決策

先修正「繼續冒險會重置等級與當局把戲」的舊合約，建立完整冒險檢查點。之後把第一章做成有重玩價值的 Demo：三職業各兩條路線、可辨認的同伴連攜、少量可選風險與不同目標的遭遇，以及清楚的首三分鐘。

三職業已有不同攻擊方式；同伴、進化與隨機無盡波次也已存在。下一步要深化這些系統的互動和選擇。不要將文件中的提案當成已完成的功能。

## 平台與商業模式提案

- 優先驗證 Windows／Steam 的完整付費遊戲與免費 Demo 路線；桌面版面、全流程手把與語言支援須專門設計。
- 保留手機直向觸控核心；App Store 路線先完成可靠中斷續玩與 iPhone 真機測試，再評估一次購買或試玩後一次解鎖。
- 上述是本專案的候選策略，不是收入、榜單或編輯推薦的保證；本次沒有開店、提交上架、購買廣告或聯絡創作者。

## 怎樣判斷值得繼續投入

以陌生目標玩家的操作理解、配搭理解、自發重玩、公平性感受及後續自主回來玩作依據；測試版本、平台和玩家起始成長分開記錄。初步 12–20 人試玩用來找問題，不用來推算整個市場。

目前沒有可靠的人類留存基準。下一輪方案中的比例是內部暫定門檻，不能當行業統一標準。先前 802 項測試與機器人通關紀錄也不代表留存或商業成功。

## 官方來源與界限

- [Brotato 官方頁](https://store.steampowered.com/app/1942280/Brotato/)：用來研究配搭選擇。
- [Deep Rock Galactic: Survivor 官方頁](https://store.steampowered.com/app/2321470/Deep_Rock_Galactic_Survivor/)：用來研究戰鬥與任務目標。
- [Valve：手機轉 Steam](https://partner.steamgames.com/doc/gettingstarted/mobile)：遊玩情境、解析度、輸入與商業模式的設計考量。
- [Steam 曝光](https://partner.steamgames.com/doc/marketing/visibility)：購買、遊玩、語言與標籤等因素；願望清單不是通用的演算法曝光門檻。
- [Steam Next Fest](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest)：每個遊戲只參加一次等現行一般資格；選場次前再核對。
- [Apple 推薦考量](https://developer.apple.com/app-store/getting-featured/)：整體玩法、藝術、控制、重玩性、效能與其他品質；提名不保證推薦。

以上是第一方文件及由此作出的設計推論，未進行代表性評論樣本分析。先前文件的程序美術描述、待新增第二／三章、未驗證故事時長，以及無來源的留存與收入概括已撤回；歷史內容仍可從 Git 查閱。
