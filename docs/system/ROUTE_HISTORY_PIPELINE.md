# Route History Pipeline

This is the stable design contract for the Run Planner route-history pipeline.
Older migration notes were culled from the docs tree; use git history for
provenance when needed.

## Pipeline

```text
template/form
  -> complete selected snapshot
  -> builder/adapters
  -> selected history ledger
  -> validator walker
  -> validators
  -> feedback
```

The builder and validator do not cooperate mid-build. The builder materializes
selected facts. The validator derives timing, candidates, and legality from the
completed ledger.

## Layer Ownership

| Layer | Owns | Must not own |
| --- | --- | --- |
| Biome declarations | Game-domain facts: room keys, role/option definitions, counter costs, availability, force metadata, topology rules, reward surfaces, timeline entries. | UI state, user storage, route-status wording. |
| Template/form | Storage, rendering, local form completeness, render gates, selected snapshots, form coordinates. | Route legality, depth validation, force pressure, reward legality, NPC legality. |
| Builder/adapters | Translating complete snapshots plus declarations into selected history facts. Adapter-specific traversal is allowed here. | Candidate lists, invalid rows, value states, route-status text, validation decisions. |
| History ledger | Append-only selected route facts and indexes over those facts. | Generated candidate tables, UI decoration state, unresolved form defaults. |
| Validator walker | Timing phases, generated candidates, availability contexts, and step stream over the ledger. | Materializing selected route facts, reading template storage directly, coloring controls. |
| Validators | Game legality: selected rooms, candidates, route requirements, deadlines, force pressure, rewards, NPCs. | UI layout, template storage, message formatting. |
| Feedback | Translating findings to template/form coordinates, value states, markers, route status, inactive horizon. | Route legality, topology inference, timing reconstruction. |

## Hard Rules

- Do not attach generated candidate tables to history entries.
- Do not store `entry.phases` on materialized history entries.
- Do not default incomplete editable rows inside adapters.
- Do not let templates decide route legality.
- Do not let feedback infer route timing or generated topology.
- Do not use one row coordinate for all timing axes.
- Do not add compatibility shims for old snapshots unless released persisted
  state explicitly requires them.

If a snapshot is incomplete, route context returns completion feedback and does
not build fake history.

## Selected Snapshot Contract

Snapshots record user choices and fixed slot state in template language.

They should:

- preserve selected keys and blanks;
- include form addresses for controls that can receive feedback;
- include active rows and active child controls only;
- use keys, not resolved declaration objects;
- omit labels, computed counters, candidate tables, invalid rows, and value
  states.

Templates may normalize only declaration-owned fixed/single-option slot state.
Editable blank choices stay blank so form completion can stop the build at the
boundary.

## Builder Contract

The builder:

- walks configured biomes in route order;
- reads one complete snapshot per biome;
- looks up the biome declaration;
- dispatches to the declaration adapter;
- emits selected room entries and selected topology facts;
- emits selected loot facts over emitted room entries;
- appends declaration timeline entries after a built biome.

Adapters may have biome-specific traversal. For example, HubPylon can emit hub,
pylon, side-room, restore, and return entries. That traversal still produces the
same selected ledger language.

## History Ledger

The ledger is the route spine. A room entry represents a room the player
actually entered. Generated choices hang off the current room as topology.

For current row `i`:

```text
entry i = current room actually entered
entry i.topology.picked = generated door selected for row i + 1
entry i.topology.sibling(s) = generated doors not taken from row i
entry i + 1 = next room actually entered
```

That duplication is intentional. The current room records what vanilla
generated. The next room records what the player entered.

## Timing Contract

Route timing follows `ROUTE_TIMING_MODEL.md`.

For one current room:

1. Enter the room.
2. Start the encounter and increment `biomeEncounterDepth` / run encounter
   depth when the encounter counts.
3. Emit the current room entry.
4. Apply the current room reward.
5. Evaluate generated next rooms and next rewards using the offer phase:
   - encounter depth sees the current encounter counted;
   - reward state sees the current reward collected;
   - `biomeDepthCache` is still pre-leave;
   - `roomHistoryOrdinal` is still pre-leave.
6. Attach generated topology to the current entry.
7. Leave the room and commit `biomeDepthCache` / room-history costs.

## Validator Walker Contract

The walker reads the completed ledger and declarations and creates validation
steps. A step may contain:

- selected entry and selected declaration role/option;
- entry, generated, and offer timing contexts;
- room candidates;
- sibling/other-door candidates;
- variant candidates;
- reward candidates;
- generated topology exits.

Candidate factories receive explicit contexts from the walker. They must not
fall back to entry timing when an availability context is missing.

## Validator Contract

Validators consume walker steps and query APIs. They emit game-domain findings
with stable codes and payloads.

Targeting rules:

- selected/current-room validity targets the entered room entry;
- picked-next validity targets the generated picked door and carries render
  coordinates for the current row;
- other-door validity targets the sibling candidate on the current row;
- reward validity targets the reward address on the entered room unless the
  reward is explicitly generated branch metadata;
- force/deadline validity targets the current room that generated or failed to
  generate the required doors.

Force pressure walks the same step stream as room eligibility. A missed exact or
deadline force candidate is valid only when every generated door is occupied by
another active legal force candidate.

## Feedback Contract

Feedback maps validator findings back to UI language. It may use:

- `formAddress`;
- `rowIndex` for same-row controls;
- `renderRowIndex` for picked-next controls rendered on the current row;
- `siblingIndex` and sibling structure keys;
- reward addresses and control aliases;
- `controlTargets` for selected blank controls.

Feedback owns labels and route-status message rendering. Validators own the
facts behind those messages.

## Active Companion Docs

- `ROUTE_TIMING_MODEL.md`: vanilla timing and counter phase authority.
- `BIOME_DEPTH_AUDIT.md`: per-biome counter and room-cost reference.
- `../wip/REWARD_GENERATION_MODEL.md`: reward bag and topology design notes.
- `../wip/VALIDATION_MESSAGE_AUDIT.md`: message cleanup state and remaining
  slices.
