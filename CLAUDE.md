# CLAUDE.md —《金毛騎士》原型

這是一款像素風手機 RPG 的原型:金毛尋回犬騎士帶著同伴打小怪、升級、打頭目。完整計劃在 `docs/DEV_PLAN.md`,**動手前先讀它**。

## 你是哪一條線

擁有人會在開場指示中告訴你是 Phase 0、A、B、C、D 還是整合。只做那一線的任務。

## 不可違反的規則

1. 只修改自己擁有的目錄(`docs/DEV_PLAN.md` 第 3 節)。
2. 除了 Phase 0 與整合工作階段,不得修改 `project.godot`、`core/`、`CLAUDE.md`、`docs/DEV_PLAN.md`、`tools/run_tests.sh`。
3. 跨線溝通只走 `EventBus` 訊號與 `core/` 內的資料類別。
4. 需要改合約時,新增 `docs/requests/YYYYMMDD-<線>-<主題>.md`,不要自己改。
5. 不做 `docs/DEV_PLAN.md` 第 1 節「不包含」的任何東西。
6. 狗不會受傷:失敗與受擊表現一律可愛,不得有血或受傷畫面。
7. 可調的數值放在資料檔,不寫死。
8. 不安裝第三方外掛。

## 工作方式

- 分支:`line-a/combat`、`line-b/flow`、`line-c/art-ui`、`line-d/camp-mobile`。
- 提交訊息以 `[A]`、`[B]`、`[C]`、`[D]`、`[P0]`、`[INT]` 開頭;小步提交並推送。
- 開 PR 前執行 `tools/run_tests.sh`,全部通過才開。
- 每次收工更新 `docs/status/LINE_X.md`:已完成 / 進行中 / 被甚麼卡住 / 下一步 / 需要擁有人決定的事。
- 擁有人不會寫程式。回報時用淺白的中文說明做了甚麼、怎樣試玩、有甚麼需要他決定。

## 技術

- 引擎:Godot 4(確切版本:__由 Phase 0 填寫__)。不得升級。
- GDScript,全部加型別標註。
- 直向 180×320,整數倍放大,像素不平滑。
- 測試指令:__由 Phase 0 填寫__。
