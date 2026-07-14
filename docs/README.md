# Run Planner Docs

The locked revamp design under `revamp/` is the sole architecture and
implementation-guidance authority for the clean Run Planner rewrite. Begin
with `revamp/README.md` and follow its declared reading order.

The superseded `system_design/` and `progress/` trees are preserved on the
`codex/fresh-planner-spine` branch and in Git history. They are intentionally
absent from the live rewrite branch so searches cannot confuse them with the
revamp model.

## Game Data References

- `gameinfo/FORCE_AT_BIOME_DEPTH_AUDIT.md`: vanilla force-depth behavior.
- `gameinfo/PHYSICAL_EXIT_TOPOLOGY_AUDIT.md`: physical exit counts by biome.
- `gameinfo/rewardbag.txt`: community reward-bag reference notes.

These files are audit evidence rather than design authority. Harvest or remove
them as the executable catalog is built.
