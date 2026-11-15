# ScreenFit:視窗縮小時有時不會重新計算畫面大小

- 提出:D 線,2026-11-15(D5 在不同長寬比截圖時發現)
- 狀態:待決定

## 要改甚麼

`core/screen_fit.gd` 目前只在 `get_tree().root.size_changed` 時呼叫 `_refit()`。
建議另外在視窗的實體大小改變時也重算,例如在 `_process()` 比對上一次處理過的 `root.size`:

```gdscript
var _last_window_px: Vector2i = Vector2i.ZERO

func _process(_delta: float) -> void:
	var window_px := get_tree().root.size
	if window_px != _last_window_px:
		_refit()

func _refit() -> void:
	var root := get_tree().root
	var window_px := root.size
	_last_window_px = window_px
	...(其餘不變)
```

`ScreenFit` 已經是 `PROCESS_MODE_ALWAYS`,這個比對每格只花一次向量比較。

## 為甚麼

重現步驟(Godot 4.7.2,Xvfb,`tests/` 以外的探測腳本):

1. 視窗 392×852 → ScreenFit 設定畫面為 196×426(倍數 2)。
2. 把視窗縮小到 368×798。正確結果應該是 184×399(倍數 2)。
3. 實際結果:`root.size` 已是 368×798,但畫面仍是 196×426,`size_changed` **沒有發出**。
   原因:畫面大小已經被固定為 196×426,視窗縮小後 Godot 算出的可見大小沒有改變,所以不發 `size_changed`。
   之後畫面以 1 倍顯示在 368×798 的視窗中,四邊出現大片黑邊。
4. 對照:由 400×800 縮到 368×798 時,可見大小有變,`size_changed` 正常發出,結果正確。

手機上一般只在啟動時設定一次大小(`_ready()` 會直接呼叫 `_refit()`),所以多數情況沒有問題;
但 Android 的分割畫面、摺疊手機開合、桌面測試時拉小視窗,都可能遇到。

D 線的截圖腳本目前在改變視窗大小後手動呼叫 `ScreenFit._refit()` 繞過這個問題。

## 影響哪些線

只改 `core/screen_fit.gd`,四條線都不用改程式。建議在 `tests/core/test_screen.gd` 加一個測試:
把 `root.size` 由 392×852 改為 368×798,等兩格後 `SafeArea.get_screen_size()` 應為 184×399。

## 給擁有人的一句話說明

在摺疊手機或分割畫面下改變畫面大小時,遊戲畫面仍會正確填滿,不會突然出現大片黑邊。

## 結果

(由整合工作階段填寫)
