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
- `Choose Other Door`
- `Choose Picked Door reward count`
- `Choose combat count`
- `Choose Side 1 encounter difficulty`
- `Choose wheel choices for 1st Encounter`
- `Unknown room type: <stored key>`
- `Unknown room option: <stored key>`

Status:

- Normal incomplete state now uses local UI vocabulary rather than route,
  topology, or sibling implementation terms.
- Unknown-value messages still expose raw stored keys. That is intentional for
  corrupted/debug state, but the route-status path should keep marking them as
  form-completion warnings rather than route validity errors.
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
- rule-specific messages from variant/reward validators through catalog codes
- sibling structural messages, rendered by the feedback message catalog

Status:

- Generic selected-candidate invalids no longer synthesize display text inside
  the validator.
- `role_limit` and `option_limit` use candidate/declaration labels when
  available and fall back to generic `Room type` / `Room`, not raw keys.
- Sibling structural failures emit code-only findings and render text through
  the route feedback message catalog.
- Reward-type payloads resolve labels through reward primitives when a catalog
  template uses `{rewardLabel}`.
- Unknown generic candidate codes fall back to `Selection is not valid`.

Remaining gaps:

- Keep newly added rule-specific candidate validators on the same catalog-code
  path.
- Add new payload resolvers only when future candidate messages need labels for
  reward-adjacent concepts beyond the reward type itself.

### Picked Room Structure Validation

Source:

- `src/mods/route/history/validator/biome_structure/picked_entries.lua`
- `src/mods/route/history/validator/biome_structure/route_requirements.lua`

Previous messages:

- `Room is not valid at this generated depth`
- `Previous planned room only leads to <required next-room tag label>`
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
- `previous_room_next_tags` resolves declaration-owned tag labels through the
  biome declaration, with the raw tag retained only as a fallback.

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
- Validators carry structured payloads such as `generatedCount`,
  `requiredGeneratedCount`, and `deadlineBiomeDepthCache`.
- Route feedback renders those counts in force/deadline messages so the status
  explains how much generated pressure was missing.

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

Current route-status messages are catalog-authored:

- `Trial requires at least two prior planned god rewards`
- `Trial requires 15 rooms since the previous Trial`
- `Selene's Gift cannot be planned after a shop Selene's Gift offer`
- `Path of Stars rewards require an earlier Selene's Gift`
- `Hermes can only be planned twice per route`
- `The second Hammer cannot be planned before the third biome`

Status:

- Selected-legality declarations carry stable rule identity via `code` and
  structured requirement data.
- Reward validators emit code + payload and do not copy authored `message`
  fields into findings/invalids.
- Route feedback renders reward legality text through
  `src/mods/route/history/feedback/message_catalog.lua`.
- Reward legality messages can use `{rewardLabel}` to display the selected
  reward primitive label.
- Unknown selected-legality requirement kinds now raise a contract failure
  instead of silently passing validation.

Current gaps:

- Related-event labels still depend on route-feedback location formatting.

Recommended fix:

- Keep declarations focused on rule identity and game-domain requirement data.
- Extend route feedback payload resolvers if reward messages need richer
  related-event locations or labels for concepts beyond reward type.

### NPC Validation

Source:

- `src/mods/route/history/validator/npcs.lua`
- `src/mods/route/history/feedback/npcs.lua`

Current messages:

- `<NPC label> needs Disabled or a target biome`
- `<NPC label> needs a target room`
- `<NPC label> target is no longer valid`
- `Only one NPC encounter can use the same room`
- `<NPC label> is too close to another planned NPC`

Status:

- NPC snapshots carry `npcLabel`, and NPC validators emit code + payload
  instead of authored raw-key messages.
- Route feedback renders NPC message text from the shared message catalog.
- NPC route-status locations use `NPC <label> Row N` when a label is present,
  with `NPC Row N` as the fallback.

Remaining fix:

- NPC labels are currently slot labels from the control. If per-biome NPC slot
  labels become more specific later, route status will pick them up from the
  snapshot without changing the validator.

### Missing Control / Assembly Boundary

Source:

- `src/mods/route/run_context/feedback.lua`
- `src/mods/route/run_context/overview.lua`

Previous message:

- `Missing route control: <biomeKey>`

Status:

- This is a boundary failure, not a normal planner error.
- Missing route controls now raise a route-control invariant failure instead of
  producing a user-facing route-status marker.
- A completed biome completion report with no `biomeKey` also raises an
  invariant failure. Incomplete reports remain user feedback and are routed
  through the completion marker path.
- Unknown route keys now raise a route-context invariant failure instead of
  constructing a synthetic route-status marker.

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

Status: implemented for generic candidate messages, picked-entry structure
messages, NPC messages, sibling candidate messages, and selected-legality /
reward constraint messages.

Move generic candidate messages from validators into a message translator.

Translator inputs:

- `record.code` / `record.reason`
- `record.kind`
- labels already carried on candidates/findings
- declaration lookup for room/reward/NPC labels

This pass should remove raw `roleKey`, `optionKey`, `roomKey`, and `npcKey`
from ordinary user-facing messages as each validator path is migrated.

Route/history validators should emit `code` plus structured payload. The
feedback catalog owns normal route-status prose. Template completion records
remain the one explicit-message exception because incomplete form copy is local
to the control template.

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

- any message path that currently returns raw `reason`

These should become load/test failures or explicit invariant failures, not
normal route-status text.

## Remaining Slices

- Continue migrating any newly added route/history validators to catalog codes
  instead of authored messages.
- Keep form-completion copy local, but do not let non-completion route
  validation records carry `message`.
