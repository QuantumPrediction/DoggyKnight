# 啟動畫面與全域介面主題

- 提出:C 線,2026-11-15
- 狀態:已完成

## 要改甚麼

只改 `project.godot` 的四個設定(都是現成的 Godot 設定,不動任何合約):

| 設定 | 數值 | 作用 |
| --- | --- | --- |
| `application/boot_splash/image` | `"res://assets/app_icon/splash.png"` | 開機時顯示金毛的啟動畫面(720×1280,像素圖 4 倍) |
| `application/boot_splash/stretch_mode` | `4`(Cover) | 填滿各種長寬比的手機,不留邊 |
| `application/boot_splash/use_filter` | `false` | 像素圖放大時不模糊 |
| `application/boot_splash/bg_color` | `Color(0.435, 0.784, 0.941, 1)`(調色盤 sky `#6fc8f0`) | 圖片載入前一瞬間的底色,與天空同色 |
| `gui/theme/custom` | `"res://ui/theme/main_theme.tres"` | 所有介面(包括 D 線的營地與小遊戲)預設使用俐方體11號像素字與同一套按鈕外觀 |

另外,D 線的匯出設定可直接引用 C 線已放好的圖示(不需改 `project.godot`):

- Android 自適應圖示:`assets/app_icon/android_foreground.png`、`android_background.png`、`android_monochrome.png`(432×432)。
- iOS App Store 圖示:`assets/app_icon/icon_1024.png`(1024×1024,不透明、無圓角)。
- Google Play:`assets/app_icon/play_icon_512.png`、`feature_graphic_1024x500.png`。

## 為甚麼

- 不設定的話,開機會先看到 Godot 預設的灰底圖示,再跳到遊戲,手機上看起來像未完成。
- C 線的畫面已各自套用主題;但 D 線的營地等畫面若沒有指定主題,會用 Godot 預設字型(沒有像素感,而且可能缺中文字)。設成全域主題後,不必每條線各自指定。
- 替代做法:各線在自己的介面根節點設定 `theme = preload("res://ui/theme/main_theme.tres")`(C 線的畫面已這樣做)。

## 影響哪些線

- 不需要任何線改程式。D 線可以把營地介面的主題設定刪掉(可選)。

## 給擁有人的一句話說明

開遊戲時直接看到金毛的啟動畫面,而且整個遊戲的文字都是同一款可愛的像素字。

## 結果

已完成(2026-11-15,整合):四個啟動畫面設定與全域主題已寫入 `project.godot`;同時把主場景改為 `game/flow/main.tscn`。`tests/core/test_project_settings.gd` 已加入檢查。
