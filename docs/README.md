# Run Planner Docs

The locked revamp design under `revamp/` is the sole architecture and
implementation-guidance authority for the clean Run Planner rewrite. Begin
with `revamp/README.md` and follow its declared reading order.

Current implementation status is tracked separately in
`revamp/IMPLEMENTATION_PROGRESS.md`; the remaining plan lives in
`revamp/IMPLEMENTATION_GUIDE.md`.

The superseded `system_design/` and `progress/` trees are preserved on the
`codex/fresh-planner-spine` branch and in Git history. They are intentionally
absent from the live rewrite branch so searches cannot confuse them with the
revamp model.

## Game Data References

- `gameinfo/FORCE_AT_BIOME_DEPTH_AUDIT.md`: vanilla force-depth behavior.
- `gameinfo/PHYSICAL_EXIT_TOPOLOGY_AUDIT.md`: physical exit counts by biome.
- `gameinfo/rewardbag.txt`: community reward-bag reference notes.

These files are audit evidence rather than design authority. Their room-exit,
force-window, and counted-bag facts are now exercised by the headless catalog
foundation and its coverage tests; they remain useful for future game-data
reverification.
