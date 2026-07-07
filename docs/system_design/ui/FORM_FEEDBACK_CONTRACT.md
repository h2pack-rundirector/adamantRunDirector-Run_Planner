# Form And Feedback Contract

## Purpose

The UI form should author concrete route decisions without becoming a route
validator. The fresh planner keeps form completion, history building,
validation, and feedback as separate responsibilities.

The guiding rule is:

```text
Forms decide whether data is complete enough to materialize.
History and validators decide whether the materialized plan is legal.
Feedback targets form participants, not inner widget aliases.
```

## Draft Form Versus Complete Snapshot

The draft form may contain blanks, partial choices, and local UI state.

When complete, the form emits a strict complete snapshot that can be
materialized into the canonical plan. Complete snapshots must not contain
implicit defaults, unresolved Auto/Vanilla choices, placeholder target rooms,
or incomplete reward selections.

The history builder consumes only complete snapshots. It should not build fake
history for incomplete editable choices.

## Completeness Boundary

Form completion checks are local shape checks:

- required fields are filled;
- referenced local draft choices exist;
- typed room state is materializable;
- reward offer forms resolve to concrete store and reward type;
- generated doors reference concrete target rooms and declared exit indexes.

Form completion must not validate route/game legality:

- room availability at current depth;
- force pressure;
- duplicate generated rooms;
- reward legality;
- reward bag availability;
- NPC/feature legality;
- encounter-depth or room-history spacing.

Those belong to history validation.

## Partial Route Scope

Partial history is not allowed inside a biome. A biome is atomic for history
scope: either its form is complete and contributes to history, or it is
incomplete and contributes only form-completion findings.

Partial route planning is allowed only as a complete biome prefix:

```text
Underworld: F
Underworld: F, G
Underworld: F, G, H
Underworld: F, G, H, I
```

Invalid scopes include:

```text
G without F
F incomplete with G complete
F, H while skipping G
```

The route form owns this prefix rule.

## Form Participants

The UI is composed from small form participants, not biome-sized route engines.

Examples:

- route form;
- biome form;
- room-kind form;
- generated-door form;
- offer-point form;
- reward-offer form;
- shop-offer form;
- side-room child form.

Room-kind and reward forms are polymorphic leaves. Biomes compose them instead
of owning custom route templates for every biome shape.

## Leaf Interface

Leaf forms should expose a small common interface:

```lua
leaf.defaultDraft(context) -> draft
leaf.isComplete(draft, context) -> completion
leaf.materialize(draft, context) -> canonicalFragment
leaf.render(draw, draft, context, feedback) -> changed
leaf.reset(draft, context, reason) -> draft
```

`isComplete` answers whether the local draft can be materialized. It does not
answer whether the result is legal in the run.

`materialize` returns concrete canonical data. It must not invent defaults for
missing required choices.

`render` owns inner widget layout and local mapping from participant feedback
to inner controls.

`reset` handles local cleanup when a parent choice changes.

## Structured Addresses

Form addresses should be structured data, not row strings or UI aliases.

Examples:

```lua
{ routeKey = "Underworld", biomeIndex = 1 }
```

```lua
{ routeKey = "Underworld", biomeIndex = 1, roomIndex = 4 }
```

```lua
{ routeKey = "Underworld", biomeIndex = 1, roomIndex = 4, doorIndex = 2 }
```

```lua
{
    routeKey = "Surface",
    biomeIndex = 1,
    roomIndex = 3,
    childKind = "sideRoom",
    childIndex = 1,
}
```

Leaf-local widget aliases may exist inside the leaf, but they should not be the
language of route validation.

## Builder Source Addresses

While materializing complete snapshots into history, the builder should attach
source addresses to authored facts:

- room entries;
- generated doors;
- offer points;
- reward offers;
- room-kind state facts;
- side-room child facts.

This gives feedback a direct reverse lookup from validation finding to form
participant.

History facts may contain derived game data, but their source address should
refer to the authored participant that produced them.

## Feedback Boundary

Validators emit domain findings with source addresses and payloads.

Feedback translates findings into participant-level markers:

```lua
{
    address = { routeKey = "Underworld", biomeIndex = 1, roomIndex = 4, doorIndex = 2 },
    severity = "invalid",
    code = "target_room_does_not_match_exit",
    message = "...",
    payload = { ... },
}
```

Feedback should not know inner widget aliases such as dropdown keys. If a
finding targets a `FieldsCombat` room participant, the `FieldsCombat` leaf
decides which local control to decorate.

This avoids route feedback doing row arithmetic or reaching into template
internals.

## Candidate And Color Policy

Candidate-owning leaves expose stable candidate provider arrays. They own the
values, labels, and mutable draw-state arrays, but they do not own route/game
validity.

Validation evaluates exported candidate semantics and returns presentation
policies such as hidden, invalid, or warning. Policy belongs to the failed
condition, not to a broad "impossible" category.

Incomplete local fields are form-completion findings, not route-legality
findings.

Downstream content after the first blocking invalid can be greyed or inactive.

Enrichment colors are allowed only when the planned scope is valid.

## Non-Goals

The form layer should not:

- simulate route legality;
- compute reward bag state;
- infer generated doors from compact role/group choices in the canonical plan;
- expose row-based route coordinates as validation language;
- require route feedback to know leaf-local widget aliases.

## Supporting Docs

- `UI_IMPLEMENTATION_ORDER.md` owns production UI build order and draw-state
  constraints.
- `FORM_STORAGE_ROUNDTRIP.md` owns the form-to-draft-to-storage mapping and
  serialization rules.
- `../validation/VALIDATION_MODEL.md` owns candidate evaluation and feedback
  semantics.
- `../model/CANONICAL_PLAN.md` owns canonical plan shape.
