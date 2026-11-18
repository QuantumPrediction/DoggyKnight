# 美術規格表(給美術師或 AI 繪圖用)

更新:2026-11-18(v2.7 六章之後)。由整合工作階段從專案檔案自動整理。**換圖規則**:檔案放回同一路徑、同一尺寸、同一動畫格數與次序;程式不用改。全部只畫朝右(朝左由程式鏡像)。像素圖不可有半透明模糊邊(粒子特效除外);每格角色的腳底位置要一致。

## 風格

- 可愛、明亮、輪廓清楚的中世紀童話像素風;狗狗亞瑟王世界(見 `docs/STORY.md` 的角色設定)。
- 色板:`assets/palette.png`(40 色)。新美術可以擴充色板,但全遊戲要一致。
- 狗不會受傷:受擊表情是可愛的(星星、皺眉),沒有血。
- 原創設計:不要模仿任何電影、動畫或其他遊戲的角色與畫風。

## 角色與特效(SpriteFrames 圖表)

| 檔案 | 每格尺寸 | 動畫(名稱與格數) |
| --- | --- | --- |
| `assets/fx/arrow/arrow.png` | 16x16 | default 2格(循環) |
| `assets/fx/bubble/bubble.png` | 12x12 | default 4格(循環) |
| `assets/fx/dizzy_stars/dizzy_stars.png` | 20x12 | default 6格(循環) |
| `assets/fx/dust/dust.png` | 12x12 | default 4格 |
| `assets/fx/exp_orb/exp_orb.png` | 12x12 | default 6格(循環) |
| `assets/fx/fireball/fireball.png` | 16x16 | default 4格(循環) |
| `assets/fx/fox_flame/fox_flame.png` | 16x16 | default 4格(循環) |
| `assets/fx/hit_spark/hit_spark.png` | 20x20 | default 4格 |
| `assets/fx/ice_shard/ice_shard.png` | 16x16 | default 4格(循環) |
| `assets/fx/ink_blob/ink_blob.png` | 16x16 | default 4格(循環) |
| `assets/fx/magic_orb/magic_orb.png` | 12x12 | default 4格(循環) |
| `assets/fx/moon_orb/moon_orb.png` | 16x16 | default 4格(循環) |
| `assets/fx/music_note/music_note.png` | 12x12 | default 4格(循環) |
| `assets/fx/pitchfork/pitchfork.png` | 16x16 | default 4格(循環) |
| `assets/fx/shadow_slash/shadow_slash.png` | 24x24 | default 4格(循環) |
| `assets/fx/slash/slash.png` | 32x32 | default 4格 |
| `assets/fx/snack/snack.png` | 8x8 | default 2格(循環) |
| `assets/fx/snowball/snowball.png` | 12x12 | default 4格(循環) |
| `assets/fx/sword_wave/sword_wave.png` | 24x24 | default 3格(循環) |
| `assets/fx/tentacle/tentacle.png` | 24x56 | default 4格(循環) |
| `assets/fx/thorn/thorn.png` | 16x16 | default 2格(循環) |
| `assets/fx/ultimate_slash/ultimate_slash.png` | 64x64 | default 6格 |
| `assets/sprites/armored_husk/armored_husk.png` | 32x32 | idle 4格(循環)、run 6格(循環)、attack 3格、hurt 1格、dash 2格(循環)、down 1格 |
| `assets/sprites/black_knight/black_knight.png` | 64x64 | idle 4格(循環)、run 6格(循環)、attack 4格、hurt 2格、charge 3格(循環)、slam 4格、down 2格 |
| `assets/sprites/bulldog/bulldog.png` | 32x32 | idle 4格(循環)、run 6格(循環)、attack 4格、hurt 2格、guard 2格(循環)、victory 4格(循環) |
| `assets/sprites/chest/chest.png` | 24x24 | idle 2格(循環)、open 3格 |
| `assets/sprites/crab/crab.png` | 24x24 | idle 4格(循環)、run 4格(循環)、attack 4格、hurt 2格、guard 2格(循環) |
| `assets/sprites/crow/crow.png` | 24x24 | idle 4格(循環)、run 6格(循環)、attack 4格、hurt 2格 |
| `assets/sprites/foxfire/foxfire.png` | 16x16 | idle 4格(循環)、run 4格(循環)、attack 3格、hurt 2格、burst 4格 |
| `assets/sprites/gargoyle/gargoyle.png` | 32x32 | idle 4格(循環)、run 4格(循環)、attack 4格、hurt 2格、swoop 2格(循環)、stone 2格(循環) |
| `assets/sprites/gawain/gawain.png` | 40x40 | idle 4格(循環)、run 6格(循環)、attack 4格、hurt 2格、slam 3格 |
| `assets/sprites/goldie/goldie.png` | 32x32 | idle 6格(循環)、run 6格(循環)、attack 4格、hurt 2格、sleep 2格(循環)、victory 4格(循環) |
| `assets/sprites/green_knight/green_knight.png` | 64x64 | idle 4格(循環)、run 6格(循環)、attack 4格、hurt 2格、whip 4格、summon 3格、hat_off 4格、down 2格、idle_bare 4格(循環)、run_bare 6格(循環)、attack_bare 4格、hurt_bare 2格、whip_bare 4格、summon_bare 3格 |
| `assets/sprites/jellyfish/jellyfish.png` | 24x24 | idle 4格(循環)、run 4格(循環)、attack 3格、hurt 2格、zap 3格 |
| `assets/sprites/kraken/kraken.png` | 64x64 | idle 4格(循環)、run 6格(循環)、attack 4格、hurt 2格、slam 3格、ink 3格、summon 3格、down 2格 |
| `assets/sprites/lady_lake/lady_lake.png` | 32x32 | idle 4格(循環)、run 6格(循環)、cast 3格 |
| `assets/sprites/lancelot/lancelot.png` | 32x32 | idle 4格(循環)、run 6格(循環)、attack 4格、hurt 2格、dash 2格(循環) |
| `assets/sprites/lantern_wisp/lantern_wisp.png` | 16x16 | idle 4格(循環)、run 4格(循環)、attack 3格、hurt 2格、heal 3格 |
| `assets/sprites/merlin/merlin.png` | 32x32 | idle 4格(循環)、run 6格(循環)、cast 3格 |
| `assets/sprites/mordred/mordred.png` | 48x48 | idle 4格(循環)、run 6格(循環)、attack 4格、hurt 2格、dash 2格(循環)、slash 4格、guard 2格(循環)、summon 3格、down 2格 |
| `assets/sprites/morgana/morgana.png` | 64x64 | idle 4格(循環)、run 6格(循環)、attack 4格、hurt 2格、cast 4格、teleport 4格、down 2格 |
| `assets/sprites/red_dragon/red_dragon.png` | 64x64 | idle 4格(循環)、run 6格(循環)、attack 4格、hurt 2格、breath 4格、roar 3格、sulk 2格(循環) |
| `assets/sprites/salamander/salamander.png` | 24x24 | idle 4格(循環)、run 4格(循環)、attack 4格、hurt 2格、dash 2格(循環) |
| `assets/sprites/scarecrow/scarecrow.png` | 32x32 | idle 4格(循環)、run 6格(循環)、attack 4格、hurt 2格 |
| `assets/sprites/scarecrow_archer/scarecrow_archer.png` | 32x32 | idle 4格(循環)、run 6格(循環)、attack 3格、hurt 1格、aim 2格(循環) |
| `assets/sprites/scarecrow_captain/scarecrow_captain.png` | 48x48 | idle 4格(循環)、run 6格(循環)、attack 3格、hurt 1格、throw 3格、rally 2格(循環)、down 1格 |
| `assets/sprites/shadow_knight/shadow_knight.png` | 32x32 | idle 4格(循環)、run 6格(循環)、attack 4格、hurt 2格、guard 2格(循環)、down 4格 |
| `assets/sprites/shadow_wolf/shadow_wolf.png` | 32x32 | idle 4格(循環)、run 6格(循環)、attack 4格、hurt 2格、dash 2格(循環)、down 4格 |
| `assets/sprites/snowman/snowman.png` | 24x24 | idle 4格(循環)、run 4格(循環)、attack 4格、hurt 2格、throw 3格 |
| `assets/sprites/spellbook/spellbook.png` | 24x24 | idle 4格(循環)、run 4格(循環)、attack 3格、hurt 2格、cast 3格 |
| `assets/sprites/tristan/tristan.png` | 32x32 | idle 4格(循環)、run 6格(循環)、attack 4格、hurt 2格、play 3格(循環) |
| `assets/sprites/white_dragon/white_dragon.png` | 64x64 | idle 4格(循環)、run 6格(循環)、attack 4格、hurt 2格、breath 4格、roar 3格、sulk 2格(循環) |

圖表排列:每一列是一個動畫(依上表次序),每一欄是一格;對應的 `_frames.tres` 由 `tools/pixel/` 重新產生,或請整合工作階段依新圖表更新。

## 頭像(對白)

| 檔案 | 尺寸 |
| --- | --- |
| `assets/portraits/black_knight/normal.png` | 48x48 |
| `assets/portraits/bulldog/happy.png` | 48x48 |
| `assets/portraits/bulldog/normal.png` | 48x48 |
| `assets/portraits/bulldog/serious.png` | 48x48 |
| `assets/portraits/crow/normal.png` | 48x48 |
| `assets/portraits/gargoyle/normal.png` | 48x48 |
| `assets/portraits/gawain/happy.png` | 48x48 |
| `assets/portraits/gawain/normal.png` | 48x48 |
| `assets/portraits/gawain/serious.png` | 48x48 |
| `assets/portraits/goldie/happy.png` | 48x48 |
| `assets/portraits/goldie/normal.png` | 48x48 |
| `assets/portraits/goldie/serious.png` | 48x48 |
| `assets/portraits/goldie/surprised.png` | 48x48 |
| `assets/portraits/goldie/tired.png` | 48x48 |
| `assets/portraits/green_knight/normal.png` | 48x48 |
| `assets/portraits/kraken/normal.png` | 48x48 |
| `assets/portraits/lady_lake/normal.png` | 48x48 |
| `assets/portraits/lady_lake/smile.png` | 48x48 |
| `assets/portraits/lady_lake/worried.png` | 48x48 |
| `assets/portraits/lancelot/happy.png` | 48x48 |
| `assets/portraits/lancelot/normal.png` | 48x48 |
| `assets/portraits/lancelot/serious.png` | 48x48 |
| `assets/portraits/lancelot/surprised.png` | 48x48 |
| `assets/portraits/merlin/normal.png` | 48x48 |
| `assets/portraits/merlin/proud.png` | 48x48 |
| `assets/portraits/merlin/surprised.png` | 48x48 |
| `assets/portraits/merlin/worried.png` | 48x48 |
| `assets/portraits/mordred/angry.png` | 48x48 |
| `assets/portraits/mordred/normal.png` | 48x48 |
| `assets/portraits/mordred/sad.png` | 48x48 |
| `assets/portraits/mordred/smirk.png` | 48x48 |
| `assets/portraits/morgana/smirk.png` | 48x48 |
| `assets/portraits/morgana_true/angry.png` | 48x48 |
| `assets/portraits/morgana_true/normal.png` | 48x48 |
| `assets/portraits/morgana_true/sad.png` | 48x48 |
| `assets/portraits/morgana_true/smile.png` | 48x48 |
| `assets/portraits/red_dragon/normal.png` | 48x48 |
| `assets/portraits/scarecrow_captain/angry.png` | 48x48 |
| `assets/portraits/tristan/happy.png` | 48x48 |
| `assets/portraits/tristan/normal.png` | 48x48 |
| `assets/portraits/tristan/serious.png` | 48x48 |
| `assets/portraits/tristan/surprised.png` | 48x48 |
| `assets/portraits/white_dragon/normal.png` | 48x48 |

## 繪本插畫

| 檔案 | 尺寸 |
| --- | --- |
| `assets/story/c2_ending_1.png` | 160x120 |
| `assets/story/c2_ending_2.png` | 160x120 |
| `assets/story/c2_ending_3.png` | 160x120 |
| `assets/story/c2_prologue_1.png` | 160x120 |
| `assets/story/c2_prologue_2.png` | 160x120 |
| `assets/story/c3_ending_1.png` | 160x120 |
| `assets/story/c3_ending_2.png` | 160x120 |
| `assets/story/c3_ending_3.png` | 160x120 |
| `assets/story/c3_prologue_1.png` | 160x120 |
| `assets/story/c3_prologue_2.png` | 160x120 |
| `assets/story/c4_ending_1.png` | 160x120 |
| `assets/story/c4_ending_2.png` | 160x120 |
| `assets/story/c4_ending_3.png` | 160x120 |
| `assets/story/c4_prologue_1.png` | 160x120 |
| `assets/story/c4_prologue_2.png` | 160x120 |
| `assets/story/c5_ending_1.png` | 160x120 |
| `assets/story/c5_ending_2.png` | 160x120 |
| `assets/story/c5_ending_3.png` | 160x120 |
| `assets/story/c5_prologue_1.png` | 160x120 |
| `assets/story/c5_prologue_2.png` | 160x120 |
| `assets/story/c6_ending_1.png` | 160x120 |
| `assets/story/c6_ending_2.png` | 160x120 |
| `assets/story/c6_ending_3.png` | 160x120 |
| `assets/story/c6_ending_4.png` | 160x120 |
| `assets/story/c6_prologue_1.png` | 160x120 |
| `assets/story/c6_prologue_2.png` | 160x120 |
| `assets/story/ending_1.png` | 160x120 |
| `assets/story/ending_2.png` | 160x120 |
| `assets/story/ending_3.png` | 160x120 |
| `assets/story/prologue_1.png` | 160x120 |
| `assets/story/prologue_2.png` | 160x120 |
| `assets/story/prologue_3.png` | 160x120 |
| `assets/story/prologue_4.png` | 160x120 |
| `assets/story/teaser_1.png` | 160x120 |
| `assets/story/teaser_2.png` | 160x120 |
| `assets/story/teaser_3.png` | 160x120 |
| `assets/story/teaser_4.png` | 160x120 |
| `assets/story/teaser_5.png` | 160x120 |

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
| `assets/backgrounds/avalanche_pass.png` | 304x512 |
| `assets/backgrounds/avalanche_pass_fg.png` | 304x512 |
| `assets/backgrounds/avalon_gate.png` | 304x512 |
| `assets/backgrounds/avalon_gate_fg.png` | 304x512 |
| `assets/backgrounds/avalon_hill.png` | 304x512 |
| `assets/backgrounds/avalon_hill_fg.png` | 304x512 |
| `assets/backgrounds/bridge.png` | 304x512 |
| `assets/backgrounds/bridge_fg.png` | 304x512 |
| `assets/backgrounds/camlann_field.png` | 304x512 |
| `assets/backgrounds/camlann_field_fg.png` | 304x512 |
| `assets/backgrounds/castle_courtyard.png` | 304x512 |
| `assets/backgrounds/castle_courtyard_fg.png` | 304x512 |
| `assets/backgrounds/castle_town.png` | 304x512 |
| `assets/backgrounds/castle_town_fg.png` | 304x512 |
| `assets/backgrounds/castle_wall.png` | 304x512 |
| `assets/backgrounds/castle_wall_fg.png` | 304x512 |
| `assets/backgrounds/coral_reef.png` | 304x512 |
| `assets/backgrounds/coral_reef_fg.png` | 304x512 |
| `assets/backgrounds/crow_forest.png` | 304x512 |
| `assets/backgrounds/crow_forest_fg.png` | 304x512 |
| `assets/backgrounds/crystal_cave.png` | 304x512 |
| `assets/backgrounds/crystal_cave_fg.png` | 304x512 |
| `assets/backgrounds/dragon_nest.png` | 304x512 |
| `assets/backgrounds/dragon_nest_fg.png` | 304x512 |
| `assets/backgrounds/fairy_forest.png` | 304x512 |
| `assets/backgrounds/fairy_forest_fg.png` | 304x512 |
| `assets/backgrounds/farm_fence.png` | 304x512 |
| `assets/backgrounds/farm_fence_fg.png` | 304x512 |
| `assets/backgrounds/golden_beach.png` | 304x512 |
| `assets/backgrounds/golden_beach_fg.png` | 304x512 |
| `assets/backgrounds/green_chapel.png` | 304x512 |
| `assets/backgrounds/green_chapel_fg.png` | 304x512 |
| `assets/backgrounds/hot_springs.png` | 304x512 |
| `assets/backgrounds/hot_springs_fg.png` | 304x512 |
| `assets/backgrounds/ice_cave.png` | 304x512 |
| `assets/backgrounds/ice_cave_fg.png` | 304x512 |
| `assets/backgrounds/magic_garden.png` | 304x512 |
| `assets/backgrounds/magic_garden_fg.png` | 304x512 |
| `assets/backgrounds/meadow.png` | 304x512 |
| `assets/backgrounds/meadow_fg.png` | 304x512 |
| `assets/backgrounds/misty_lake.png` | 304x512 |
| `assets/backgrounds/misty_lake_fg.png` | 304x512 |
| `assets/backgrounds/morgana_tower.png` | 304x512 |
| `assets/backgrounds/morgana_tower_fg.png` | 304x512 |
| `assets/backgrounds/occupied_town.png` | 304x512 |
| `assets/backgrounds/occupied_town_fg.png` | 304x512 |
| `assets/backgrounds/pirate_ship.png` | 304x512 |
| `assets/backgrounds/pirate_ship_fg.png` | 304x512 |
| `assets/backgrounds/royal_library.png` | 304x512 |
| `assets/backgrounds/royal_library_fg.png` | 304x512 |
| `assets/backgrounds/sea_cliffs.png` | 304x512 |
| `assets/backgrounds/sea_cliffs_fg.png` | 304x512 |
| `assets/backgrounds/shadow_camp.png` | 304x512 |
| `assets/backgrounds/shadow_camp_fg.png` | 304x512 |
| `assets/backgrounds/snowfield.png` | 304x512 |
| `assets/backgrounds/snowfield_fg.png` | 304x512 |
| `assets/backgrounds/stone_circle.png` | 304x512 |
| `assets/backgrounds/stone_circle_fg.png` | 304x512 |
| `assets/backgrounds/sunken_city.png` | 304x512 |
| `assets/backgrounds/sunken_city_fg.png` | 304x512 |
| `assets/backgrounds/sunken_palace.png` | 304x512 |
| `assets/backgrounds/sunken_palace_fg.png` | 304x512 |
| `assets/backgrounds/sword_stone.png` | 304x512 |
| `assets/backgrounds/sword_stone_fg.png` | 304x512 |
| `assets/backgrounds/throne_hall.png` | 304x512 |
| `assets/backgrounds/throne_hall_fg.png` | 304x512 |
| `assets/backgrounds/tower_top.png` | 304x512 |
| `assets/backgrounds/tower_top_fg.png` | 304x512 |
| `assets/backgrounds/volcano.png` | 304x512 |
| `assets/backgrounds/volcano_fg.png` | 304x512 |
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
