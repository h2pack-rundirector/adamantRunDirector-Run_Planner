# Decision-Tree Downstream Policy Handoff

## Status

The downstream-retention policy is locked and implemented for the common
`LinearBiome` F/G slice. Focused command, normalization, structural-check,
projection, draw-command, codec, and reload coverage must remain green. The
file is retained only until the pending Checkpoint 4A in-game interaction probe
confirms the repair flow; then remove it because the authoritative contracts
now live in `UI_PERSISTENCE_MODEL.md`, `UI_EDITOR_MODEL.md`,
`IMPLEMENTATION_GUIDE.md`, and `IMPLEMENTATION_PROGRESS.md`.

## Implemented Contract

- `SelectStart`, replacement of a picked `SetTarget`, and `SetPicked` retain
  downstream topology and atomically re-anchor its semantic owner keys.
- Unpicked peers and every Room Control's private persistence remain untouched.
- Expansion preserves existing targets and exposes only genuinely new exits as
  unspecified.
- Shrinkage retains targets above the new physical exit count inside the
  biome-wide bounded topology. Structural checking reports them as unavailable;
  they are not malformed persistence and do not reach materialization or the
  route validator.
- An unavailable picked target keeps its continuation attached. No command
  chooses a surviving exit automatically. The user must pick an available exit,
  and `SetPicked` re-anchors the retained continuation.
- `ReconcileExitCapacity` is an explicit destructive repair. It is rejected
  while an unavailable target is picked and otherwise removes only unavailable
  target references without resetting their Room Controls.
- Restoring capacity before reconciliation reactivates retained targets.
- `RemoveBatch`, `ClearTopology`, terminal removal, and explicit incompatible
  continuation-form replacement retain their intentionally destructive
  semantics.
- Injective Room Control identity remains enforced by prepared selector domains
  and full-proposal normalization. Expansion itself creates no target and
  cannot introduce a collision.

## Deferred Specialization

This slice does not implement I's terminal-companion mutation policy. The
common semantic re-anchoring and retained-unavailable representation are the
foundation for that later biome slice, but `terminalWithCompanions` must receive
focused implementation and probes with I.

## Remaining Probe

In game, verify this sequence without accepting any automatic selection or
silent deletion:

1. author a two-exit decision with a picked continuation and terminal;
2. replace its parent with a one-exit room;
3. confirm the overflow target and attached continuation remain visible and the
   reconciliation action is unavailable;
4. pick the available exit and confirm the continuation re-anchors;
5. reconcile and confirm only overflow target references disappear;
6. repeat the shrink but restore a two-exit parent before reconciliation and
   confirm retained targets reactivate.
