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
| 佔位圖(純色方塊)與佔位 App 圖示(已全部被 C 線正式圖取代) | `assets/sprites/`、`assets/app_icon/` | 本專案以 `tools/placeholders/make_placeholders.gd` 生成 | 本專案原創 | 是 | 否 | Phase 0,2026-11-15 |
| 程式繪製的預警圈與預警線、震波圓環、黑騎士盔甲碎片與頭盔、閃白著色器 | `game/combat/`、`game/actors/enemies/` | 本專案程式碼即時繪製,沒有使用外部素材 | 本專案原創 | 是 | 否 | A 線,2026-11-15 |
| 正式像素圖:角色、特效、圖塊、背景、介面圖、把戲圖示、標題圖、App 圖示、商店宣傳圖、啟動畫面 | `assets/`(字型與音效除外) | 本專案以 `tools/pixel/build_all.py` 程式生成(`python3 tools/pixel/build_all.py`) | 本專案原創 | 是 | 否 | C 線,2026-11-15 |

## 音效

| 素材 | 用在哪裡 | 來源網址 | 授權 | 是否允許商用 | 需要在遊戲內列出 | 核對人與日期 |
| --- | --- | --- | --- | --- | --- | --- |
| 14 個 8-bit 音效(swing、hit、hurt、enemy_down、pickup、level_up、bark、boss_warning、ultimate、clear、fail、ui_tap、scroll、ink) | `assets/sfx/` | 本專案以 `tools/pixel/sfx_gen.py` 程式合成(`python3 tools/pixel/build_all.py`) | 本專案原創 | 是 | 否 | C 線,2026-11-15 |

## 建置範本與平台程式庫(D 線)

匯出時由 Godot 的匯出範本與 Android 建置範本(Gradle)放進安裝檔的程式庫。不是遊戲素材,但會隨 App 一起發布。

| 素材 | 用在哪裡 | 來源網址 | 授權 | 是否允許商用 | 需要在遊戲內列出 | 核對人與日期 |
| --- | --- | --- | --- | --- | --- | --- |
| Godot 4.7.2 匯出範本(Android、iOS) | 所有安裝檔 | https://godotengine.org | MIT(內含的第三方元件見 `Engine.get_license_info()`) | 是 | 是(與引擎相同,C10 畫面已涵蓋) | D 線,2026-11-15 |
| AndroidX(fragment、core-splashscreen、documentfile)與 Kotlin 標準程式庫 | Android AAB(Gradle 建置) | https://developer.android.com/jetpack/androidx 、https://kotlinlang.org | Apache 2.0 | 是 | 建議在製作名單加一行「本 App 使用 AndroidX 與 Kotlin(Apache License 2.0)」 | D 線,2026-11-15 |
| MoltenVK(Godot iOS 範本內附) | iOS 建置 | https://github.com/KhronosGroup/MoltenVK | Apache 2.0 | 是 | 建議同上一併列出 | D 線,2026-11-15 |

D 線的營地、小遊戲與圖示全部由程式繪製(本專案原創),沒有使用外部圖像或音效。

## v2.2(M3 打磨,C 線新增)

| 素材 | 用在哪裡 | 來源網址 | 授權 | 是否允許商用 | 需要在遊戲內列出 | 核對人與日期 |
| --- | --- | --- | --- | --- | --- | --- |
| 7 首 8-bit 背景音樂(title、field、boss、camp、victory、fail、chapter_clear),全部旋律原創 | `assets/music/` | 本專案以 `tools/pixel/music_gen.py` 程式作曲與合成(`python3 tools/pixel/build_all.py`) | 本專案原創 | 是 | 否 | C 線,2026-11-16 |
| 9 個新音效(crit、combo、boss_roar、star、whoosh、heal、pet、perfect、countdown),原有音效加厚層次 | `assets/sfx/` | 本專案以 `tools/pixel/sfx_gen.py` 程式合成 | 本專案原創 | 是 | 否 | C 線,2026-11-16 |
| 新背景(麥田、農場、烏鴉森林)與重畫的三個背景、背景動畫圖層、粒子特效圖、標題風景、雲、星星、切入畫面頭像、教學手指、狗掌印轉場 | `assets/backgrounds/`、`assets/fx/particles/`、`assets/ui/`、`ui/transition/` | 本專案以 `tools/pixel/` 程式繪製;調色盤增加 8 個氣氛色(共 40 色) | 本專案原創 | 是 | 否 | C 線,2026-11-16 |

D 線 M3(2026-11-16):營地新增的金毛像素圖(`game/camp/art/`,由 `game/camp/art/make_camp_art.py` 以程式畫出,顏色取自 C 線的調色盤)、營火、夜空、城堡剪影、螢火蟲與小遊戲的所有演出,全部是本專案原創,沒有使用外部素材。

## v2.3(故事與深化,C 線新增)

| 素材 | 用在哪裡 | 來源網址 | 授權 | 是否允許商用 | 需要在遊戲內列出 | 核對人與日期 |
| --- | --- | --- | --- | --- | --- | --- |
| 16 張對白頭像(金毛、貝德維爾、梅林、黑騎士、摩根娜剪影、稻草人隊長、烏鴉),依 `docs/STORY.md` 第 3 節原創設計(梅林是西施犬法師,沒有貓頭鷹;摩根娜只有紫色剪影;不模仿任何電影或動畫版本) | `assets/portraits/` | 本專案以 `tools/pixel/art_portraits.py` 程式繪製 | 本專案原創 | 是 | 否 | C 線,2026-11-16 |
| 8 張繪本插畫(開場、結局、第二章預告) | `assets/story/` | 本專案以 `tools/pixel/art_story.py` 程式繪製(角色用遊戲本身的像素圖) | 本專案原創 | 是 | 否 | C 線,2026-11-16 |
| 新角色與投射物(稻草人弓兵、空盔甲兵、稻草人隊長、梅林;箭、劍氣、乾草叉)、對白框與繪本框、困難標記 | `assets/sprites/`、`assets/fx/`、`assets/ui/` | 本專案以 `tools/pixel/art_cast.py`、`art_ui.py` 程式繪製 | 本專案原創 | 是 | 否 | C 線,2026-11-16 |
| 光暈精靈、前景剪影、暗角、雨幕、角色投影、閃電 | `assets/fx/lights/`、`assets/backgrounds/` | 本專案以 `tools/pixel/art_light.py` 程式繪製;投影與閃電由 `assets/backgrounds/*.gd` 即時繪製 | 本專案原創 | 是 | 否 | C 線,2026-11-16 |
| 6 個新音效(talk、page_turn、arrow_shot、husk_clank、captain_shout、magic)與故事音樂 `story`(旋律原創) | `assets/sfx/`、`assets/music/` | 本專案以 `tools/pixel/sfx_gen.py`、`music_gen.py` 程式合成 | 本專案原創 | 是 | 否 | C 線,2026-11-16 |

## v2.4(玩法深度,C 線新增)

| 素材 | 用在哪裡 | 來源網址 | 授權 | 是否允許商用 | 需要在遊戲內列出 | 核對人與日期 |
| --- | --- | --- | --- | --- | --- | --- |
| 10 個新把戲圖示(撲擊、打滾、挖寶、嗅嗅、裝死、暴衝;四個金框進化把戲)、寶箱、零食、進化卡片、梅林與摩根娜的事件卡片、金色緞帶、紫色按鈕、HUD 零食/波數/獎盃小圖示。只參考同類遊戲的玩法機制,名稱與美術全部原創 | `assets/icons/tricks/`、`assets/sprites/chest/`、`assets/fx/snack/`、`assets/ui/` | 本專案以 `tools/pixel/art_v24.py` 程式繪製 | 本專案原創 | 是 | 否 | C 線,2026-11-17 |
| 5 個新音效(chest_open、evolve、snack、revive、event) | `assets/sfx/` | 本專案以 `tools/pixel/sfx_gen.py` 程式合成 | 本專案原創 | 是 | 否 | C 線,2026-11-17 |
