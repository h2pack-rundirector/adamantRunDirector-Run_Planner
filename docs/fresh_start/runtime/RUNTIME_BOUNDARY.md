# Runtime Boundary

## Purpose

Runtime is the final consumer of a validated route. It should not re-solve
room, reward, shop, or candidate decisions.

The guiding rule is:

```text
Validated history is the source of truth.
Execution plan is a concrete instruction stream.
Runtime hooks only apply those instructions to game generation.
```

## Inputs

Runtime compilation receives:

- complete canonical plan;
- declarations;
- materialized history;
- validation success;
- configured route scope.

If the route is incomplete or invalid, no runtime execution plan should be
compiled. Runtime should never be asked to interpret a partial invalid route.

## Outputs

The compiler produces an execution plan:

```lua
executionPlan = {
    routeKey = "Underworld",
    scope = {
        configuredBiomeCount = 2,
    },
    biomes = {
        {
            biomeKey = "F",
            instructions = {
                ...
            },
        },
    },
}
```

Instructions are concrete and callback-oriented:

- choose this generated room for this door;
- assign this reward offer to this generated door;
- assign this shop profile and shop offer set;
- assign this encounter-local O wheel reward;
- assign this H cage batch reward set;
- suppress or ignore planner control outside configured scope.

The runtime plan should not contain unresolved values such as Auto, Vanilla,
Major, Minor, random reward class, or unknown target room.

## Compile Boundary

Execution plan compilation is a pure translation from validated history to
runtime instructions.

Compilation may index history into callback-friendly maps, but it should not
change decisions:

```text
history room/generated-door/reward facts
  -> compile
execution instruction lookup tables
```

Examples:

```lua
nextRoomInstruction = {
    currentRoomKey = "F_Combat03",
    exitIndex = 1,
    targetRoomKey = "F_MiniBoss02",
}
```

```lua
rewardInstruction = {
    offerPointId = "...",
    store = "RunProgress",
    rewardType = "Boon",
    payload = { source = "AphroditeUpgrade" },
}
```

The compiler can derive stable lookup keys from history phases and source
addresses, but it should not invent new route semantics.

## Runtime Hook Responsibilities

Runtime hooks are adapters between game callbacks and execution instructions.

They may:

- find the current instruction for the current game callback;
- force a target room key;
- force a reward type and payload;
- force a shop option set;
- disable out-of-scope planner intervention;
- log mismatches between expected and actual game context.

They must not:

- evaluate room eligibility;
- evaluate reward legality;
- simulate reward bags;
- pick random fallback rooms or rewards;
- infer missing plan data;
- repair malformed instructions;
- re-run validation.

If runtime sees a missing instruction inside configured scope, that is a plan
compile or hook-position bug. It should fail or log loudly instead of falling
back silently.

## Matching Game Callbacks

Runtime instructions should be organized around game generation moments:

- room generation / door assignment;
- reward generation for generated doors;
- reward generation for H cage rewards;
- O ship wheel reward generation;
- N hub door reward generation;
- shop option generation;
- preboss shop/free-reward generation.

The hook should use the narrowest callback that matches the instruction's game
phase. For example, O wheel rewards should be applied at the wheel reward
generation point, not by pretending the O room has one normal door reward.

## Scope Behavior

Configured scope is a route prefix.

Inside configured scope:

- runtime applies instructions exactly;
- missing or mismatched instructions are errors.

Outside configured scope:

- runtime should stop forcing planner decisions;
- vanilla game behavior resumes;
- planner history does not pretend to know those future rooms or rewards.

This is the only intentional relaxation in the fresh model. The planned prefix
is strict; the unconfigured suffix is absent.

## History To Instruction Mapping

History facts should map mechanically into runtime instructions.

`GeneratedDoorHistory`
: room target instructions and generated door reward instructions.

`RewardOfferHistory`
: reward forcing instructions for generated offers.

`LootHistory`
: not usually forced directly; used by validation and possibly diagnostics.

`RoomHistory`
: expected entered-room order and callback synchronization.

`EncounterHistory`
: O wheel timing and encounter-local reward instructions.

`ShopOfferHistory`
: shop option instructions and bought/unbought state for diagnostics.

Runtime should primarily consume offer and generated-door histories. It should
not need to inspect form drafts.

## Reward Runtime Rules

Reward runtime consumes concrete offers:

```lua
{
    rewardType = "Devotion",
    payload = {
        sources = { "ApolloUpgrade", "PoseidonUpgrade" },
    },
}
```

The runtime hook can translate payload into game fields such as forced loot
name, devotion source pair, or shop item name.

Reward bags are not simulated in runtime. The planner already validated that
the forced offer can exist at that point. Runtime only applies the forced
result.

## Diagnostics

Runtime diagnostics should compare the active game context to the plan:

- expected current room key;
- expected generated exit count;
- expected offer point kind;
- expected reward store/profile;
- expected selected instruction index;
- configured scope state.

Diagnostics should help locate hook-position or data-model drift. They should
not paper over drift with fallback logic.

## Out-Of-Scope Runtime Features

These should remain out of runtime until their data model exists:

- Chaos gate insertion/detour routing;
- NPC/feature forcing if the fresh planner has not modeled them yet;
- surface-shop purchase side effects not represented in history;
- active bounty reward store overrides unless declared and validated;
- profile/save-state requirement overrides unless declared.

## Contract Rules

- Runtime only consumes validated execution plans.
- Execution plans contain concrete instructions.
- Missing instruction inside configured scope is an error.
- Unknown instruction kind is an error.
- Runtime does not run candidate evaluation.
- Runtime does not run reward bag simulation.
- Runtime does not choose fallback rewards or fallback rooms.
- Runtime hooks should stay smaller than the planning layer.

## Supporting Docs

- `../model/CANONICAL_PLAN.md` owns the complete route data shape.
- `../pipeline/TIMELINE_EVENTS.md` owns generation phases.
- `../validation/VALIDATION_MODEL.md` owns route validity.
- `../model/REWARD_MODEL.md` owns reward offers and bag simulation.
