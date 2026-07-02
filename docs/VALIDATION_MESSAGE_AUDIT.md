# Validation Message Audit

## Purpose

Route validation now flows through the history/feedback path, but user-facing
messages still come from several layers. This audit records the current message
sources and the cleanup direction for route-status UX.

The main UX problems are:

- Route-status locations often say generic `Biome Row N`.
- Some messages expose implementation keys such as `F_Shop01`, topology group
  keys, reward keys, NPC keys, or route role keys.
- Validators mix game-domain validation with presentation strings, so message
  quality depends on which validator emitted the first invalid.

## Desired Contract

Validators should emit stable game-domain findings:

- `code`
- structured payload, such as `roomKey`, `roleKey`, `optionKey`,
  `rewardType`, `npcKey`, `formAddress`, `relatedEvents`, `expected`, `actual`
- optional developer-facing details when useful for tests/debugging

Feedback should translate those findings into UI language:

- location labels, such as `Erebus Depth 4`, `Ephyra Row 4 Side 1`,
  `Tartarus Pick 6 Other Door`, or `NPC 2`
- display labels for rooms, rewards, NPCs, gods, topology groups, and controls
- route-status message text

The route-feedback message catalog in
`src/mods/route/history/feedback/message_catalog.lua` owns the dumb
`code -> template + expected payload` mapping. The renderer in
`src/mods/route/history/feedback/messages.lua` fills those payloads and renders
the template. Route marker assembly should call that renderer instead of
embedding message `if/else` chains.

Templates can keep form-completion messages because they own local form
requirements. Even there, they should use labels from declarations rather than
raw keys.

## Current Message Pipeline

### Form Completion

Source:

- `src/mods/controls/form.lua`
- biome template runtimes under `src/mods/controls/*Route/runtime.lua`
- topology form checks under `src/mods/controls/*Route/data/topology.lua`

Examples:

- `Choose a room type`
- `Choose a <role label>`
- `Unknown route role: <roleKey>`
- `Unknown route option: <optionKey>`
- `Choose Side 1 encounter difficulty`
- `Choose wheel choices for 1st Encounter`

Status:

- Mostly acceptable as local form UX.
- Unknown-value messages still expose raw stored keys. That is probably fine
  for corrupted state, but the route-status path should mark them as form
  completion warnings rather than route validity errors.
- Completion locations already use `form.locations.biomeRow(...)`, so they are
  usually richer than validator locations.

### Route Status Location Labels

Source:

- `src/mods/route/history/feedback/route.lua`
- rendered by `src/mods/ui/route_status.lua`

Current behavior:

- `locationLabel(...)` uses biome labels, rendered row labels, child
  `formAddress` labels, generated-offer timing, reward addresses, and NPC row
  labels.

Observed gap:

- Route status still does not name every control/branch; it mostly identifies
  the row, child row, generated offer, and reward address.
- NPC labels are still row-based unless the NPC layer grows richer label
  payloads.

Remaining fix:

- Keep extending the route-feedback location translator from structured
  payloads rather than adding strings in validators.

### Candidate Validation

Source:

- `src/mods/route/history/validator/candidates.lua`
- `src/mods/route/history/feedback/message_catalog.lua`
- `src/mods/route/history/feedback/messages.lua`
- `src/mods/route/history/feedback/route.lua`
- candidate subvalidators under `src/mods/route/history/validator/candidates/`

Current messages are translated at the route-feedback boundary:

- `Room is not valid at this generated depth`
- `Room is not valid at this encounter depth`
- `Previous planned room does not lead to this room`
- `<role label> is already planned`
- `<option label> is already generated`
- `Selection is not valid` for unknown generic candidate codes
- rule-specific messages from sibling/variant/reward validators

Status:

- Generic selected-candidate invalids no longer synthesize display text inside
  the validator.
- `role_limit` and `option_limit` use candidate/declaration labels when
  available and fall back to generic `Room type` / `Room`, not raw keys.
- Unknown generic candidate codes fall back to `Selection is not valid`.

Remaining gaps:

- Some rule-specific sibling/variant/reward messages are still authored in the
  validator layer. Most are readable, but they should be audited for current UI
  vocabulary and raw-key leakage.
- Reward primitive and NPC labels still need broader translation support as
  those layers are ported.

### Picked Room Structure Validation

Source:

- `src/mods/route/history/validator/biome_structure/picked_entries.lua`
- `src/mods/route/history/validator/biome_structure/route_requirements.lua`

Previous messages:

- `Room is not valid at this generated depth`
- `Previous planned room only leads to <required next-room tag> rooms`
- `<variant label> is not valid at this encounter depth`
- `<role label> is already planned`
- `<option label> is already generated`
- `Previous planned room must have at least N exits`
- `Unknown route requirement: <kind>`

Previous leaks:

- Previous-room tags and route requirement kinds can still reach route status.
- `Unknown route requirement` is a contract failure. It should be loud in dev,
  not a normal user-facing route error.

Status:

- Picked-entry generic failures now emit code + payload and use the route
  feedback message catalog for display text.
- Picked variant-depth failures use the dedicated
  `variant_encounter_depth_unavailable` code so the catalog can use a variant
  label payload.
- `previousRoomExitCount` route requirements now emit structured payload:
  `requiredExitCount`, `actualExitCount`, `previousEntryLabel`, and
  `currentEntryLabel`.
- Unknown route requirement kinds now raise a contract failure instead of
  producing a user-facing route-status marker.

Remaining fix:

- `previous_room_next_tags` still renders tag text directly. If tags ever stop
  being user-facing labels, add a tag-label resolver or declaration label map.

### Force Pressure And Deadline Validation

Source:

- `src/mods/route/history/validator/biome_structure/force_pressure.lua`
- `src/mods/route/history/validator/biome_structure/deadlines.lua`

Previous messages:

- `Hard-forced topology needs generated force-window doors`
- `Forced <group.key|topology> deadline needs generated forced doors`
- `Required room missing by deadline`

Previous leaks:

- `group.key` can expose internal topology names. This is the clearest current
  example of implementation language leaking into route status.
- Deadline requirements can also provide declaration-authored messages, but
  default text is generic and does not say which room or door pressure failed.

Status:

- Force groups and deadline requirements now carry declaration-owned display
  labels.
- Force/deadline validators emit code + payload and no authored prose for the
  generic paths.
- Route feedback renders the message from the catalog using declaration-owned
  labels such as `topologyForceLabel`, `topologyGroupLabel`, and
  `deadlineRequirementLabel`.
- Validators also carry structured payloads such as `generatedCount`,
  `requiredGeneratedCount`, and `deadlineBiomeDepthCache` so future route
  status can explain the pressure without changing validator output.

Remaining fix:

- The current message text does not yet render the count payloads. They are
  preserved so future route status can explain how many generated doors were
  missing without changing validator output.

### Clockwork-Specific Validation

Source:

- `src/mods/route/history/validator/biome_structure/rules/clockwork_goal.lua`

Previous messages:

- `Tartarus Preboss cannot appear before Clockwork goals are complete`
- `Tartarus single doors need Goal Room before Clockwork goals are complete`
- `Tartarus generated doors need exactly one Goal Room before Clockwork goals
  are complete`
- `Tartarus post-goal doors need Preboss`

Status:

- Clockwork rule failures now emit code + payload and use the route feedback
  message catalog for display text.
- Tartarus progression labels are declared in biome data and carried as payload:
  `clockworkBiomeLabel`, `clockworkGoalLabel`, `clockworkPrebossLabel`, and
  `clockworkProgressionLabel`.

Remaining fix:

- None for route-status text. The labels can still be tuned in the Tartarus
  declaration if the UI language changes.

### Fields Cage Rule Validation

Source:

- `src/mods/route/history/validator/biome_structure/rules/fields_cage.lua`

Previous message:

- `Sibling combat reward count must match selected combat reward count`

Status:

- Fields Cage rule failures now emit code + payload and use the route feedback
  message catalog for display text.
- The user-facing text now uses `Other Door` / `Picked Door` language.

Remaining fix:

- None for route-status text.

### Reward Legality Validation

Source:

- `src/mods/rewards/declarations/selected_legality.lua`
- `src/mods/route/history/validator/rewards.lua`
- `src/mods/route/history/validator/candidates/rewards.lua`

Current messages are mostly declaration-authored and user-readable:

- `Trial requires at least two prior planned god rewards`
- `Trial requires 15 rooms since the previous Trial`
- `Selene's Gift cannot be planned after a shop Selene's Gift offer`
- `Path of Stars rewards require an earlier Selene's Gift`
- `Hermes can only be planned twice per route`
- `The second Hammer cannot be planned before the third biome`

Status:

- This is the best current shape: rules carry user-facing messages near their
  domain declaration.

Current gaps:

- Requirement evaluation silently ignores unknown `kind` by returning valid.
  That is a contract problem, not a message problem.
- Related-event labels still depend on route-feedback location formatting.

Recommended fix:

- Add loud failure for unknown selected-legality requirement kinds.
- Keep these rule messages, but route feedback should translate related
  locations and reward labels consistently.

### NPC Validation

Source:

- `src/mods/route/history/validator/npcs.lua`
- `src/mods/route/history/feedback/npcs.lua`

Current messages:

- `<npcKey> needs Disabled or a target biome`
- `<npcKey> needs a target room`
- `Selected NPC target is no longer valid`
- `Only one NPC encounter can use the same room`
- `<npcKey> is too close to another planned NPC`

Current leaks:

- `npcKey` is user-visible in required and spacing messages.
- Location labels are route-level generic unless NPC feedback handles the
  marker locally.

Recommended fix:

- NPC snapshot should carry `npcLabel`, or validator should receive NPC
  declaration lookup and add labels to findings.
- Route feedback should support non-biome locations such as `NPC Row 2` or
  `<NPC label>`.

### Missing Control / Assembly Boundary

Source:

- `src/mods/route/run_context/feedback.lua`

Current message:

- `Missing route control: <biomeKey>`

Status:

- This is a boundary failure, not a normal planner error.

Recommended fix:

- Treat as a dev/invariant failure where possible.
- If it must be user-visible, translate `biomeKey` through biome labels.

## Cleanup Plan

### Pass 1: Centralize Location Labels

Status: implemented for route markers.

Add a history-feedback location translator and route all route-status markers
through it.

Minimum support:

- biome label from `biomeLookup`
- row label from `entry.source.slotLabel` or `formAddress.rowIndex`
- child labels:
  - `sideRoom` -> `Side <childIndex>`
  - `hubReturn` -> `Hub Return`
  - `pylonRestore` -> `Pylon Restore`
- reward addresses:
  - `cage:N` -> `Cage Reward N`
  - `side:N` -> `Side N Reward`
  - `encounter:N` -> `Encounter N Reward`
- NPC layer -> `NPC Row N` or NPC label when available

This should fix most `Biome Row N` messages without touching validation logic.

### Pass 2: Centralize Message Translation

Status: implemented for generic candidate messages and picked-entry structure
messages.

Move generic candidate messages from validators into a message translator.

Translator inputs:

- `record.code` / `record.reason`
- `record.kind`
- labels already carried on candidates/findings
- declaration lookup for room/reward/NPC labels

This pass should remove raw `roleKey`, `optionKey`, `roomKey`, and `npcKey`
from ordinary user-facing messages as each validator path is migrated.

### Pass 3: Add Missing Display Metadata

Add labels/messages to declaration metadata that currently only has internal
keys:

- topology forced groups
- deadline requirements
- route requirement declarations if they become broader
- any room topology option that can appear in a route-status message

### Pass 4: Fail Loud On Unknown Rule Kinds

Unknown validation kinds are not user errors. They indicate bad declaration or
validator wiring.

Targets:

- unknown selected-legality requirement kinds
- any message path that currently returns raw `reason`

These should become load/test failures or explicit invariant failures, not
normal route-status text.

## Next Slice

Handle selected-legality/reward messages next. That path still carries
declaration-authored strings and should be moved toward the same code + payload
catalog shape.
