# 0.9.1 遊戲驗證截圖

全部十張原圖已按擁有人於 2026-11-20 的明確授權公開至 PR #14，並隨該 PR 合併至預設分支。
這些是正式 Godot 引擎中擺位／凍結角色的畫面檢查，並非真人通關錄影。
圖片沒有重新生成、裁切或重新編碼；雜湊及檔案大小列於 [publication.json](../publication.json)。

| 畫面／尺寸 | 最終畫面 | 修正前畫面（iteration2） |
| --- | --- | --- |
| 弓手追蹤預警，540×960 | [查看](archer_tracking.png) | [查看](iteration2/archer_tracking.png) |
| 鎖定預警／專注就緒，540×960 | [查看](archer_locked_focus_ready.png) | [查看](iteration2/archer_locked_focus_ready.png) |
| 法師翻滾冷卻，540×960 | [查看](mage_roll_cooldown.png) | [查看](iteration2/mage_roll_cooldown.png) |
| 騎士小螢幕，360×640 | [查看](knight_small.png) | [查看](iteration2/knight_small.png) |
| 弓手模擬瀏海，390×844 | [查看](archer_notched.png) | [查看](iteration2/archer_notched.png) |

修正前畫面保留了文字／進度條重疊及擺位時產生的受擊閃白問題。最終版加高面板、分開文字與進度條，並直接設定展示專注值，避免擺位時真正射擊。

最終安全區與文字檢查見 [checks.json](checks.json)；完整測試、原始失敗及限制見 [驗證紀錄](../README.md)。
