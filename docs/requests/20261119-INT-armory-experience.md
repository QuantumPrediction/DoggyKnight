# Armory experience integration

Continue the owner's authorized quality work from recovered commit 83932d2.
This integration covers the equipment UI, production inventory modifiers,
read-only comparisons, art, regression evidence and handoff.

- Replace the text-list armory with illustrated cards, slot shortcuts, visible
  prices, chapter locks, clear selection, actual stat comparisons and fixed actions.
- Comparison uses the selected class, permanent training, full loadout and set
  bonuses. It excludes run tricks and temporary buffs, and never edits a save.
- Add optional per_level_mods to catalog entries. Only training_sword and stormbow
  gain -0.01 base attack interval per upgrade: -4% / -8% at their existing caps.
  This is a small, explicit balance change to give their integer-damage plateaus
  a real timing benefit. Attack damage, pierce milestones and other items retain
  their rules. No broad difficulty adjustment or claim of human balance.
- Save v8, existing checkpoints, caps, prices, rewards and disabled payments remain.
- New artwork is generated with GPT Image and inspected in actual engine renders.
- Publish the recovered work plus this iteration as a draft against PR #11 within
  the owner's retained authorization. Do not merge or release to a store.
