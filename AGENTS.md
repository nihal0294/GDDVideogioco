# AGENTS.md

## Project Scope

Godot 4.5 game project.

Primary goals:
- Preserve current single-player behavior.
- Keep gameplay compatible with future multiplayer/co-op/PvP.
- Use one shared gameplay codebase for offline and online.
- Offline = local authority.
- Online = server authority.
- Future dedicated servers must be able to run headless.

Do not implement speculative infrastructure unless explicitly requested.

---

## Source of Truth

Game design and requirements live in `/docs`.

Before non-trivial work:
1. Read this file.
2. Search `/docs` for files relevant to the task.
3. Read only relevant documentation.
4. Inspect relevant existing code/scenes.
5. Reuse existing systems before creating new ones.

Do not read all documentation for every task.

If docs conflict with code or with each other, report the conflict before making broad changes.

Technical architecture:
- `docs/architecture.md`

Treat it as required reading for tasks involving:
- architecture;
- multiplayer/networking;
- player/session ownership;
- persistence;
- battles;
- authority;
- headless/server behavior.

---

## General Rules

- Preserve existing behavior unless explicitly asked to change it.
- Prefer small, focused, reversible changes.
- Extend existing architecture instead of rewriting it.
- Do not modify unrelated systems.
- Do not invent undocumented game requirements.
- Do not add plugins/dependencies unless requested.
- Do not edit `.godot/` or generated/cache files.
- Do not rename/delete important files unless required.
- Prefer maintainable code over clever abstractions.
- Avoid duplicate logic and premature generalization.

---

## Architecture Principles

- State belongs to the player, world, battle or service that owns it.
- Resolve player-owned state through `PlayerSession`, not unrelated scene paths.
- Keep request, validation, authoritative mutation and presentation distinct.
- Prefer progressive seams around current code over mass rewrites.
- Keep domain APIs callable without networking; future RPCs remain adapters.

---

## Godot

- Target Godot **4.5 stable**.
- Prefer GDScript.
- Prefer typed GDScript where practical.
- Follow Godot lifecycle/scene ownership conventions.
- Prefer composition, Resources and reusable scenes over deep inheritance.
- Prefer signals for decoupled communication.
- Avoid fragile hard-coded NodePaths when safer references/signals/groups are available.
- Avoid unnecessary per-frame work.
- Keep gameplay, persistent data and presentation separated when practical.

Naming:
- `snake_case`: files, methods, variables, signals.
- `PascalCase`: `class_name` and custom classes.

---

## Multiplayer-Ready Architecture

Every significant gameplay feature must work conceptually in:

```text
offline -> local authority
online  -> server authority
```

unless it is explicitly presentation/local-only.

Do **not** create separate gameplay implementations for single-player and multiplayer.

Before adding direct dependencies on:
- one global Player;
- `Input`;
- UI nodes;
- local filesystem;
- camera/rendering;

consider whether they make future server/multiplayer support harder.

### Authority

For important gameplay, the authority decides results.

Preferred flow:

```text
request action
    ->
validate
    ->
execute gameplay logic
    ->
mutate authoritative state
    ->
present/replicate result
```

Never design important online state around trusting client-reported results.

Server-authoritative candidates include:
- combat results;
- RNG results;
- inventory;
- currency;
- captures;
- Astral ownership;
- evolution;
- trades;
- progression;
- rewards;
- raid rewards;
- future auctions.

Offline uses the same rules with local authority.

### Networking Boundary

Gameplay/domain code should not depend directly on RPCs.

Future RPC/network code should remain a thin transport layer around normal gameplay methods.

Do not add networking nodes/RPCs merely for future-proofing without a concrete use case.

---

## Player Ownership

Do not assume forever that there is only:

```text
THE Player
THE Inventory
THE AstralRoster
THE PlayerProfile
```

Player-specific systems should be resolvable through the project's player session/context abstraction.

Code receiving an actor should prefer resolving its player context rather than comparing everything against one global player.

Do not duplicate all player systems prematurely; support the current local player while keeping ownership extensible.

---

## Input and Simulation

Local `Input` should not be inseparable from character simulation.

Preferred flow:

```text
Input / network intent
        ->
player command
        ->
movement/gameplay simulation
```

Simulation should eventually be callable without local keyboard/controller input.

Do not implement prediction/reconciliation unless requested.

---

## Data and Serialization

Prefer stable IDs and serializable state:

- `astral_id`
- `move_id`
- `item_id`
- `map_id`
- `interaction_id`
- similar stable identifiers

For transferable/persistent state prefer:
- bool;
- int;
- float;
- String/StringName;
- Array;
- Dictionary;
- stable IDs.

Do not design networking around transferring direct Node/Resource references.

Resources may remain local definitions/catalog data where appropriate.

---

## RNG

Gameplay-relevant randomness must be controllable by the authority.

Examples:
- damage;
- crits;
- captures;
- shiny rolls;
- encounters;
- drops;
- AI;
- loot;
- rewards.

Prefer injectable/shared `RandomNumberGenerator` where appropriate.

Do not make important multiplayer outcomes depend on independent client RNG.

---

## UI / Presentation

UI requests actions and displays state.

UI must not be the authoritative source of gameplay state.

Keep presentation-specific dependencies such as:
- Camera;
- Button;
- Label;
- animation;
- audio;

out of reusable/server gameplay logic where practical.

---

## Battle System

Preserve current battle behavior.

Long-term target:

```text
Battle Simulation / State
        |
Battle Presentation / UI
```

Do not perform a massive `BattleController` rewrite unless explicitly requested.

When touching battle code:
- move new gameplay logic toward server/headless-compatible code;
- avoid increasing coupling between simulation and UI;
- extract pieces only when useful for the current task.

---

## World / Instances

World code should remain compatible with future concepts of:

```text
map_id
instance_id
players in instance
```

Do not assume every online player sees every other player.

Player limits may differ by mode/session/instance.

Do not hard-code one universal multiplayer player cap.

---

## Headless / Runtime Roles

New gameplay code should be capable of running eventually on a Godot dedicated server without requiring:
- UI;
- Camera;
- local Input;
- audio;
- rendering.

Future runtime roles include:

```text
OFFLINE
LISTEN_SERVER
NETWORK_CLIENT
DEDICATED_SERVER
```

If runtime-role logic is needed, centralize it.

Do not spread repeated `if multiplayer/server/offline` checks throughout unrelated systems.

---

## Persistence

Preserve existing `get_save_data()` / `load_save_data()` patterns.

Current:

```text
game state -> local save -> user://
```

Future:

```text
game state -> persistence boundary
              ├─ offline -> local storage
              └─ online  -> server/backend
```

Do not couple gameplay logic unnecessarily to `FileAccess`.

Do not silently break existing saves.

If a format must change:
- preserve backward compatibility when practical;
- document migration;
- bump versions only when necessary.

---

## No Premature Infrastructure

Unless explicitly requested, do NOT implement:
- Docker;
- Kubernetes;
- Agones;
- cloud infrastructure;
- microservices;
- HTTP backend;
- database;
- Redis;
- authentication;
- matchmaking service;
- advanced anti-cheat;
- prediction/reconciliation;
- generic enterprise-style buses/frameworks.

Design code so these can be added later without implementing them now.

---

## Before Implementing

For non-trivial tasks:
1. Check relevant `/docs`.
2. Inspect relevant code/scenes.
3. Find existing reusable systems.
4. Identify the smallest safe change.
5. Check multiplayer/server implications when applicable.
6. Preserve public APIs/save formats where practical.
7. Report major conflicts or risky rewrites before doing them.

Do not turn a focused task into a repository-wide refactor.

---

## Testing

After changes, when applicable:
- check GDScript syntax/types;
- check scene/resource references;
- run relevant tests;
- validate affected gameplay;
- validate with Godot 4.5;
- use headless validation when useful.

Never claim a test was run if it was not.

Preserve current single-player behavior.

---

## Git

- Work on the current branch unless explicitly told otherwise.
- Do not commit automatically.
- Do not push automatically.
- Do not switch/create branches unless requested.
- Never force-push.
- Never reset/rebase/clean/discard user work unless explicitly requested.
- Preserve uncommitted user changes.

---

## Final Response

Keep task-completion responses concise.

Report only:
- what changed;
- files changed;
- important architectural decisions;
- tests actually run;
- unresolved problems/risks.

Do not repeat documentation or explain obvious code unless asked.
