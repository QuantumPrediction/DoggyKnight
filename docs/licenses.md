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

| 素材 | 用在哪裡 | 來源網址 | 授權 | 是否允許商用 | 需要在遊戲內列出 | 核對人與日期 |
| --- | --- | --- | --- | --- | --- | --- |
| 俐方體11號(Cubic 11)1.500 版 | 全部介面文字(`assets/fonts/Cubic_11.ttf`,主題 `ui/theme/main_theme.tres`);標題字樣與商店宣傳圖上的「金毛騎士」四字也是用這個字型畫出來的 | https://github.com/ACh-K/Cubic-11(repo 提交 `4c566f7d`「Ver. 1.500」,2026-06-27;檔案 `fonts/ttf/Cubic_11.ttf`,SHA-256 `0193f5f0…dcf62`) | SIL Open Font License 1.1(授權全文在 `assets/fonts/OFL.txt`;字型衍生自 M+ BITMAP FONTS 與 JF Dot M+H 12,版權聲明一併保留) | 是(OFL 允許隨軟體販售;只是不得單獨販售字型檔,改造後不得使用「Cubic」「俐方體」這兩個保留名稱) | 是(OFL 要求隨字型附上授權全文:已放在 `assets/fonts/OFL.txt`,遊戲內「製作名單」畫面也列出全文) | C 線,2026-11-15(已讀 repo 的 OFL.txt 與 README:「任何人可以無償使用此字型,包含商用」) |

## 圖像

| 素材 | 用在哪裡 | 來源網址 | 授權 | 是否允許商用 | 需要在遊戲內列出 | 核對人與日期 |
| --- | --- | --- | --- | --- | --- | --- |
| 佔位圖(純色方塊)與佔位 App 圖示 | `assets/sprites/`、`assets/app_icon/` | 本專案以 `tools/placeholders/make_placeholders.gd` 生成 | 本專案原創 | 是 | 否 | Phase 0,2026-11-15 |
| 正式像素圖:角色、特效、圖塊、背景、介面圖、把戲圖示、標題圖、App 圖示、商店宣傳圖、啟動畫面 | `assets/`(字型與音效除外) | 本專案以 `tools/pixel/build_all.py` 程式生成(`python3 tools/pixel/build_all.py`) | 本專案原創 | 是 | 否 | C 線,2026-11-15 |

## 音效

| 素材 | 用在哪裡 | 來源網址 | 授權 | 是否允許商用 | 需要在遊戲內列出 | 核對人與日期 |
| --- | --- | --- | --- | --- | --- | --- |
| 14 個 8-bit 音效(swing、hit、hurt、enemy_down、pickup、level_up、bark、boss_warning、ultimate、clear、fail、ui_tap、scroll、ink) | `assets/sfx/` | 本專案以 `tools/pixel/sfx_gen.py` 程式合成(`python3 tools/pixel/build_all.py`) | 本專案原創 | 是 | 否 | C 線,2026-11-15 |
