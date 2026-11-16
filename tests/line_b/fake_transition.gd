extends CanvasLayer
## 給 B 線測試用的假轉場(方法與 ui/transition/transition.tscn 相同)。
## hang = true 時 cover() / reveal() 永遠不會完成(模擬出錯或被打斷的轉場),
## 用來證明流程不會因此卡住。記錄每次呼叫與「畫面目前是否被蓋住」。

signal _never

var hang: bool = false
var covered: bool = false
var calls: PackedStringArray = []


func cover(duration: float = 0.25) -> void:
	calls.append("cover")
	covered = true
	if hang:
		await _never
	await get_tree().create_timer(duration).timeout


func reveal(duration: float = 0.25) -> void:
	calls.append("reveal")
	if hang:
		await _never
	await get_tree().create_timer(duration).timeout
	covered = false
