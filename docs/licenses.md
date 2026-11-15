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

## 音效

(C12 記錄。)
