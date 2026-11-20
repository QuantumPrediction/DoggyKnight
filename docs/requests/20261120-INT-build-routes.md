# 0.9 integration: first-chapter build choices

Continue the owner's requested quality work above verified 0.8.1. Two starting
routes per class should enable intentional builds without permanently locking
equipment or removing random upgrade choices. Replace the first chapter's first
mid-wave event with a class-specific route choice: one existing starter ability,
a visible benefit and cost, and one relevant future upgrade option when legal.
Evolutions retain priority; no duplicate/capped/consumed upgrades are introduced.
Existing non-route draws must retain their exact random behavior.

Route identity and effects survive stage checkpoints and retries correctly; old
checkpoints default to no route. Three later first-chapter event choices will
state concrete recovery, growth or risk/reward consequences and duration. Later
chapters/endless retain their current event table. Event cards must remain usable
on small safe areas, support existing portraits and current skill artwork, and
explain the active route during subsequent upgrade choices.

Cross-directory integration covers progression, event UI, save/checkpoint
sanitization, flow and tests. Tuning remains data-driven. Tests must exercise
actual granted abilities, tradeoffs, legal offers, migration/retry/new-run reset,
duplicate choice protection, UI and the real flow. Controlled bot runs assess
functional behavior, not human fun or an achieved 9/10 score. No new download,
Windows package or recovery archive is requested in this turn.
