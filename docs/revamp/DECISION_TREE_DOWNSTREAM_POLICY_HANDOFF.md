# Decision-Tree Downstream Policy Handoff

## Status

This is a temporary handoff for the next active Run Planner work item. It
records accepted direction, current implementation behavior, and the design
questions that must be settled before changing topology commands. It is not a
second architecture authority. Once the policy is implemented and validated,
reconcile the decisions into `UI_PERSISTENCE_MODEL.md`, `UI_EDITOR_MODEL.md`,
`IMPLEMENTATION_GUIDE.md`, and `IMPLEMENTATION_PROGRESS.md`, then remove this
file.

Current branch: `codex/planner-revamp`.

Relevant completed commits:

- `0927826 feat(topology): make targets replacement-only`;
- `9403d49 feat(rewards): make leaf choices total`;
- shell pointer `48697dd chore(submodules): update Run Planner`.

## Current Work Item

Define and implement the edit contract for preserving a decision tree after
an upstream authored choice changes.

The current command implementation assumes that a changed selected start,
picked target, or picked exit invalidates all dependent topology and deletes
it immediately. That behavior is safe but too destructive for an editor. A
user changing an interchangeable opening room should not have to recreate the
entire biome tree. The editor should retain authored work, expose the resulting
invalid state, and let validation plus subsequent user edits repair it.

The goal is minimal authored change, not automatic topology repair. Commands
may update the structural ownership necessary to keep retained state attached,
but they must not choose new rooms, invent exits, solve eligibility, or silently
make the plan valid.

## Already Locked

### Topology targets are monotonic

A topology target has this lifecycle:

```text
unspecified -> specified -> replaced
                         -> removed with its owning decision or topology
```

Once a target exists, it cannot be emptied independently. It must be replaced
by another concrete Room Control, or its owning decision must be deleted. The
two-stage room selector may browse with transient sentinels, but those
sentinels never become authored target deletion.

This invariant is implemented and has passed in-game testing.

### Leaf values are total

Active focused Room Control leaves start from declaration-owned complete
defaults and only replace concrete values. This is now implemented. Downstream
topology work must not reset or rewrite Room Control persistence.

### Retention is the default

Ordinary replacement commands should retain downstream authored topology even
when the replacement makes it invalid. Destructive behavior belongs to
explicit destructive commands:

- `RemoveBatch`, presented as `Remove From Here`;
- `ClearTopology`, presented as clearing the biome;
- explicit continuation-form replacement where the old form cannot coexist
  with the new form.

Replacing a room or picked exit is not an implicit `Remove From Here`.

### Temporary invalidity is expected

The editor may retain:

- downstream rooms that become contextually ineligible;
- a continuation whose new parent has a different exit shape;
- a terminal outcome that is no longer legal for its new predecessor;
- reward choices that make later rooms invalid.

History, materialization, and execution must remain blocked until the biome is
complete and valid. The editor should preserve and display repairable authored
state instead of deleting it.

### An upstream room cannot become empty

A selected room may be replaced. A decision may be explicitly deleted. An
ordinary replacement must never leave the selected spine with an empty room.
This prevents a disconnected tree caused merely by clearing an upstream
selector.

## Current Implementation Divergence

`src/mods/route/topology/linear_biome_commands.lua` currently performs these
destructive edits:

| Command | Current behavior | Desired direction |
| --- | --- | --- |
| `SelectStart` | Clears every batch, target, and terminal transition when the start changes | Retain the tree and re-anchor only the first decision ownership required by the new start |
| `SetTarget` on the picked target | Calls `clearAfterBatch` before replacing the room | Replace the room and retain its dependent continuation |
| `SetPicked` | Deletes everything after the batch before changing the picked exit | Change the selected continuation and retain the existing dependent continuation |
| `RemoveBatch` | Deletes this batch and all dependent topology | Keep; this is the explicit destructive action |
| `ClearTopology` | Clears all layout-owned authored state | Keep; this is the explicit biome reset |
| `ReplaceWithTerminalTransition` | Removes the batch and downstream topology before installing the terminal form | Keep the explicit form replacement, but revisit compatible-state preservation for I when that biome is implemented |

The current normalized topology is keyed by semantic Room Control identity:

- a batch is owned by `parentRoomControlKey`;
- targets repeat that parent key plus `exitIndex`;
- a terminal transition is owned by its predecessor Room Control key.

Therefore retaining descendants cannot mean leaving their old owner keys
untouched. That would create a genuinely disconnected tree. The likely
operation is an atomic semantic re-anchor from the replaced selected Room
Control key to the new one, while preserving child targets, the picked choice,
and later decisions. This is not yet locked because exit-shape changes make the
required boundary behavior important.

## Cases the Policy Must Cover

### Replacing the selected start

F opening rooms are structurally interchangeable today. Changing
`F_Opening01` to `F_Opening02` should preserve the first generated decision and
all later topology. The command likely needs to re-anchor the first batch and
its target owner keys from the old start control to the new start control.

Do not model this as an empty start followed by a new selection, and do not
recreate targets from candidate defaults.

### Replacing the picked room on one exit

If the picked target room changes, retain the dependent continuation rather
than clearing it. The immediate child batch or terminal transition must remain
attached to the selected spine, which likely requires replacing its predecessor
owner key atomically.

Unpicked peer targets remain unchanged. Their Room Control state remains
untouched.

### Changing which exit is picked

`SetPicked` should retain the existing continuation and associate it with the
newly picked target instead of deleting it. This produces a valid structural
attachment but may produce contextual invalidity, which later validation owns.

The old target remains a concrete unpicked dead leaf. The new target becomes
the selected continuation. Neither target is cleared.

### Expanding the predecessor exit count

Replacing a selected room with a room that has more physical exits is
straightforward:

- retain targets for the exits that still exist;
- retain the picked target and downstream continuation when its exit remains;
- expose the additional exits as unspecified;
- report the decision incomplete until the user fills them.

No new target is selected automatically.

### Shrinking the predecessor exit count

This is the primary unresolved representation issue. Existing targets may now
occupy exits the replacement room does not physically possess, and the picked
target may be one of them.

The rejected policies are:

- silently deleting those targets;
- clearing the picked target;
- hiding the continuation as dormant or suspended.

The intended UX is visible but unavailable/invalid retained state. The exact
domain representation is not locked. Before implementation, decide how the
Biome Plan boundary, normalized topology, projector, and later validator will
represent an authored target on a no-longer-available exit without treating it
as corrupt persistence.

This distinction matters:

- malformed storage remains a contact-boundary failure;
- a well-formed but physically impossible authored edit should be projectable
  and repairable through feedback.

Do not weaken all contact validation to achieve this. Define the retained
invalid shape explicitly.

### Retaining a terminal transition

Changing an upstream selected room may leave a terminal transition attached to
the former predecessor. Leaving that stale owner key is not acceptable, while
deleting the terminal outcome violates retain-by-default.

The likely direction is to re-anchor the transition to the replacement
predecessor and allow validation to report that the terminal outcome is no
longer eligible. The policy still needs an explicit decision for predecessor
exit-shape changes, especially I's terminal companion targets and the forked
preboss active free-reward capacity.

F/G can establish the common re-anchoring contract without prematurely
implementing I-specific companion behavior.

### Unique Room Control collisions

Top-level Room Controls remain injective inside one biome topology. A retained
replacement must not create two references to the same Room Control. Decide
whether the selector excludes already referenced controls or the semantic
command rejects the collision. Do not introduce occurrence identities or
positional Room Control instances to solve it.

## Ownership Constraints

The implementation must preserve these boundaries:

- the Biome Plan command layer owns topology mutation;
- the layout codec owns physical bounded persistence;
- the normalized topology uses game/domain identity, not rendered row indexes;
- the UI only translates interactions into semantic commands;
- Room Controls own their leaf persistence and are never reset by topology
  edits;
- validation reports contextual illegality and never mutates the tree;
- history and materialization consume only complete, valid biome snapshots.

Avoid a general positional edit document. Any re-anchoring helper should work
from the selected source and semantic Room Control keys, with layout-specific
logic kept in the `LinearBiome` command implementation.

## Recommended Implementation Order

1. Add command-layer tests that capture current destructive behavior before
   changing it, then rewrite them around retain-by-default.
2. Implement equal-exit-shape re-anchoring for `SelectStart`, picked
   `SetTarget`, and `SetPicked` in F/G.
3. Prove that unpicked peers, later batches, terminal transitions, and every
   Room Control leaf value survive those edits.
4. Settle and document the explicit retained-invalid representation for exit
   shrinkage before changing normalization or the projector.
5. Add expansion and shrinkage tests, including a picked target on an exit
   that disappears.
6. Reconcile terminal-transition re-anchoring for common LinearBiome behavior;
   defer I companion specialization until I's implementation slice.
7. Update the UI projection so retained invalid exits remain visible and
   editable without introducing a second positional authority.
8. Reconcile the authoritative docs and progress tracker, then remove this
   handoff.

Primary production/test files:

- `src/mods/route/topology/linear_biome_commands.lua`;
- `src/mods/route/topology/linear_biome.lua`;
- `src/mods/ui/layouts/linear_biome.lua`;
- `src/mods/ui/layouts/linear_biome_draw.lua`;
- `tests/TestBiomePlan.lua`;
- `tests/TestUiEditor.lua`.

## Acceptance Gate

The work item is complete when:

- replacing an interchangeable F start retains the authored tree;
- replacing the picked room or picked exit retains its continuation;
- increasing exit count preserves existing exits and exposes only new missing
  targets;
- decreasing exit count preserves and visibly reports unavailable authored
  targets according to one explicit model;
- retained terminal outcomes remain attached and repairable;
- only `Remove From Here`, clear-biome, and explicit incompatible
  continuation-form replacement destroy topology;
- no command clears a concrete target independently;
- no topology edit resets a Room Control;
- malformed persisted state still fails at the contact boundary;
- command, projection, reload, and in-game interaction coverage pass.

## Out of Scope

- automatic eligibility repair;
- choosing replacement rooms or rewards for the user;
- history, validator, feedback, or execution-plan implementation beyond the
  minimum representation seam required for visible retained invalid state;
- I companion, N hub, or O ship specialization unless a common contract cannot
  be established without them;
- undo/redo or general revision history.
