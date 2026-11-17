# 美術規格表(給美術師或 AI 繪圖用)

更新:2026-11-17。由整合工作階段從專案檔案自動整理。**換圖規則**:檔案放回同一路徑、同一尺寸、同一動畫格數與次序;程式不用改。全部只畫朝右(朝左由程式鏡像)。像素圖不可有半透明模糊邊(粒子特效除外);每格角色的腳底位置要一致。

## 風格

- 可愛、明亮、輪廓清楚的中世紀童話像素風;狗狗亞瑟王世界(見 `docs/STORY.md` 的角色設定)。
- 色板:`assets/palette.png`(40 色)。新美術可以擴充色板,但全遊戲要一致。
- 狗不會受傷:受擊表情是可愛的(星星、皺眉),沒有血。
- 原創設計:不要模仿任何電影、動畫或其他遊戲的角色與畫風。

## 角色與特效(SpriteFrames 圖表)

| 檔案 | 每格尺寸 | 動畫(名稱與格數) |
| --- | --- | --- |
| `assets/fx/arrow/arrow.png` | 16x16 | default 2格(循環) |
| `assets/fx/dizzy_stars/dizzy_stars.png` | 16x10 | default 6格(循環) |
| `assets/fx/dust/dust.png` | 8x8 | default 4格 |
| `assets/fx/exp_orb/exp_orb.png` | 12x12 | default 6格(循環) |
| `assets/fx/hit_spark/hit_spark.png` | 16x16 | default 4格 |
| `assets/fx/pitchfork/pitchfork.png` | 16x16 | default 4格(循環) |
| `assets/fx/slash/slash.png` | 32x32 | default 4格 |
| `assets/fx/snack/snack.png` | 8x8 | default 2格(循環) |
| `assets/fx/sword_wave/sword_wave.png` | 24x24 | default 3格(循環) |
| `assets/fx/ultimate_slash/ultimate_slash.png` | 64x64 | default 6格 |
| `assets/sprites/armored_husk/armored_husk.png` | 24x24 | idle 2格(循環)、run 4格(循環)、attack 3格、hurt 1格、dash 2格(循環)、down 1格 |
| `assets/sprites/black_knight/black_knight.png` | 48x48 | idle 4格(循環)、run 6格(循環)、attack 4格、hurt 2格、charge 3格(循環)、slam 4格、down 2格 |
| `assets/sprites/bulldog/bulldog.png` | 24x24 | idle 4格(循環)、run 6格(循環)、attack 4格、hurt 2格、guard 2格(循環)、victory 4格(循環) |
| `assets/sprites/chest/chest.png` | 24x24 | idle 2格(循環)、open 3格 |
| `assets/sprites/crow/crow.png` | 16x16 | idle 4格(循環)、run 6格(循環)、attack 4格、hurt 2格 |
| `assets/sprites/goldie/goldie.png` | 24x24 | idle 6格(循環)、run 6格(循環)、attack 4格、hurt 2格、sleep 2格(循環)、victory 4格(循環) |
| `assets/sprites/merlin/merlin.png` | 24x24 | idle 2格(循環)、run 4格(循環)、cast 3格 |
| `assets/sprites/scarecrow/scarecrow.png` | 24x24 | idle 4格(循環)、run 6格(循環)、attack 4格、hurt 2格 |
| `assets/sprites/scarecrow_archer/scarecrow_archer.png` | 24x24 | idle 2格(循環)、run 4格(循環)、attack 3格、hurt 1格、aim 2格(循環) |
| `assets/sprites/scarecrow_captain/scarecrow_captain.png` | 32x32 | idle 2格(循環)、run 4格(循環)、attack 3格、hurt 1格、throw 3格、rally 2格(循環)、down 1格 |

圖表排列:每一列是一個動畫(依上表次序),每一欄是一格;對應的 `_frames.tres` 由 `tools/pixel/` 重新產生,或請整合工作階段依新圖表更新。

## 頭像(對白)

| 檔案 | 尺寸 |
| --- | --- |
| `assets/portraits/black_knight/normal.png` | 48x48 |
| `assets/portraits/bulldog/happy.png` | 48x48 |
| `assets/portraits/bulldog/normal.png` | 48x48 |
| `assets/portraits/bulldog/serious.png` | 48x48 |
| `assets/portraits/crow/normal.png` | 48x48 |
| `assets/portraits/goldie/happy.png` | 48x48 |
| `assets/portraits/goldie/normal.png` | 48x48 |
| `assets/portraits/goldie/serious.png` | 48x48 |
| `assets/portraits/goldie/surprised.png` | 48x48 |
| `assets/portraits/goldie/tired.png` | 48x48 |
| `assets/portraits/merlin/normal.png` | 48x48 |
| `assets/portraits/merlin/proud.png` | 48x48 |
| `assets/portraits/merlin/surprised.png` | 48x48 |
| `assets/portraits/merlin/worried.png` | 48x48 |
| `assets/portraits/morgana/smirk.png` | 48x48 |
| `assets/portraits/scarecrow_captain/angry.png` | 48x48 |

## 繪本插畫

| 檔案 | 尺寸 |
| --- | --- |
| `assets/story/ending_1.png` | 160x120 |
| `assets/story/ending_2.png` | 160x120 |
| `assets/story/ending_3.png` | 160x120 |
| `assets/story/prologue_1.png` | 160x120 |
| `assets/story/prologue_2.png` | 160x120 |
| `assets/story/prologue_3.png` | 160x120 |
| `assets/story/prologue_4.png` | 160x120 |
| `assets/story/teaser_1.png` | 160x120 |

## 把戲圖示

| 檔案 | 尺寸 |
| --- | --- |
| `assets/icons/tricks/bark.png` | 16x16 |
| `assets/icons/tricks/dig.png` | 16x16 |
| `assets/icons/tricks/fetch.png` | 16x16 |
| `assets/icons/tricks/high_five.png` | 16x16 |
| `assets/icons/tricks/lion_roar.png` | 16x16 |
| `assets/icons/tricks/meteor_pounce.png` | 16x16 |
| `assets/icons/tricks/play_dead.png` | 16x16 |
| `assets/icons/tricks/pounce.png` | 16x16 |
| `assets/icons/tricks/roll.png` | 16x16 |
| `assets/icons/tricks/shake.png` | 16x16 |
| `assets/icons/tricks/sit.png` | 16x16 |
| `assets/icons/tricks/sniff.png` | 16x16 |
| `assets/icons/tricks/spin.png` | 16x16 |
| `assets/icons/tricks/tornado_tail.png` | 16x16 |
| `assets/icons/tricks/wag.png` | 16x16 |
| `assets/icons/tricks/zoomies.png` | 16x16 |

## App 圖示與商店圖

| 檔案 | 尺寸 |
| --- | --- |
| `assets/app_icon/android_background.png` | 432x432 |
| `assets/app_icon/android_foreground.png` | 432x432 |
| `assets/app_icon/android_monochrome.png` | 432x432 |
| `assets/app_icon/feature_graphic_1024x500.png` | 1024x500 |
| `assets/app_icon/icon.png` | 256x256 |
| `assets/app_icon/icon_1024.png` | 1024x1024 |
| `assets/app_icon/icon_master_32.png` | 32x32 |
| `assets/app_icon/play_icon_512.png` | 512x512 |
| `assets/app_icon/splash.png` | 720x1280 |

## 場地背景

| 檔案 | 尺寸 |
| --- | --- |
| `assets/backgrounds/bridge.png` | 304x512 |
| `assets/backgrounds/bridge_fg.png` | 304x512 |
| `assets/backgrounds/crow_forest.png` | 304x512 |
| `assets/backgrounds/crow_forest_fg.png` | 304x512 |
| `assets/backgrounds/farm_fence.png` | 304x512 |
| `assets/backgrounds/farm_fence_fg.png` | 304x512 |
| `assets/backgrounds/meadow.png` | 304x512 |
| `assets/backgrounds/meadow_fg.png` | 304x512 |
| `assets/backgrounds/sword_stone.png` | 304x512 |
| `assets/backgrounds/sword_stone_fg.png` | 304x512 |
| `assets/backgrounds/wheat_field.png` | 304x512 |
| `assets/backgrounds/wheat_field_fg.png` | 304x512 |

## 介面

`assets/ui/` 內的按鈕、框、圖示;尺寸以現有檔案為準。觸控目標至少 24×24 邏輯像素。

## 優先次序(先做最影響第一印象的)

1. 金毛 `goldie`(全部動畫)與標題畫面主視覺
2. App 圖示 `assets/app_icon/`
3. 黑騎士 `black_knight` 與第 1、6 關背景
4. 頭像與繪本插畫
5. 其他敵人、同伴、特效

## 授權

- 外包:合約要寫明著作權轉讓或永久商業授權。
- AI 繪圖:要確認工具的條款允許商業用途,並記錄在 `docs/licenses.md`(工具名稱、日期、條款連結)。
