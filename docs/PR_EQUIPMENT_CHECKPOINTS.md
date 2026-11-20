# [INT] Add equipment progression and preserve adventure builds across resume

Story resume previously restarted the reached stage with a level-one character and no acquired tricks. Stage-boundary checkpoints now preserve the build, experience, event modifiers, vigor, loadout and saved random states. The current stage restarts when resuming; unbanked stage growth and snacks return to the checkpoint. A title-screen equipment upgrade also stays pending through a death/retry and takes effect at the next stage.

Add an 18-item permanent armory: six common weapons/armor capped at level 5, six epic weapons/armor and six epic treasures capped at level 9. Each class has a weapon, armor and two distinct treasure slots. Include two-piece set bonuses, guaranteed forging, specified coin-or-gem shop purchases, boss drops with a fifth-clear guarantee, duplicate conversion, and combat effects for counterattacks, companion blocks, movement charges, shields, healing, splash and piercing. Purchases roll back if saving fails. Real payment and paid-gem crediting remain disabled.

This draft targets `codex/music-classes-type` (PR #11), following the art and Windows drafts #10 and #9. `AGENTS.md` and `docs/PROJECT_STATE.md` give future sessions a durable entry point. No merge, executable export or store release is included.

Validation: final Godot 4.7.2 full-suite run: **823 cases, 0 failed, 0 broken files; exit code 0** (`final_regression_823.log`). The new retry regression failed on the recovered implementation and passes after the fix; all 21 equipment cases pass. Existing test cleanup and exit resource warnings remain; see `docs/validation/0.4.0/` for unabridged evidence.

The five included screenshots are actual Linux Godot OpenGL armory renders from the preceding session, using staged wallets and unlocks. Their hashes were verified during recovery; the armory UI and artwork did not change during the retry fix. They are not human playtest or payment evidence. No native Windows/mobile, long-term balance, manual music-listening or real-payment validation is claimed.

| Loadout | Item detail | Gem confirmation |
| --- | --- | --- |
| ![Loadout](https://raw.githubusercontent.com/QuantumPrediction/DoggyKnight/codex/equipment-checkpoints/docs/validation/0.4.0/screenshots/equipment_loadout.png) | ![Item detail](https://raw.githubusercontent.com/QuantumPrediction/DoggyKnight/codex/equipment-checkpoints/docs/validation/0.4.0/screenshots/equipment_detail.png) | ![Gem confirmation](https://raw.githubusercontent.com/QuantumPrediction/DoggyKnight/codex/equipment-checkpoints/docs/validation/0.4.0/screenshots/equipment_confirm.png) |

Implementation and rules: `docs/EQUIPMENT_SYSTEM_ZH.md`. Current handoff: `docs/PROJECT_STATE.md`.
