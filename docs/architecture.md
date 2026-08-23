# GDDVideogioco — Technical Architecture

## 1. Scope

This document defines the high-level technical architecture for `GDDVideogioco`.

The project must support one shared gameplay codebase for:

- offline single-player;
- future co-op;
- future PvP where required by game design;
- future raid sessions;
- future listen-server/self-hosted play;
- future dedicated Godot servers running headless.

The goal is **not** to implement the full online stack now. The goal is to make current development compatible with it.

Core rule:

```text
Single-player = local authority
Multiplayer   = server authority
```

The gameplay rules should remain the same in both cases.

---

## 2. Current / Later / Future Deployment

### NOW

Focus on:

- complete single-player gameplay;
- multiplayer-ready ownership;
- separation of input and simulation;
- server-authoritative-compatible gameplay APIs;
- stable IDs;
- serializable data;
- headless-compatible gameplay logic;
- clear player/session ownership;
- preservation of existing saves and behavior.

Do **not** build cloud infrastructure simply for future-proofing.

Phase 1 currently implemented:

- `RuntimeContext` centralizes runtime role, authority and the current world instance ID;
- `PlayerSession` owns the local actor, Inventory, AstralRoster, Grimoire, PlayerProfile and player services;
- `Main` can resolve `actor -> PlayerSession` for world interactions, facilities, NPCs, trainers, transitions and battle entry;
- local input produces a serializable `PlayerMovementCommand` consumed by character simulation;
- `SaveManager` serializes state independently from an injectable `SaveStorage` implementation;
- shop and coin-flip UI request authoritative operations from `PlayerEconomyService`;
- `BattleController.setup_for_session()` provides an ownership seam while preserving its legacy setup API.

This is architectural preparation, not working multiplayer.

### LATER

When real multiplayer work starts:

- introduce actual network sessions;
- spawn multiple players;
- add RPC/replication only where needed;
- synchronize world/player state;
- implement session/instance visibility;
- make combat authority explicit;
- test listen server and dedicated server locally;
- add protocol/version compatibility.

### FUTURE DEPLOYMENT

Only after the multiplayer gameplay works locally:

- export a Godot Linux dedicated server;
- containerize the server with Docker;
- deploy initially to a simple Linux host/VPS where appropriate;
- introduce backend/database for persistent online data;
- add matchmaking if required;
- consider Kubernetes/Agones only when scale justifies orchestration.

Docker/Kubernetes/Agones are deployment concerns, not gameplay requirements.

---

## 3. Architecture Principles

### 3.1 Shared Gameplay Code

Do not maintain separate implementations for offline and online gameplay.

```text
                 Gameplay Rules
                       |
             +---------+---------+
             |                   |
      Local Authority       Server Authority
       Single-player          Multiplayer
```

The authority changes. The gameplay rules do not.

### 3.2 Server Authority

Important multiplayer outcomes must eventually be decided by the server.

Examples:

- combat results;
- damage;
- captures;
- RNG;
- inventory changes;
- Astral ownership;
- progression;
- currency;
- evolution;
- trading;
- rewards;
- raid results;
- auction operations.

Clients express **intent**, not trusted results.

```text
Client intent
    |
    v
Authority validation
    |
    v
Gameplay/domain operation
    |
    v
Authoritative state mutation
    |
    v
Result presentation / replication
```

Example:

```text
GOOD:
Client -> "Use move 2"
Server -> validates, calculates, mutates HP

BAD:
Client -> "Move 2 dealt 742 damage"
Server -> trusts client
```

Single-player uses the same validation/gameplay path with local authority.

---

## 4. Runtime Modes

The architecture should eventually support:

```text
OFFLINE
LISTEN_SERVER
NETWORK_CLIENT
DEDICATED_SERVER
```

These modes do not all need to be implemented immediately.

Runtime-role knowledge should be centralized instead of scattered across unrelated gameplay classes.

Avoid repeated runtime checks throughout domain code when a centralized session/runtime abstraction can answer:

- Is this process authoritative?
- Is this the local player?
- Is presentation available?
- Is this process headless?

Current implementation: `game/session/runtime_context.gd`. Only `OFFLINE` is exercised by normal gameplay today. The other values define centralized roles and trust behavior; they do not create peers, spawn remote players or replicate state.

---

## 5. High-Level Component Model

```text
                        +----------------------+
                        |      Runtime Role    |
                        | offline/client/server|
                        +----------+-----------+
                                   |
                                   v
                        +----------------------+
                        | Session / Ownership  |
                        | PlayerSession/Context|
                        +----------+-----------+
                                   |
          +------------------------+------------------------+
          |                        |                        |
          v                        v                        v
+------------------+     +------------------+     +------------------+
| Player Data      |     | World / Instance |     | Battle / Domain  |
| profile          |     | maps             |     | simulation       |
| inventory        |     | interactions     |     | rules            |
| Astral roster    |     | NPCs             |     | RNG              |
| grimoire         |     | encounters       |     | rewards          |
+--------+---------+     +---------+--------+     +--------+---------+
         |                         |                       |
         +-------------------------+-----------------------+
                                   |
                                   v
                        +----------------------+
                        | Authoritative State  |
                        +----------+-----------+
                                   |
                 +-----------------+-----------------+
                 |                                   |
                 v                                   v
        +--------------------+              +--------------------+
        | Presentation / UI  |              | Persistence        |
        | camera / animation |              | local now          |
        | local input        |              | backend later      |
        +--------------------+              +--------------------+
```

Future networking wraps the authoritative gameplay boundary rather than replacing it.

---

## 6. PlayerSession / PlayerContext

Current single-player-oriented code often assumes one global:

```text
Player
Inventory
AstralRoster
PlayerProfile
```

The target architecture must represent player-specific ownership explicitly.

Conceptual model:

```text
PlayerSession A
├── session/player ID
├── actor/avatar
├── Inventory
├── AstralRoster
├── PlayerProfile
├── Grimoire if player-owned
└── future network peer metadata

PlayerSession B
├── ...
```

For now, the project can still have one local session.

The important change is that gameplay should increasingly resolve:

```text
actor -> owning PlayerSession
```

rather than relying everywhere on:

```text
actor == global_player
```

The abstraction must stay lightweight. Do not duplicate every player system until multiplayer actually requires multiple simultaneous sessions.

Current implementation: `game/session/player_session.gd`, registered by `RuntimeContext`. `Main.get_local_player_session()` and `Main.get_player_session_for_actor()` are the supported orchestration entry points. The current scene registers one local session, while the registry can represent additional sessions without changing player-owned data classes.

---

## 7. Input -> Intent -> Simulation

Local input must not define the movement simulation itself.

Target flow:

```text
Keyboard / Controller
        |
        v
Local Input Adapter
        |
        v
Movement Intent / Command
        |
        v
Character Simulation
```

Future online flow:

```text
Remote Input / Network Request
        |
        v
Movement Intent / Command
        |
        v
Authoritative Character Simulation
```

The same simulation should be reusable in both cases.

Prediction, reconciliation and lag compensation are **future work**, not current requirements.

Current implementation:

```text
LocalPlayerInput
       |
       v
PlayerMovementCommand
       |
       v
PlayerController.simulate_movement()
```

The controller can disable local input and accept submitted commands. No prediction, reconciliation, remote transport or movement replication exists yet.

---

## 8. Gameplay / Domain Layer

Gameplay/domain logic should:

- operate on game state;
- validate actions;
- apply game rules;
- mutate authoritative state;
- emit meaningful results/signals;
- remain usable without UI;
- remain usable without local input;
- remain usable in headless mode.

Examples of domain systems:

- inventory;
- Astral state;
- progression;
- capture logic;
- evolution;
- battle rules;
- rewards;
- economy;
- NPC/trainer outcome state;
- map/world persistent state.

Domain logic should not require RPC methods to function.

---

## 9. Presentation / UI Layer

Presentation includes:

- `GameUI`;
- buttons;
- menus;
- HUD;
- camera;
- VFX;
- animations;
- audio;
- local notifications.

Presentation may request actions but should not become authoritative.

```text
Shop UI
   |
   v
request_purchase(item_id)
   |
   v
Gameplay service validates currency and item
   |
   v
Inventory/Profile state changes
   |
   v
UI refreshes
```

Avoid embedding persistent gameplay decisions directly inside button handlers.

---

## 10. Stable IDs and Data Contracts

Continue using stable identifiers such as:

```text
astral_id
move_id
item_id
map_id
interaction_id
trainer_id
npc_id
```

Transferable or persistent state should prefer:

- bool;
- int;
- float;
- String;
- StringName;
- Array;
- Dictionary;
- stable IDs.

Avoid future networking designs based on sending direct references to Node, Resource or scene instances.

Resources such as Astral definitions may remain local shared definitions. Runtime state should be represented by IDs + serializable values.

---

## 11. World and Instance Model

The future world model must distinguish at least:

```text
map_id
instance_id
players in instance
```

A player does not need to receive every other player's state globally.

```text
World
├── Instance A
│   ├── Player 1
│   └── Player 2
│
├── Instance B
│   └── Player 3
│
└── Raid Instance C
    ├── Player 4
    ├── Player 5
    ├── Player 6
    └── Player 7
```

Future replication/visibility should be scoped by relevant instance/area.

Player limits must belong to session/mode/instance configuration. Do not hard-code one universal multiplayer cap.

---

## 12. Interactions / NPC / Trainers / Facilities

World interactions should increasingly operate on an actor and resolve its player context.

```text
interaction request
       |
       v
resolve actor -> PlayerSession
       |
       v
validate interaction
       |
       v
modify owning player/world state
```

Avoid future growth of logic based on `actor != player` when the actual rule is that the actor must belong to a valid player session.

Single-player still resolves to the local session.

---

## 13. Battle Architecture Target

The current battle implementation combines substantial simulation and presentation responsibilities.

Do not rewrite it all at once.

Target:

```text
+------------------------------+
| Battle Simulation / State    |
|                              |
| turn rules                   |
| moves                        |
| damage                       |
| statuses                     |
| RNG                          |
| synergies                    |
| victory/defeat               |
| rewards                      |
+---------------+--------------+
                |
                v
+------------------------------+
| Battle Presentation          |
|                              |
| Camera                       |
| Labels                       |
| Buttons                      |
| Models                       |
| Animations                   |
| Messages                     |
+------------------------------+
```

The battle simulation should eventually be runnable:

- offline;
- on a listen server;
- on a dedicated headless server;
- without Camera3D/UI.

Migration should be incremental.

The current phase adds only a session-aware setup seam. `BattleMath` and `BattleSynergyRuntime` already contain reusable gameplay logic, but `BattleController` still owns UI nodes, animation, state mutation and turn flow together. A server/headless battle simulation remains Phase 2/3 work and must not be claimed as complete.

Whenever battle code is touched:

- avoid adding new UI dependencies to gameplay rules;
- extract pure calculations/state logic when useful;
- keep existing gameplay stable.

---

## 14. RNG Authority

Gameplay-relevant randomness must be generated or controlled by the authority.

Examples:

- damage variation;
- crits;
- captures;
- shiny rolls;
- encounters;
- AI choices;
- loot;
- drops;
- procedural raid generation;
- raid rewards.

Preferred pattern:

```text
Authority owns RNG / seed
       |
       v
Gameplay method receives or accesses controlled RNG
```

Do not allow separate clients to independently roll outcomes that must agree.

Full deterministic lockstep is not currently required.

---

## 15. Persistence Architecture

### Current

```text
Runtime state
     |
     v
SaveManager
     |
     v
JSON in user://
```

Existing `get_save_data()` / `load_save_data()` patterns should be preserved.

### Target Boundary

```text
                  Runtime Game State
                         |
                         v
                Serialization Contract
                         |
                 +-------+-------+
                 |               |
                 v               v
          Local Storage     Remote Storage
           single-player    future online
             user://         backend/database
```

Gameplay systems should know how to serialize their state. They should not need to know whether final storage is local JSON, server memory, backend API or database.

Do not break existing saves without explicit migration.

Current implementation keeps `SAVE_VERSION = 1` and all existing payload keys. `SaveManager` owns serialization/orchestration and delegates text storage to `SaveStorage`; `LocalFileSaveStorage` remains the default `user://` JSON implementation. A future server/backend can provide another storage implementation without moving persistence concerns into gameplay systems.

---

## 16. Backend Boundary — Future

Persistent online features will eventually require services outside normal Godot client gameplay.

Examples:

- accounts;
- persistent characters;
- persistent Astral ownership;
- inventory persistence;
- auction house;
- matchmaking;
- raid allocation;
- server-side economy;
- cross-session progression.

Conceptual future boundary:

```text
Godot Client
     |
     +---- realtime ----> Godot Game Server
     |
     +---- service -----> Backend API
                              |
                              v
                          Database
```

The backend is future work.

Do not implement HTTP/database abstractions until a real feature needs them.

---

## 17. Dedicated Server / Headless Requirements

Future server gameplay must not require:

- visible UI;
- camera;
- local input;
- audio;
- rendering.

A future dedicated process should conceptually be launchable as:

```text
Godot dedicated/headless server
    |
    ├── runtime role = DEDICATED_SERVER
    ├── port/config
    ├── one or more game sessions/instances
    └── authoritative simulation
```

Do not build the production server export now unless requested.

New gameplay code should simply avoid making headless execution unnecessarily difficult.

---

## 18. Networking Layer — Future

Networking will be added only when there are concrete synchronization needs.

Possible Godot facilities include:

- high-level Multiplayer API;
- RPC;
- MultiplayerSpawner;
- MultiplayerSynchronizer;
- ENet or another suitable peer implementation.

Architecture rule:

```text
NETWORKING
    |
    v
thin transport / replication layer
    |
    v
GAMEPLAY API
    |
    v
AUTHORITATIVE STATE
```

Avoid making an RPC method the entire gameplay implementation.

Do not add network nodes merely to make the project appear "multiplayer-ready."

---

## 19. Security / Trust Boundaries

In online mode, treat the client as untrusted for important persistent or competitive state.

Never rely only on the client for:

- currency values;
- owned Astrals;
- inventory contents;
- battle outcome;
- capture success;
- progression;
- rewards;
- auction ownership/prices;
- raid result.

This does not mean a full anti-cheat system is needed now.

Architectural requirement:

```text
important state -> authority validates/mutates it
```

---

## 20. Hosting / Deployment Assumptions

The gameplay architecture should remain deployable later as a normal dedicated server process.

Expected future progression:

```text
Local dedicated server testing
        |
        v
Linux dedicated server build
        |
        v
Docker container
        |
        v
Single VPS / Docker Compose
        |
        v
Multiple hosts if needed
        |
        v
Kubernetes + Agones only if scale justifies it
```

No gameplay system should know or care whether its server process is running directly on Linux, inside Docker, under Docker Compose, under Kubernetes or under Agones.

---

## 21. Docker / Kubernetes / Agones

These are **future deployment concerns**.

### Docker

Likely useful for:

- packaging the Godot dedicated server;
- reproducible server environments;
- staging/production parity;
- CI/CD.

### Kubernetes

Useful only when the project has enough concurrent game-server instances to justify orchestration.

### Agones

Potential future fit for dynamically allocated dedicated game-server instances, particularly raid/session servers.

None of these should be introduced into gameplay code.

---

## 22. Current Project Areas Most Relevant to Migration

Current project structure already provides useful separation:

```text
game/
├── astrals/
├── battle/
├── grimoire/
├── interaction/
├── inventory/
├── main/
├── npcs/
├── player/
├── save/
├── ui/
└── world/
```

### `game/main`

Current coordination is heavily oriented around one Player, one Inventory, one Roster and one Profile.

Target:
- keep Main as orchestration;
- reduce implicit global-player assumptions;
- resolve actor/session ownership explicitly.

### `game/player`

Current movement reads local `Input`.

Target:
- separate input collection from movement simulation.

### `game/battle`

Current controller mixes gameplay and presentation.

Target:
- gradually extract headless-compatible simulation/state.

### `game/save`

Current local save implementation is useful.

Target:
- preserve serialization;
- later allow storage implementations other than local filesystem.

### `game/session`

Current foundation:
- one explicit local `PlayerSession`;
- actor-to-session lookup;
- centralized runtime role and authority query;
- a configured `world_instance_id` seam.

Not implemented:
- peer lifecycle;
- remote sessions;
- player spawning/replication;
- map/instance membership management.

### `game/astrals`

Current use of definitions + serializable runtime instances is broadly compatible with future networking/persistence.

Preserve this direction.

---

## 23. Migration Roadmap

### Phase 1 — Architecture Conversion

Goal: preserve single-player while removing the strongest single-player assumptions.

Recommended work:

1. Introduce lightweight player session/context ownership.
2. Resolve player-specific systems through that context.
3. Reduce direct `actor == player` assumptions.
4. Separate local input collection from movement simulation.
5. Centralize runtime role/authority only if needed now.
6. Preserve stable serialization and save compatibility.
7. Keep new gameplay headless-compatible.
8. Document remaining single-player-oriented debt.

No full networking required.

### Phase 2 — Local Multiplayer Foundation

Goal: prove the architecture with multiple processes/players.

Possible work:

1. Start a Godot host/server locally.
2. Connect second client locally.
3. Spawn multiple player actors.
4. Assign ownership/session IDs.
5. Synchronize essential movement/state.
6. Scope visibility by instance/map.
7. Validate interaction ownership.
8. Add protocol/version identifier.

Do not network every system at once.

### Phase 3 — Authoritative Gameplay

Goal: move important outcomes under server authority.

Likely order:

1. interactions;
2. inventory operations;
3. currency;
4. captures;
5. Astral state;
6. battle commands/results;
7. rewards;
8. progression.

### Phase 4 — Raid / Session Infrastructure

Goal: support documented multiplayer raid gameplay.

Work may include:

- party/session formation;
- ready state;
- raid instance allocation;
- authoritative procedural generation seed;
- raid-specific player limit;
- boss shared state;
- authoritative rewards.

### Phase 5 — Persistent Online Backend

Only when required by actual game features.

Likely responsibilities:

- accounts;
- persistent online save state;
- inventory/Astral ownership;
- auction house;
- matchmaking;
- long-lived economy state.

### Phase 6 — Production Deployment

Only after the game server works correctly.

Possible path:

```text
Godot Linux dedicated build
-> Docker
-> VPS / Compose
-> monitoring/backups
-> multi-host
-> Kubernetes/Agones if needed
```

---

## 24. Rules for New Features

Every significant new gameplay feature should answer:

1. Who owns this state?
2. Who is authoritative over it?
3. Can it run without UI?
4. Can it run without local Input?
5. Can its state be serialized with stable IDs?
6. Does it rely on authoritative RNG?
7. Is this player-specific, world-specific or instance-specific?
8. Does it assume only one player?
9. Does it write directly to local filesystem?
10. Would a dedicated server be able to execute the gameplay portion?

For offline play, the answer may still be:

```text
local process is authority
```

That is valid.

---

## 25. Avoid Premature Complexity

Do not introduce infrastructure solely because the game may need it years later.

Avoid premature:

- microservices;
- message brokers;
- Redis;
- Kubernetes manifests;
- Agones resources;
- generic command buses;
- global event buses;
- complex DI frameworks;
- prediction/reconciliation;
- large networking abstractions without real consumers.

Prefer small seams around current concrete responsibilities.

---

## 26. Technical Debt / Known Single-Player-Oriented Areas

The following are expected migration targets and should not be mistaken for completed multiplayer support:

- `Main` still owns one active world map, one presentation stack and one active battle/trainer/NPC flow, although player-owned dependencies are now resolved through sessions;
- world encounter/trainer discovery still assigns one local actor in several map scripts;
- local interaction/UI input has no remote command transport;
- battle simulation and battle presentation are substantially coupled;
- local JSON persistence is the only implemented storage backend, although storage is now injectable;
- Astral exchange/gift and several other UI flows still mutate domain objects directly and need authority services when networked;
- important encounter/procedural RNG outside battle is not yet uniformly supplied by a central authority;
- actual networking, replication and peer/session lifecycle are not yet implemented;
- dedicated-server export/runtime is not yet productionized;
- matchmaking/backend/database do not exist yet.

These are roadmap items, not reasons to perform uncontrolled rewrites.

---

## 27. Definition of Multiplayer-Ready

A feature is **multiplayer-ready** when:

- its gameplay state has clear ownership;
- authority can validate/mutate it;
- it does not require UI to execute;
- local input is not embedded in its core simulation;
- important RNG is authority-controlled;
- relevant state can be represented with stable serializable data;
- networking could wrap the gameplay API without rewriting the feature.

Multiplayer-ready does **not** mean that the feature is already networked.

---

## 28. Final Design Principle

Optimize first for a maintainable game.

Then make authority and ownership explicit.

Then add networking.

Then deploy it.

```text
GOOD GAMEPLAY ARCHITECTURE
        |
        v
AUTHORITATIVE MULTIPLAYER
        |
        v
DEDICATED SERVER
        |
        v
DOCKER / CLOUD / ORCHESTRATION
```

Do not reverse this order.
