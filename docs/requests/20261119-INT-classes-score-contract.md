# 2026-11-19 擁有人試玩回饋：職業、配樂、文字設計

擁有人已直接要求執行配樂重設、法師／弓箭手選角、字體重設，並深入測試玩法和畫質；同時明確不需要新版遊戲下載。此指示擴充早期只有近戰主角的原型範圍，整合工作可修改職業狀態、戰鬥、存檔、流程、音樂和相應 UI／測試。沒有開放網絡功能或新增第三方遊戲外掛。

新合約：`GameState.hero_class` 為 knight / mage / archer；`GameState.base_stats()` 取得職業基準；`HeroClassData` 集中職業參數；存檔 v7 保存故事職業。`BASE_STATS` 保留為騎士基準，供既有引用相容。`Music.play` API 不變，改為 OGG 優先和戰況伴奏。六章流程、EventBus 既有訊號與碰撞單位保留。

實作與驗證：`docs/MUSIC_CLASSES_TYPOGRAPHY.md`、`docs/status/LINE_INT.md`。
