# 授權記錄

遊戲中用到的每一個外部素材(引擎、字型、圖、音效、程式碼)都要記錄在這裡。任何線都可以新增條目,只加不刪。商店審查與遊戲內的「製作名單與授權」畫面(C10)都以這份為準。

新增條目的格式:

| 素材 | 用在哪裡 | 來源網址 | 授權 | 是否允許商用 | 需要在遊戲內列出 | 核對人與日期 |
| --- | --- | --- | --- | --- | --- | --- |

## 引擎

| 素材 | 用在哪裡 | 來源網址 | 授權 | 是否允許商用 | 需要在遊戲內列出 | 核對人與日期 |
| --- | --- | --- | --- | --- | --- | --- |
| Godot Engine 4.7.2 | 整個遊戲 | https://godotengine.org | MIT | 是 | 是 | Phase 0,2026-11-15 |

Godot 本身與它內含的第三方元件(例如 FreeType 等)都要求在遊戲內列出授權聲明。C10 的「製作名單與授權」畫面可以直接用引擎提供的文字,不必手抄:

- `Engine.get_license_text()`:Godot 本身的授權全文(見下方)。
- `Engine.get_copyright_info()`:Godot 各部分的版權資訊。
- `Engine.get_license_info()`:各第三方元件的授權全文。

說明:https://docs.godotengine.org/en/stable/about/complying_with_licenses.html

Godot 授權全文:

```
Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md).
Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## 字型

(C11 選定後記錄。)

## 圖像

| 素材 | 用在哪裡 | 來源網址 | 授權 | 是否允許商用 | 需要在遊戲內列出 | 核對人與日期 |
| --- | --- | --- | --- | --- | --- | --- |
| 佔位圖(純色方塊)與佔位 App 圖示 | `assets/sprites/`、`assets/app_icon/` | 本專案以 `tools/placeholders/make_placeholders.gd` 生成 | 本專案原創 | 是 | 否 | Phase 0,2026-11-15 |
| 程式繪製的預警圈與預警線、震波圓環、黑騎士盔甲碎片與頭盔、閃白著色器 | `game/combat/`、`game/actors/enemies/` | 本專案程式碼即時繪製,沒有使用外部素材 | 本專案原創 | 是 | 否 | A 線,2026-11-15 |

## 音效

(C12 記錄。)

## 建置範本與平台程式庫(D 線)

匯出時由 Godot 的匯出範本與 Android 建置範本(Gradle)放進安裝檔的程式庫。不是遊戲素材,但會隨 App 一起發布。

| 素材 | 用在哪裡 | 來源網址 | 授權 | 是否允許商用 | 需要在遊戲內列出 | 核對人與日期 |
| --- | --- | --- | --- | --- | --- | --- |
| Godot 4.7.2 匯出範本(Android、iOS) | 所有安裝檔 | https://godotengine.org | MIT(內含的第三方元件見 `Engine.get_license_info()`) | 是 | 是(與引擎相同,C10 畫面已涵蓋) | D 線,2026-11-15 |
| AndroidX(fragment、core-splashscreen、documentfile)與 Kotlin 標準程式庫 | Android AAB(Gradle 建置) | https://developer.android.com/jetpack/androidx 、https://kotlinlang.org | Apache 2.0 | 是 | 建議在製作名單加一行「本 App 使用 AndroidX 與 Kotlin(Apache License 2.0)」 | D 線,2026-11-15 |
| MoltenVK(Godot iOS 範本內附) | iOS 建置 | https://github.com/KhronosGroup/MoltenVK | Apache 2.0 | 是 | 建議同上一併列出 | D 線,2026-11-15 |

D 線的營地、小遊戲與圖示全部由程式繪製(本專案原創),沒有使用外部圖像或音效。
