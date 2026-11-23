# 戰場上會出現哪一種寶箱？

![普通、精英與頭目箱並排開蓋](field-chests.gif)

左邊是行裝木箱。平蓋上繞了兩條皮帶，骨頭搭扣留給金毛打開。中間的精英箱有削角青綠外殼與銅盾扣。右邊的頭目箱有酒紅拱蓋、金冠和琥珀。上圖取自正式遊戲用的十二格插畫，循環方便看清動作。

## 動作與拾取

基準為 #26 的 `b413b36bd47e8cb614210d3d714ee5154be0d5bf`。兩版用同一測試場景和固定鏡頭，生成三個正式寶箱。第 36、62、88 幀讓騎士進入對應箱子的原有拾取距離，三幀後移開供觀察。各箱在第 21 幀落地。每一箱都只發出一次對應等級的獎勵。

| 寶箱 | 扣子剛開／半開／全開（物理幀） | 從場上移除 |
| --- | --- | ---: |
| 普通 | 36／42／48 | 78 |
| 精英 | 62／68／74 | 104 |
| 頭目 | 88／94／100 | 130 |

兩個待機幀顯示同一張合蓋畫。開蓋的每格由原有 10 fps 動畫推動。修改前後各有 414 筆位置、狀態、動畫及領獎記錄，逐位元組一致，SHA-256 `5081741ba95ed32a3734bc4efb1f2c8ce0d488681cf13c5331f1b57b7bd12c54`。[逐幀資料](pickup.tsv) · [預先登記的門檻](../../requests/20261123-INT-field-chest-art.md)

在 128×128 遊戲圖格內以 alpha ≥32/255 量度，十二張畫的邊距至少 7 px，底緣位於 y=108–109（從 0 起算）。正式繪製區為 24×24 世界單位。原圖及遊戲圖集均可重新核對。[GPT Image 母稿](source.png) · [提示及指紋](art.json) · [遊戲圖集](../../../assets/illustrated/motion/field_chests.png)

重跑時先用 `godot --headless --import` 匯入，然後設定 `CHEST_CAPTURE_DIR` 和獨立的 `XDG_DATA_HOME`，以 `godot --fixed-fps 60 --resolution 360x640 --rendering-method gl_compatibility --audio-driver Dummy res://tests/integration/field_chest_showcase.tscn` 執行。加上 `--headless` 可只取逐幀資料。目標玩家尚未參與這項辨識測試。
