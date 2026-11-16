# store/:商店素材草稿(D11)

全部是**草稿與建議答案**。M4 送審前,上架工作階段要按 `docs/STORE_RELEASE.md` 第 5 節的官方連結,
用當時的問卷與後台畫面重新核對(問卷題目每年都會改)。

| 檔案 | 內容 |
| --- | --- |
| `listing_zh-Hant.md` | 商店頁面文字:名稱、簡短說明、完整說明、App Store 副標題與關鍵字 |
| `privacy_policy_zh-Hant.md` | 隱私權政策(內容:不收集任何資料)。要放在任何可公開瀏覽的網址 |
| `data_safety_answers.md` | Google Play「資料安全」表單的建議答案 |
| `app_privacy_answers.md` | Apple「App 隱私」標籤的建議答案 |
| `content_rating_answers.md` | Google Play(IARC)與 Apple 年齡分級問卷的建議答案 |
| `screenshots/capture.gd` | 自動截圖腳本,輸出商店要求的尺寸 |

這些答案**只在目前的設計下成立**:不連網、沒有廣告、沒有內購、沒有分析、沒有帳號。
加入任何一項(見 `platform/README.md`),全部都要重填。

## 自動截圖

腳本把遊戲畫面以手機實際的邏輯解析度算繪,再用「最近鄰」整數倍放大到商店要求的像素,像素不會模糊。

| 輸出資料夾 | 尺寸 | 用在哪裡 | 計算 |
| --- | --- | --- | --- |
| `googleplay_phone_1080x1920` | 1080×1920 | Google Play 手機截圖(9:16) | 180×320 × 6 |
| `appstore_6.9in_1290x2796` | 1290×2796 | App Store 6.9 吋 iPhone | 184×399 × 7,四周補 1 至 2 像素 |
| `appstore_6.9in_1320x2868` | 1320×2868 | App Store 6.9 吋 iPhone(較新機型) | 188×409 × 7,四周補 2 至 3 像素 |

目前會截取:`01_camp.png`(第二次營地:鬥牛犬在火旁、正在摸金毛的頭、流星)、
`02_scroll_minigame.png`(小遊戲「完美!」停住的一刻)、`03_scroll_results.png`(三顆星的評價畫面)。
整合完成後,可以加上整個遊戲的場景(例如標題與戰鬥);建議的截圖順序與說明文字見 `listing_zh-Hant.md`。
2026-11-16 在雲端重新執行過一次 ✅(Godot 4.7.2,三種尺寸各三張)。

指令(在專案根目錄;輸出資料夾請放在 repo 以外):

```bash
# 雲端 / Linux 伺服器(沒有螢幕,用 Xvfb)——已驗證 ✅
xvfb-run -a godot --path . --rendering-driver opengl3 --audio-driver Dummy \
  --script res://store/screenshots/capture.gd -- --out=$HOME/doggyknight_store_screenshots

# 自己的電腦(Windows / macOS / Linux 桌面)——未驗證 ⚠️
godot --path . --script res://store/screenshots/capture.gd -- --out=/某個資料夾

# 另外截取其他場景(例如整合後的主場景),等 120 格再截
... --script res://store/screenshots/capture.gd -- --out=... --scene=res://game/flow/main.tscn --frames=120
```

注意:

- 不可以用 `--headless`(沒有算繪就截不到圖,腳本會直接結束並說明)。
- 商店截圖不可以出現「測試版」「Demo」「Beta」等字樣(Apple 不接受),也不要出現 D 線測試選單。
- Google Play 另外需要 512×512 圖示與 1024×500 宣傳圖,由 C 線(C13)製作。
