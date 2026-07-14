# Biome Plan Control Model

## Purpose

This document defines the persisted editing model for the Run Planner UI.

The planner is a dynamic decision-tree editor hosted by immediate-mode ImGui,
but the universe of routes, biomes, room declarations, and room templates is
known before module activation. Persistence should therefore be static at the
route-biome boundary and dynamic only inside each biome plan.

The guiding rule is:

```text
Routes order biome plans.
Biome plans own generated occurrences and topology.
Room templates own typed occurrence behavior.
Canonical plans are materialized outputs, not persisted UI documents.
```

This replaces the former single `PlannerDraft` root serializer and its dynamic
form-participant graph.

## Terminology

`Game Room Key`
: The game-data identifier, such as `F_Combat02`. It identifies one room
  declaration. It does not identify one generated occurrence.

`Biome Plan Control`
: One module-declared Lib control for one route-biome occurrence, such as
  `Underworld_F` or `Surface_Q`. It owns that biome's persisted topology,
  biome-scoped authored state, and occurrence-local state.

`Topology Node`
: One generated occurrence inside a biome decision tree. It has a stable
  planner-owned `nodeId` and references one game room key.

`Room Template`
: A registered typed interpreter such as `StandardCombat`, `FieldsCombat`,
  `ShipCombat`, or `EphyraCombat`. It owns the storage fragment, UI behavior,
  completeness, candidate providers, feedback translation, and canonical
  fragment for occurrences of that type.

`Outgoing Batch`
: The one generated-door decision owned by a parent topology node. It owns the
  peer door set, selection semantics, batch rule, and batch-authored state.

`Nested Node Control`
: A typed object exposed by a Biome Plan control for one topology node. It is
  backed by fields or table rows owned by the Biome Plan control. It is not a
  separately module-declared Lib control and does not own an independent
  profile/reset root.

`Canonical Room Node`
: The complete output consumed by history. It is materialized by joining one
  topology occurrence, its room declaration, its room-template state, and its
  incoming/outgoing reward and batch facts.

## Game Room Identity Is Not Occurrence Identity

The game can create the same ordinary combat room more than once. It can also
create the same room for multiple offered doors. Each `CreateRoom(...)` call is
a separate occurrence with independently chosen reward and encounter state.

`MaxCreationsThisRun` is an explicit generation cap, not a universal uniqueness
rule. It increments when the game creates a room for an offered door, including
an unselected door. Rooms without that declaration remain eligible according to
their other requirements.

This is grounded in the extracted game scripts:

- next-room generation calls `ChooseNextRoomData` and then `CreateRoom` for
  every offered door;
- `CreateRoom` increments `CurrentRun.RoomCreations`;
- eligibility checks `MaxCreationsThisRun` only when the room declares it;
- the ordinary `BaseF_Combat` declaration does not declare that cap;
- forced/debug generation can assign one room key to multiple peer doors.

Therefore this is invalid as persisted occurrence identity:

```text
Underworld_F_Combat02
```

The plan must instead keep declaration and occurrence identity separate:

```lua
{
    nodeId = 17,
    gameRoomKey = "F_Combat02",
}
```

Two nodes may reference the same game room key:

```lua
{ nodeId = 17, gameRoomKey = "F_Combat02" }
{ nodeId = 23, gameRoomKey = "F_Combat02" }
```

Their authored state is independent.

The room template is resolved from the room declaration. It is not copied into
persisted topology state.

## Route And Biome Composition

Route declarations own biome order:

```text
Underworld: F -> G -> H -> I
Surface:    N -> O -> P -> Q
```

The UI composes one Biome Plan control for each declared route-biome
occurrence:

```text
RoutePlan aggregate
├── Underworld_F
├── Underworld_G
├── Underworld_H
├── Underworld_I
├── Surface_N
├── Surface_O
├── Surface_P
└── Surface_Q
```

If another route uses F, it receives a separate Biome Plan control, such as
`Challenge_F`. The same game room declarations can then participate in two
routes without sharing authored plan state.

The `RoutePlan` aggregate is a plain planner object. It owns route-prefix
composition, cross-biome materialization, evaluation caching, and navigation.
It is not a root persistence control and must not serialize every biome into one
document.

## Biome Plan Control

One Biome Plan control owns:

- biome-scoped authored state;
- the root topology node;
- stable topology node identities;
- one optional outgoing batch per node;
- generated peer-door references;
- selection state;
- occurrence-local typed state;
- node insertion, removal, replacement, and reset operations;
- materialization of a complete canonical biome plan;
- candidate-provider and feedback lookup by semantic owner.

It does not own:

- room declaration facts;
- cross-biome route ordering;
- game-rule validation;
- history counters or reward bags;
- runtime execution-plan interpretation;
- UI navigation outside its biome surface.

Representative semantic interface:

```lua
biomePlan:rootNodeId()
biomePlan:node(nodeId)
biomePlan:outgoingBatch(nodeId)
biomePlan:replaceDoorTarget(parentNodeId, doorIndex, gameRoomKey)
biomePlan:selectDoor(parentNodeId, doorIndex)
biomePlan:removeOutgoingBatch(parentNodeId)
biomePlan:resetNode(nodeId)
biomePlan:isComplete(context)
biomePlan:materialize(context)
biomePlan:exportCandidates(out, context)
biomePlan:applyFeedback(feedback)
```

The exact method names are implementation details. The ownership and atomicity
are contractual.

## Decision Tree

Each biome plan is a rooted generated-room decision tree.

The root is an entered start occurrence. Every non-root node is produced by one
door in one parent node's outgoing batch.

```lua
biomePlan = {
    routeKey = "Underworld",
    biomeKey = "F",
    rootNodeId = 1,
    nodes = {
        { nodeId = 1, gameRoomKey = "F_Opening02" },
        { nodeId = 2, gameRoomKey = "F_Combat03" },
        { nodeId = 3, gameRoomKey = "F_Combat06" },
    },
}
```

A generated but unselected node is fully materialized. It contributes room
creation, reward offers, batch pressure, and other generation-time facts. It is
a dead leaf and cannot own an outgoing batch.

A selected node is entered. It may own the next outgoing batch unless it is
terminal.

Node ids are planner identities. They should be stable across edits that do not
remove the node. They must not be recomputed from room indexes, game room keys,
or labels.

## Outgoing Batch

The outgoing batch belongs to the parent topology node because the game creates
and evaluates all peer doors together.

```lua
outgoingBatch = {
    rule = "Standard",
    state = nil,
    selection = {
        mode = "single",
        selectedDoorIndex = 1,
    },
    doors = {
        { doorIndex = 1, exitIndex = 1, targetNodeId = 2 },
        { doorIndex = 2, exitIndex = 2, targetNodeId = 3 },
    },
}
```

H adds batch-authored state without moving it into either target room:

```lua
outgoingBatch = {
    rule = "FieldsCageBatch",
    state = {
        cageRoll = "max",
    },
    selection = {
        mode = "single",
        selectedDoorIndex = 1,
    },
    doors = { ... },
}
```

N uses a different selection mode over one peer set:

```lua
selection = {
    mode = "orderedSubset",
    visits = {
        { doorIndex = 3, visitOrder = 1 },
        { doorIndex = 1, visitOrder = 2 },
    },
}
```

The batch is not a separate Lib control. Its identity is derived from its owner
node because the model permits at most one outgoing batch per node.

## Occurrence-Local Typed State

Room templates operate on generated occurrences, not global game room keys.

The Biome Plan control resolves a node's game room declaration, finds its room
template, and exposes a cached nested node control backed by that node's storage
slice.

Representative node interface:

```lua
node:id()
node:gameRoomKey()
node:readPlanState()
node:isComplete(context)
node:exportCandidates(out, context)
node:applyFeedback(feedback)
node:draw(draw, context)
node:reset(reason)
```

Templates may compose reusable internal components such as reward surfaces,
payloads, encounter sequences, shops, and side-room editors. Those components
do not need independent Lib control identities merely because the UI is
visually nested.

Examples:

- `StandardCombat` owns the occurrence's generated-target reward state;
- `FieldsCombat` owns its occurrence's cage reward slots;
- `ShipCombat` owns its occurrence's encounter sequence and wheel offers;
- `EphyraCombat` owns its occurrence's pylon-local and side-room state;
- `Shop` owns its occurrence's shop offers and acquisition choices;
- `FixedOpening` may have no persisted local fields.

## Persistence And Profiles

Lib sees one control instance per route-biome occurrence. All dynamic node and
batch state is stored beneath that control's private storage roots.

The semantic model is a tree. The storage codec may normalize it into static
tables such as:

```text
BiomeState
Nodes
OutgoingBatches
Doors
StandardCombatState
FieldsCombatState
ShipCombatState
EphyraCombatState
ShopState
...
```

Every typed state row is keyed by stable `nodeId`. The room-template module owns
its storage fragment and read/write/bind behavior. The Biome Plan control
assembles those fragments; it must not hand-code every payload type in one
root file.

This is physical parent storage with logical child ownership:

```text
Lib/profile owner: Biome Plan control
semantic state owner: nested topology node control
```

Consequences:

- coordinator profiles automatically include dormant and active node state;
- `ui.controls.reset("Underworld_F")` resets the entire biome plan;
- `biomePlan:resetNode(nodeId)` resets one occurrence through its template;
- removing a topology node removes that occurrence's state rows;
- removing an occurrence never resets state belonging to a different node with
  the same game room key;
- there is no `PlannerDraft.Revision` persisted field;
- there is no compatibility adapter for the former `PlannerDraft` row ABI.

Profile loads and resets pass through Lib's normal commit lifecycle. The
planner should invalidate cached materialization/evaluation from one
non-persisted change epoch when committed configuration changes. Explicit
external config reload/resync paths must provide the same invalidation signal.

## Materialization

The persisted biome plan is not the canonical plan.

Materialization walks only the selected continuation while preserving all peer
doors on each visited parent's outgoing batch:

```text
read biome-scoped state
-> start at root node
-> read the root's typed occurrence fragment
-> materialize every peer in its outgoing batch
-> follow the batch selection
-> repeat from the selected occurrence
-> stop at a terminal room
```

For each generated door, materialization joins:

```text
parent batch door
+ target node game room declaration
+ target template generation fragment
= canonical generated door and offer point
```

For each entered room, it joins:

```text
selected topology occurrence
+ room declaration
+ target template entry/encounter fragment
+ outgoing batch
= canonical room node
```

The template decides which occurrence-local fields emit at generation time and
which emit only when that occurrence is entered. Materialization does not copy
irrelevant dormant fields into canonical history.

Unselected nodes contribute generation-time facts and incoming offer points but
do not contribute entered-room history or outgoing batches.

The canonical plan continues to use game room keys and concrete reward facts.
Planner-only node ids may be retained as source metadata during the build, but
runtime execution does not depend on them.

## Completeness And Validation

Completeness applies only to occurrences referenced by the current biome tree.
State outside the tree is not part of the plan.

Local node completeness checks required typed fields. Batch completeness checks
peer doors, exit indexes, selection shape, and batch-authored state. Biome
completeness checks the root, tree construction invariants, terminal shape, and
biome-scoped state.

Completeness does not decide game legality. A complete biome plan may still be
invalid because of eligibility, creation caps, force pressure, rewards, bags,
or timing.

`MaxCreationsThisRun` counts every previously generated topology node with the
same game room key, including unselected peers. Same-batch peers are processed
in game generation order.

## Addressing And Feedback

Validation uses game-language ownership and planner topology location together.

```lua
source = {
    routeKey = "Underworld",
    biomeKey = "F",
    gameRoomKey = "F_Combat02",
    aspect = "generatedTargetReward",
    slot = 1,
}
```

```lua
location = {
    biomeControlId = "Underworld_F",
    nodeId = 17,
    parentNodeId = 12,
    doorIndex = 2,
}
```

Validators speak in game facts and preserve these return addresses. Feedback
resolves the Biome Plan control, then the nested node or outgoing batch, then
lets that owner translate the semantic aspect into its internal provider or
widget state.

Validators must not know storage aliases, row indexes, ImGui ids, or inner
widget names.

## Mutation Rules

Biome Plan methods are the only topology write boundary.

Required invariants:

- every node id is unique and immutable;
- the root has no incoming door;
- every non-root node has exactly one incoming door;
- every door references an existing target node;
- a node cannot be its own ancestor;
- only selected/visited nodes may own outgoing batches;
- unselected generated nodes are dead leaves;
- ordinary batches select exactly one peer;
- ordered-subset batches contain unique door indexes and contiguous visit
  order;
- terminal nodes have no outgoing batch;
- batch doors reference declared exits of the parent room;
- parent replacement or removal removes the entire downstream topology branch;
- removing a branch removes only occurrence state owned by nodes in that
  branch;
- changing a parent field resets only child state whose schema is no longer
  compatible.

Malformed profile/hash input must fail at the Biome Plan storage/materialization
boundary. Draw and validation hot paths may trust a constructed tree.

## Draw And Performance

The planner remains an immediate-mode UI hot path.

- Biome Plan and nested node objects are cached by stable identity.
- Storage-field and table-row handles are cached rather than reacquired per
  frame.
- Candidate values and labels are stable arrays.
- Feedback mutates hidden/color/message arrays during dirty rebuilds.
- Draw reads prepared state and stages edits; it does not build history or run
  validators.
- Tree mutation marks one non-persisted dirty epoch.
- Materialization, history, validation, and feedback run once per dirty rebuild.
- No complete draft tree is deep-copied on each edit.

## Rejected Directions

Do not rebuild these designs:

- one global `PlannerDraft` control that serializes every biome and payload;
- one persistent control per game room key that assumes the room can occur only
  once;
- route-indexed form participants that own detached mutable draft tables;
- reward state shared across repeated occurrences of one game room;
- outgoing doors stored by target room controls;
- batch state stored by one child room;
- canonical plans containing unresolved UI roles such as `Major`, `Minor`,
  `Auto`, or `Vanilla`;
- validation feedback that performs row arithmetic or reaches into widget
  aliases.

## Supporting Docs

- `FORM_STORAGE_ROUNDTRIP.md` owns the physical storage and reset contract.
- `FORM_FEEDBACK_CONTRACT.md` owns completeness, addressing, candidates, and
  feedback application.
- `UI_IMPLEMENTATION_ORDER.md` owns the rewrite sequence.
- `../model/CANONICAL_PLAN.md` owns canonical output shape.
- `../model/DECLARATION_OWNERSHIP.md` owns declaration and room-template facts.
- `../validation/VALIDATION_MODEL.md` owns legality and candidate evaluation.
