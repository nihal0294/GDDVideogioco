# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Required reading before non-trivial work

This repo already documents its own working rules in detail — read them instead of re-deriving them:

- **`AGENTS.md`** (repo root) — the authoritative collaboration/architecture ruleset for coding agents in this project. Covers scope, the multiplayer-ready architecture principles, authority/ownership rules, RNG, persistence, battle system constraints, and git/testing conduct. Follow it as if it were part of this file.
- **`docs/architecture.md`** — required reading for tasks touching architecture, networking, player/session ownership, persistence, battles, authority, or headless/server behavior.
- **`docs/`** — game design source of truth (Italian). Search for files relevant to the task rather than reading all of it (`docs/sistemi/` for per-system specs, `docs/trama.md` for story, `docs/topics-di-discussione/` for meeting notes).

Do not implement speculative multiplayer/backend/deployment infrastructure unless explicitly requested — see `AGENTS.md` § "No Premature Infrastructure".

## Commands

This is a Godot **4.5** project (GDScript). There is no separate build step; Godot compiles/imports on run.

The Godot editor executable path is machine-specific and configured per developer in `.vscode/settings.json` (`godotTools.editorPath.godot4`) — do not assume a fixed path across machines.

- **Run the game (editor):** open the project in Godot 4.5 and press Play, or from a terminal:
  `godot4 --path . `
- **Run a single smoke test headless:**
  `godot4 --headless --script res://tests/integration/<test_file>.gd`
  Each test script `extends SceneTree`, runs its checks in `_run()`, prints `PASS`/`FAIL (<n> errori)`, and exits with code `0` on success, `1` on failure (also on a watchdog timeout, where present). Run one at a time; there is no aggregate test runner script.
- **Test files live in `tests/integration/`** (no GUT or other addon — these are plain `SceneTree` scripts, not scene-tree unit tests via an addon).

## Architecture

The high-level target architecture (shared single-player/multiplayer-ready gameplay code, server/local authority split, session ownership, headless-compatible domain logic) is fully documented in `docs/architecture.md` — read it before touching anything cross-cutting. Summary of current implementation state:

- `game/session/runtime_context.gd` — centralizes runtime role/authority (`OFFLINE` is the only exercised mode today).
- `game/session/player_session.gd` — owns one local actor's Inventory, AstralRoster, Grimoire, PlayerProfile. Resolve player-owned state via `Main.get_local_player_session()` / `Main.get_player_session_for_actor()`, not by assuming a single global player.
- `game/save/` — `SaveManager` handles serialization/orchestration (`get_save_data()`/`load_save_data()` pattern, `SAVE_VERSION`), delegating actual storage to an injectable `SaveStorage` (`LocalFileSaveStorage` is the default, writing JSON to `user://`).
- `game/battle/` — `BattleController` still mixes simulation and presentation (UI nodes, animation, turn flow); `BattleMath` and `BattleSynergyRuntime` hold the reusable, headless-safe gameplay math/logic. Don't do a full `BattleController` rewrite; extract pure logic incrementally when a task touches it.
- `game/astrals/` — species are `AstralDefinition` resources (catalog data) vs. `AstralInstance` (serializable runtime state); this split is the model to follow for future data types.
- `data/` — shared `Resource` catalog data (astrals/moves/items/encounters/maps), separate from runtime state. Subfolders are created only when the corresponding system is implemented.

Top-level `game/` module layout: `astrals/`, `battle/`, `economy/`, `grimoire/`, `interaction/`, `inventory/`, `main/`, `npcs/`, `player/`, `save/`, `session/`, `ui/`, `world/`.

Key conventions (also in `AGENTS.md`):
- `snake_case` for files/methods/variables/signals; `PascalCase` for `class_name`.
- Prefer typed GDScript, signals over hard-coded NodePaths, composition/Resources over deep inheritance.
- Gameplay-relevant randomness must go through an authority-controlled `RandomNumberGenerator`, not independent per-client rolls.
- Prefer stable string IDs (`astral_id`, `move_id`, `item_id`, `map_id`, etc.) and serializable primitives for any transferable/persistent state — never raw Node/Resource references.
