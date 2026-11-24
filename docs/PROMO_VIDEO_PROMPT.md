# 《黃金騎士》15 秒宣傳短片:給 Google Gemini(Veo)的提示詞

更新:2026-11-18,整合工作階段。用途:TikTok、YouTube Shorts、Instagram Reels、小紅書的短影片與廣告。

## 使用方法

1. 在 Gemini 選「影片」生成,比例選 **9:16 直向**。
2. **附上參考圖**(遊戲真實截圖,讓畫面像我們的遊戲):戰鬥拼圖 `1_battles.png`、標題畫面、黑騎士戰鬥截圖。
3. Gemini 每次通常只生成約 8 秒的一段,而且每次生成互不記得。所以分成兩段,每段的提示詞都完整重複角色與畫風;生成後在剪接軟件接起來,共約 15 秒。
4. 影片裡**不要讓 AI 寫字**(AI 寫中文字常出錯)。標題「黃金騎士」與「立即下載」在剪接時自己加上。
5. 多生成幾次,挑最好的;角色走樣時,在提示詞最後加一句說明哪裡不對再生成。

## 第一段(0 至 8 秒):可愛的開場 + 爽快的戰鬥與進化

```text
Create an 8-second vertical 9:16 video that looks like real gameplay footage of the retro pixel-art mobile game shown in the attached screenshots. Match their art style, characters and colours as closely as possible.

STYLE: 16-bit pixel art, top-down three-quarter view like a classic handheld action RPG. Crisp chunky pixels with no blur and no smoothing, limited warm palette, coloured outlines, soft light from the top-left. Smooth sprite animation, a tiny screen shake on each hit, sparkle and confetti particles. Not 3D, not painted, not realistic.

HERO: a small cream-golden retriever knight with floppy ears and big dark eyes, standing upright, wearing a red cape and holding a small silver sword. He is always cheerful and his tail never stops wagging.

SHOT 1 (0-2s): A sunny green hilltop meadow. A glowing sword is stuck in a big grey stone. A wooden stick flies across the screen and lands next to the stone. The golden retriever runs in chasing it, skids to a stop, tilts his head at the sword, wags his tail, and pulls the sword out as if it were a stick. A burst of golden sparkles. He holds it up proudly.

SHOT 2 (2-5s): Scarecrow soldiers with brown hats and pitchforks hop in from the edges of the meadow. The dog runs between them, stops, and swings his sword automatically in fast white arcs. Each scarecrow pops into straw and confetti. Small blue glowing orbs fly from them into the dog. The hits come faster and faster.

SHOT 3 (5-8s): A golden pillar of light surrounds the dog: level up. He spins, and his wagging tail becomes a bright whirlwind circling around him that sweeps away a whole ring of scarecrows at once. He lands in a hero pose, tongue out, happy.

AUDIO: upbeat chiptune adventure music, one happy dog bark, sword swooshes, sparkle chimes. No narration, no speech.

RULES: no on-screen text, no letters, no logos, no user interface. No blood, no wounds, nobody gets hurt: defeated enemies just pop into straw and confetti. No humans. Keep the dog cute, never scary.
```

## 第二段(8 至 15 秒):頭目登場 + 必殺技 + 結尾

```text
Create an 8-second vertical 9:16 video that looks like real gameplay footage of the retro pixel-art mobile game shown in the attached screenshots. Match their art style, characters and colours as closely as possible.

STYLE: 16-bit pixel art, top-down three-quarter view like a classic handheld action RPG. Crisp chunky pixels with no blur and no smoothing, limited palette, coloured outlines, soft light from the top-left. Smooth sprite animation, screen shake on heavy impacts, sparkle and confetti particles. Not 3D, not painted, not realistic.

HERO: a small cream-golden retriever knight with floppy ears and big dark eyes, standing upright, wearing a red cape and holding a small silver sword. Cheerful, tail always wagging.
FRIENDS: a stocky white-and-brown English bulldog knight carrying a round shield with a blue cross; an old Shih Tzu wizard with long white fur like a beard, a blue starry wizard hat and a staff with a glowing star.
BOSS: a giant knight in black armour, three times the dog's height, with a purple glow in the visor and a huge sword. The armour is empty inside: it is animated by magic.

SHOT 1 (0-3s): A grey stone bridge in the rain at dusk, in front of a castle gate. The screen darkens and the ground shakes. The giant black knight drops onto the bridge with a heavy slam, purple light flaring in his visor. The golden retriever and the bulldog look up, surprised for a moment, then stand brave.

SHOT 2 (3-6s): A red warning line flashes on the ground. The black knight charges along it. The golden retriever dodges sideways at the last moment while the bulldog blocks with his shield in a shower of sparks. Then the dog's sword glows gold and he fires a huge golden beam slash across the whole screen.

SHOT 3 (6-8s): The black armour falls apart into empty pieces and a small purple wisp of magic floats away. Nobody is hurt. The golden retriever does a victory pose with his tail wagging fast; the bulldog and the wizard hop in beside him as confetti falls. Hold on this happy group. Keep the top third of the frame calm and empty (sky and castle wall) so a title can be added later.

AUDIO: the music turns dramatic with a deep boom when the boss lands, a shield clang, a big sword-beam whoosh, then a short triumphant chiptune fanfare and a happy bark. No narration, no speech.

RULES: no on-screen text, no letters, no logos, no user interface. No blood, no wounds, nobody gets hurt. No humans. Keep everything cute and family friendly.
```

## 剪接時加上

- 第 13 至 15 秒:上方加標題「黃金騎士」,下方加「立即下載」與商店圖示(用商店官方提供的徽章)。
- 想提高可信度,可以在中間插入 2 至 3 秒的**真實遊戲錄影**。

## 注意(商店與廣告規定)

- **App Store 的「App 預覽影片」必須是 App 本身的實際畫面**,不能用 AI 生成的影片;Google Play 的宣傳影片也應以真實遊戲畫面為主。這段 AI 影片適合放在社交平台與廣告。
- 廣告不可以誤導:影片裡出現的玩法(停下自動揮劍、升級進化、頭目預警、必殺技)都是遊戲裡真的有的;不要讓 AI 加入遊戲沒有的東西(例如騎馬、開放世界、多人對戰)。
- 使用前確認 Gemini 當時的條款允許商業用途,並保留生成紀錄。
- 不要讓 AI 模仿其他遊戲或電影的角色與畫風。
