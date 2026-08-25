# External touches

Everything under `test_hub/` is self-contained. This file tracks every place *outside* `test_hub/` that had to be touched to make the hub actually work — because some systems (battle, map transitions) can only be exercised through the real game's session/orchestration layer, which lives in `game/`, not `test_hub/`.

Each entry below is also marked in the code itself with a `# Test Hub only — see test_hub/EXTERNAL_TOUCHES.md` (or `;` for `.tscn` files) comment, so a repo-wide search for `Test Hub only` finds every touch listed here.

To remove Test Hub entirely: delete the `test_hub/` folder, then remove every block listed below (search for `Test Hub only` first — it's the fastest way to find them all, this file is the fallback/detail reference).

## `game/main/main.gd`

- `MAP_SCENES` dictionary: the `&"test_hub"`, `&"test_hub_battle"`, and `&"test_hub_astrals_roster"` entries (and their preloads).
- `TEST_ITEM_KIT` / `TEST_ITEM_KIT_AMOUNT` consts (used by the Battle building's "Stock Inventory" box).
- `_connect_world_map_signals()`: the calls connecting `&"test_battle_start_requested"` and `&"test_astral_gift_requested"`.
- `_on_facility_action_requested()`: the `&"open_squad_screen"` and `&"stock_test_inventory"` match cases. **Note:** these two action ids are intentionally building-agnostic (not `battle_*`-prefixed) since multiple Test Hub buildings reuse them — expect more buildings to add match cases here as Test Hub grows before this section is ever removed wholesale.
- Whole functions: `_grant_test_item_kit()`, `_on_test_battle_start_requested()`, `_start_test_battle()`, `_on_test_astral_gift_requested()`.
- **Not test-hub-only, do not remove:** `_run_battle()` was extracted out of `_start_wild_battle()` as a shared helper — it's used by both real wild battles and Test Hub battles. Removing Test Hub only means removing `_start_test_battle()`'s call into it, not the function itself.

## `game/world/maps/verdant_valley/verdant_valley.gd`

- `dev_test_hub_portal` onready var.
- The `_setup_dev_test_hub_portal()` call inside `_ready()`.
- Whole functions: `_setup_dev_test_hub_portal()`, `_on_dev_test_hub_portal_requested()`.

## `game/world/maps/verdant_valley/verdant_valley.tscn`

- The `4_dev_portal` ext_resource (pointing at `test_hub/dev/dev_test_hub_portal.tscn`).
- The `DevTestHubPortal` node instance.

## History

- 2026-08-25: `test_hub` map registration + Battle building interior + dev portal added to `verdant_valley`. An earlier alternative (`test_hub/dev/test_hub_standalone.tscn`, an F6-runnable bootstrap scene requiring zero external touches) was tried first but deleted once it became clear it can't support anything needing real session/battle orchestration — see the `feedback-isolate-shared-work` memory for the full reasoning. The dev portal is now the only way into `test_hub`.
