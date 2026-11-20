# Golden Knight 0.5.0：軍械工坊

接續 0.4.0 的裝備、關卡檢查點及品質稽核。本輪集中改善「選得到、看得懂、鍛造有數值收益」，不把新增功能當作全遊戲已達 9/10。

## 已實作

- 新工坊插畫橫幅，裝備透明圖示；清楚標示目前職業、所在分頁與已裝備物品。內文使用無襯線字體，標題保留刻字感，取代原來的全頁文字清單。
- 兩欄收藏圖卡直接顯示金幣／寶石價格、等級、章節開放條件；配裝頁有武器、護甲、兩個寶物捷徑。
- 換裝比較使用完整配裝和永久訓練，列出實際屬性增加、降低，以及套裝得失。兩個寶物欄可分別比較；把已裝備寶物移到另一欄時，不會重複計算。
- 鍛造比較顯示下一級實際數值，包含取整後攻擊與活力、三位小數的攻擊間隔、特效變化。未裝備的物品另外顯示「假設裝在此欄」的鍛造比較。
- 購買／鍛造／確認／取消固定在內容捲動區外。餘額或材料不足、章節未開放時，不能點擊購買／鍛造；文字指出欠缺數量。
- 確認交易保存原本的物品、職業和幣別，不受其後的選擇變數影響。仍由原有交易與存檔流程負責扣款、保存及失敗回滾。

## 兩件武器的鍛造補充

先前衛兵長劍及翠雷長弓的若干等級，因攻擊／貫穿取整而沒有任何數值變化。現在這兩件武器每次升級會另減少 **1% 職業基礎攻擊間隔**，以加法計算、不複利。

| 武器 | Lv.1 | 最高級 | 攻擊間隔（零訓練、無其他裝備） |
| --- | --- | --- | --- |
| 衛兵長劍 | 無額外攻速 | Lv.5，合計 −4% 基礎間隔 | 0.500 → 0.480 秒 |
| 翠雷長弓 | 無額外攻速 | Lv.9，合計 −8% 基礎間隔 | 0.550 → 0.506 秒 |

這是小幅平衡調整，並非修正所有傷害的取整方式。攻擊傷害、貫穿里程碑、其他裝備、價格與掉落維持原有規則。攻擊計時仍受物理幀影響，因此相鄰等級不保證每次攻擊都提前一幀；觸發治療也仍可能取整。沒有宣稱每擊、每個敵人或每種構築都有同幅收益。

同一套正式數值稽核，330 個合法職業／單件裝備／等級狀態中，「相鄰升級所有屬性與特效都完全相同」由 9 個降為 0 個。這是數值覆蓋結果，不是玩家滿意度、職業平衡或留存證明。

## 實際畫面與驗證

`docs/validation/0.5.0/` 保存測試、數值稽核及 12 張真實 Linux Godot OpenGL 畫面，包含普通店、換裝預覽、鍛造、確認、史詩店、章節鎖定，以及 360×640 和 390×844 模擬瀏海版面。截圖的成熟收藏和錢包是明確配置的展示資料，並非自然養成紀錄。

另外使用全新獨立存檔，實際操作正式主場景：標題 → 工坊 → 普通店 → 買衛兵長劍 → 裝備 → 鍛造一次 → 返回。金幣由 250 → 110 → 60；長劍升至 Lv.2；下一級需要 100 金幣，畫面顯示還差 40 並停用按鈕。這是 AI 操作驗證，不是陌生真人試玩。

測試清單與結果以驗證資料夾的 README 為準。受測實作提交為 `c56e9534ebb0a753e05949297e5bac4c915418c0`；後續只整理證據及交接。

## 尚未完成

首輪收入、史詩取得節奏、同伴合作新玩法、第一章三種遭遇、六條職業構築路線、手把、完整無障礙、多語言、真人難度測試仍是後續工作。原先品質報告的分數沒有因本批工程測試而自動上調。真實付款、商店發布、PR 合併及新版 EXE 不包含在本批。

下一批應先完成第一章的一種主動同伴合作和兩個可選構築核心，並讓玩家用自然取得的裝備試玩，再調整養成收入。不要以本輪配置的高階裝備或單一機器人種子推論首輪體驗。

## 美術來源與提示詞

使用內建 GPT Image。檔案與 SHA-256 見 `assets/illustrated/equipment/ARMORY_ART_MANIFEST.json`。新圖均已接入實際遊戲；保留原裝備圖集，沒有新增外部字型。

工坊橫幅提示詞：

> Use case: illustration-story. Asset type: a new production background banner for the armory screen in Golden Knight, a cozy illustrated game about a golden retriever knight. Create a wide panoramic 3:1 composition, ideally 1536 x 512. A warm medieval royal forge at dusk, a kind stocky bulldog master smith in a leather apron at a softly glowing forge on the RIGHT THIRD, gold embossed shield and finely crafted small sword on his workbench, small golden retriever knight admiring the equipment, warm amber embers, restrained gold and deep desaturated teal palette, richly painted storybook game environment with confident shapes and hand-painted edges. LEFT HALF is a beautifully dark quiet teal stone wall with gentle warm light gradient and subtle carved paw crest, intentionally empty space for live UI heading. Upper and lower edges darken naturally for UI blending. Fine artisan detail but readable at 500 pixels wide. Charming sophisticated medieval storybook aesthetic, not flat clipart, not photorealistic, no text, no letters, no numbers, no watermark, no interface buttons, no grid or border, no blood, no injuries. The painting must be useful as a shallow horizontal game UI banner.

透明圖集提示詞（參考本專案原圖，transparent_background=true）：

> Use case: background-extraction. This is the existing Golden Knight equipment atlas and an EDIT TARGET, not a composition reference. Remove ONLY the white/off-white paper background, making it truly transparent. Preserve all eighteen objects, their exact designs, colors, outlines, size, positions and order. Keep the 6 columns x 3 rows equal-cell atlas composition and 2:1 canvas aspect ratio exactly. Each object must remain isolated in its original cell; retain the bow strings, sparkling lightning, jewelry gaps, straps, all light interior materials on the ordinary vest and weapon blades, all fine detail. Background outside objects and inside open gaps becomes transparent alpha with clean edges, not a gray checkerboard baked into the pixels. Do not add, remove, move or redesign any equipment. No text, no shadows across neighboring cells, no colored tile backgrounds.
