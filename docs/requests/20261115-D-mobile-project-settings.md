# 手機專案設定:iOS 靜音鍵、狀態列、60 FPS

- 提出:D 線,2026-11-15
- 狀態:已完成

## 要改甚麼

在 `project.godot` 加入(或明確寫出)以下設定。設定名稱已用 Godot 4.7.2 實際核對
(以 `--script` 列出 `ProjectSettings.get_property_list()` 中符合的名稱與預設值)。

| 設定名稱 | 建議值 | 目前(預設) | 作用 |
| --- | --- | --- | --- |
| `application/run/max_fps` | `60` | `0`(不限) | 高更新率(90/120 Hz)手機也鎖 60 FPS,省電、手感一致(DEV_PLAN 第 2 節) |
| `display/window/ios/allow_high_refresh_rate` | `false` | `true` | iPhone ProMotion(120 Hz)不提高更新率,配合 60 FPS |
| `display/window/vsync/vsync_mode` | `1`(Enabled) | `1` | 明確寫出,避免畫面撕裂 |
| `audio/general/ios/session_category` | `0`(Ambient) | `0` | **iPhone 的靜音鍵打開時遊戲不發聲**;同時不會打斷玩家自己在聽的音樂 |
| `audio/general/ios/mix_with_others` | `false` | `false` | Ambient 本身已經會與其他聲音混合,保持預設 |
| `display/window/ios/hide_status_bar` | `true` | `true` | iOS 隱藏狀態列(DEV_PLAN 11 D5) |
| `display/window/ios/hide_home_indicator` | `true` | `true` | 底部橫條在玩家沒有觸碰時自動淡出 |
| `display/window/ios/suppress_ui_gesture` | `true` | `true` | 從螢幕底邊往上滑時,第一下只會叫出橫條,不會直接回到主畫面(小遊戲要向下滑,這可以減少誤觸) |

說明:

- iOS 的四個設定與音訊類別目前已經是建議值(Godot 預設),但寫進 `project.godot` 並加進
  `tests/core/test_project_settings.gd`,日後才不會被無意間改掉。
- 「Ambient」與「Solo Ambient」都會遵守靜音鍵;Ambient 不會停掉玩家的音樂,原型沒有背景音樂,選 Ambient 較好。
  若日後加入背景音樂並希望蓋過其他 App 的音樂,可改為 `5`(Solo Ambient),兩者都遵守靜音鍵。
- **Android 的沉浸模式(隱藏狀態列與導覽列)不是專案設定**,是匯出設定 `screen/immersive_mode`,
  已在 D 線的 `export_presets.cfg` 開啟,不需要整合工作階段處理。
- `display/window/frame_pacing/android/enable_frame_pacing`(Swappy)只對 Vulkan 有效;本專案用 Compatibility(OpenGL),維持預設即可。

建議加到 `tests/core/test_project_settings.gd` 的檢查:

```gdscript
func test_mobile_power_and_ios_settings() -> void:
	assert_eq(_setting("application/run/max_fps"), 60, "高更新率手機鎖 60 FPS")
	assert_eq(_setting("display/window/ios/allow_high_refresh_rate"), false)
	assert_eq(_setting("audio/general/ios/session_category"), 0, "Ambient:靜音鍵打開時不發聲")
	assert_eq(_setting("display/window/ios/hide_status_bar"), true)
	assert_eq(_setting("display/window/ios/hide_home_indicator"), true)
	assert_eq(_setting("display/window/ios/suppress_ui_gesture"), true)
```

## 為甚麼

- DEV_PLAN 第 2 節:「高更新率手機也鎖 60,以省電和保持手感一致」。目前 `max_fps` 是 0,
  120 Hz 的手機會跑 120 FPS,耗電加倍,而且以 `delta` 計算的手感可能與 60 FPS 不同。
- DEV_PLAN 11 D5:「iOS 隱藏狀態列、靜音鍵開著時不發聲」。
- 沒有不改 `project.godot` 的替代做法:`Engine.max_fps` 雖然可以在程式中設定,但應該集中在專案設定,不應散落在某一線的程式裡。

## 影響哪些線

- 只改 `project.godot` 與 `tests/core/test_project_settings.gd`,四條線都不用改程式。
- 鎖 60 FPS 之後,A 線的手感調整以 60 FPS 為準(桌面測試一般本來就是 60)。

## 給擁有人的一句話說明

手機較省電、iPhone 開靜音時不會突然發出聲音、畫面上方不會有時間與電量的狀態列。

## 結果

已完成(2026-11-15,整合):全部設定已寫入 `project.godot`,`tests/core/test_project_settings.gd` 已加入檢查。
