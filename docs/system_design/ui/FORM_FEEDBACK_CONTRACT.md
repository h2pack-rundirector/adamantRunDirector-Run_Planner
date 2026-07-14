# Biome Plan Completeness And Feedback Contract

## Purpose

The UI authors a dynamic decision tree without becoming the game-rule
validator.

```text
nested controls decide local completeness
-> Biome Plan materializes a complete canonical biome
-> history and validators decide game legality
-> feedback returns to the semantic owner
```

The validator speaks game language. The UI resolves that language through
stable topology locations. Neither side knows storage rows or widget aliases.

## Completeness Boundary

Completeness is local shape, not legality.

A nested node control checks that its required typed fields can materialize.
An outgoing batch checks its doors, exits, selection, and batch-authored state.
A Biome Plan checks its root, tree invariants, terminal shape, biome-scoped
state, and every occurrence referenced by the tree.

Completeness includes generated but unselected nodes because they represent
rooms and rewards created by the game. Those nodes must be locally complete,
but they must be dead leaves.

Completeness does not decide:

- room eligibility at the generation phase;
- `MaxCreationsThisRun` or other generation limits;
- force pressure;
- reward legality or bag availability;
- NPC, encounter, or feature legality;
- depth and history timing.

Those are validator responsibilities.

## Route Scope

History accepts complete biome prefixes only:

```text
Underworld: F
Underworld: F, G
Underworld: F, G, H
Underworld: F, G, H, I
```

A biome is atomic at this boundary. If `Underworld_F` is incomplete, later
Underworld biome plans cannot contribute to history. The route aggregate owns
this prefix rule; individual Biome Plan controls do not infer route order.

## Nested Control Interface

Room templates expose a consistent occurrence interface. Exact names may vary,
but the contract is:

```lua
nodeControl:isComplete(context) -> completion
nodeControl:materialize(context) -> canonicalFragment
nodeControl:exportCandidates(out, context)
nodeControl:applyFeedback(feedback)
nodeControl:draw(draw, context) -> changed
nodeControl:reset(reason)
```

Outgoing batches and biome-scoped editors expose equivalent operations for
their own semantics.

The template owns translation between semantic aspects and its internal
components. A route validator never selects a dropdown or mutates storage on
the template's behalf.

## Dual Addressing

Every materialized authored fact carries both semantic source and planner
location.

Semantic source uses game-domain language:

```lua
source = {
    routeKey = "Underworld",
    biomeKey = "F",
    gameRoomKey = "F_Combat02",
    aspect = "generatedTargetReward",
    slot = 1,
}
```

Planner location identifies the occurrence owner:

```lua
location = {
    biomeControlId = "Underworld_F",
    nodeId = 17,
    parentNodeId = 12,
    doorIndex = 2,
}
```

Only fields relevant to the fact are present. Biome-scoped findings may omit
`nodeId`; node-local findings may omit parent and door; batch findings target
the parent node and may name a peer door.

Game room key alone is never a sufficient return address because the same room
declaration may occur multiple times.

## Candidate Ownership

The semantic owner of a choice owns its candidate provider:

- an outgoing batch owns target-room, selection, and batch-state candidates;
- a node template owns reward, payload, encounter, shop, and room-local
  candidates;
- the Biome Plan owns biome-scoped candidates;
- the route aggregate owns route-prefix and navigation candidates.

Providers expose stable values and labels plus mutable presentation arrays:

```lua
provider = {
    key = "generatedTargetReward",
    version = 12,
    values = stableValues,
    labels = stableLabels,
    hidden = mutableHidden,
    colors = mutableColors,
    messages = mutableMessages,
}
```

Candidate export emits semantic records plus the dual address. The generic
walker asks the owner to export; it does not inspect the owner's storage or
switch on widget/template names.

## Feedback Application

Validators return findings and candidate results with the original source and
location.

```lua
{
    code = "target_room_does_not_match_exit",
    severity = "invalid",
    source = { ... },
    location = { ... },
    providerKey = "nextDoorTarget",
    providerVersion = 12,
    candidateKey = "F_Story01",
    payload = { ... },
}
```

Feedback application is:

```text
biomeControlId
-> Biome Plan control
-> node, outgoing batch, or biome-scoped owner
-> owner.applyFeedback(...)
-> provider/component/widget decoration
```

Provider feedback applies only when the provider version matches. A mismatch
marks evaluation dirty instead of applying stale indexes.

Feedback may mutate hidden/color/message arrays and participant-level status.
It must not write authored plan state.

## Presentation Policy

Declaration-time impossible options may be absent from stable provider values.
Context-invalid options remain visible and are colored invalid unless the
failed rule explicitly owns a hide policy.

Downstream content after the first blocking invalid may be greyed or inactive.
Enrichment colors appear only when the complete route scope is valid. Inline
invalid labels are not a second reporting system; route status and markers own
invalid reporting.

Incomplete local fields produce completeness findings. They do not enter game
validation as invented canonical facts.

## Generic Walker Contract

The topology walker owns traversal and phase ordering. It does not know the
internal shape of `StandardCombat`, `FieldsCombat`, `ShipCombat`, or other room
templates.

For every node it:

1. resolves the room declaration and registered template;
2. asks the nested control for completeness, canonical state, and candidates;
3. processes the parent-owned outgoing batch and all generated peers;
4. follows the selected or ordered continuation;
5. preserves the returned source and location on emitted facts.

Template-specific history interpretation lives in registered template
materializers/interpreters, not a central template-name switch.

## Non-Goals

The control layer does not:

- simulate route legality during draw;
- compute reward bags or history counters;
- use game room keys as occurrence identities;
- expose storage table rows as feedback addresses;
- require validators to know template internals or widget aliases;
- materialize unresolved `Auto`, `Vanilla`, `Major`, or `Minor` roles.

## Supporting Docs

- `BIOME_PLAN_CONTROL_MODEL.md` owns topology and semantic ownership.
- `FORM_STORAGE_ROUNDTRIP.md` owns physical persistence and reset behavior.
- `UI_IMPLEMENTATION_ORDER.md` owns implementation sequencing.
- `../validation/VALIDATION_MODEL.md` owns legality and candidate evaluation.
- `../model/CANONICAL_PLAN.md` owns canonical plan shape.
