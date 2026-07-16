# Reward Consumer Audit

## Purpose and Status

This audit maps every supported reward-producing context to its producer
behavior, counted bags or shop profile, room-owned reward filters, and
structural requirements.

Verification date: 2026-07-16.

The declaration and catalog reconciliation described by this audit is
implemented. The audit remains the binding authority for the bottom-up reward
components that will replace the current prototype. It is not a runtime
game-data reader.

Primary game sources:

```text
/home/ayyatma/wsl-projects/modding/1GameData/Scripts/LootData.lua
/home/ayyatma/wsl-projects/modding/1GameData/Scripts/RewardData.lua
/home/ayyatma/wsl-projects/modding/1GameData/Scripts/RewardLogic.lua
/home/ayyatma/wsl-projects/modding/1GameData/Scripts/RoomLogic.lua
/home/ayyatma/wsl-projects/modding/1GameData/Scripts/RequirementsLogic.lua
/home/ayyatma/wsl-projects/modding/1GameData/Scripts/RoomDataF.lua
/home/ayyatma/wsl-projects/modding/1GameData/Scripts/RoomDataG.lua
/home/ayyatma/wsl-projects/modding/1GameData/Scripts/RoomDataH.lua
/home/ayyatma/wsl-projects/modding/1GameData/Scripts/RoomDataI.lua
/home/ayyatma/wsl-projects/modding/1GameData/Scripts/RoomDataN.lua
/home/ayyatma/wsl-projects/modding/1GameData/Scripts/RoomDataO.lua
/home/ayyatma/wsl-projects/modding/1GameData/Scripts/RoomDataP.lua
/home/ayyatma/wsl-projects/modding/1GameData/Scripts/RoomDataQ.lua
```

## Modeling Decision

A reward surface describes producer behavior and UI shape. A filtered reward
domain is not a new surface.

An ordinary room-level counted reward uses one declaration shape:

```lua
incomingReward = {
    kind = "countedChoice",
    storeKeys = { "TartarusRewards" },
    eligibleRewardTypes = { "Boon" },       -- explicit positive filter
    ineligibleRewardTypes = {},              -- empty means no negative filter
}
```

The concrete room or structural producer owns `storeKeys` and both explicit
filter lists. An empty list means that the corresponding filter does not narrow
the store domain.
Catalog assembly compiles that binding into one immutable per-instance choice
view. It may internally cache equal views, but combinations such as
"Tartarus plus Boon-only" or "RunProgress without Devotion" have no public
surface key, component type, module, or DI identity.

Other behavior remains structurally distinct:

```lua
{ kind = "none" }
{ kind = "fixed", rewardType = "Story" }
{ kind = "shop", shopProfileKey = "WorldShop" }
{ kind = "localSlots", choice = <countedChoice>, ... }
{ kind = "incomingKind", kinds = { ... } }
{ kind = "offerPoint", choice = <countedChoice>, ... }
```

Structural wrappers contain ordinary fixed or counted bindings rather than
referencing a separately named filtered surface.

## Filter Semantics

The game applies filters to concrete `reward.Name` values:

```text
effective declared domain
  = union of referenced counted bags
  intersect eligibleRewardTypes, when present
  subtract ineligibleRewardTypes
```

The normalized catalog validates that:

- every store and reward type exists;
- every eligible type is offered by at least one referenced store;
- eligible and ineligible lists contain no duplicates or overlap;
- filters are immutable declaration data, not authored UI state;
- every normalized room or structural child exposes its complete resolved
  filter without requiring the control to follow inheritance at runtime.

These fields filter reward primitives only. A Boon-source restriction is a
payload-domain filter and must not be encoded as an eligible/ineligible reward
type.

## Picker Contract

The effective authored reward domain is derived in this order:

1. the producer selects or fixes a counted reward bag, sometimes once for an
   entire offer batch;
2. the concrete room's resolved positive and negative filters apply;
3. bag-entry requirements filter remaining entries against route history and
   picker context;
4. `ChooseRoomReward` selects and consumes one eligible bag entry;
5. payload setup, such as the concrete Boon source or Devotion pair, occurs
   after the reward type is selected.

`ForcedReward` is a separate producer. `ChooseRoomReward` returns it before
the counted-bag eligibility loop. A fixed forced reward therefore does not
become legal by weakening the requirements on a same-named bag entry.

The planner preserves each source of narrowing:

- store membership comes from the counted binding;
- positive and negative filters come from the room or structural producer;
- fixed structural impossibility may be proven during assembly;
- history-dependent requirements remain validator work;
- fixed or forced values validate their own payload and structural rules;
- draw consumes the compiled domain and recalculates none of these facts.

## Generated-Door Store Resolution

For ordinary generated doors, Room start prepares one default store.
`DoUnlockRoomExits` creates every target, scans their `ForcedRewardStore`
values in door order, and lets each valid forced store replace the working
batch default. Reward generation then resolves each target as follows:

1. `IndividualRewardStore` wins for that target;
2. otherwise its own valid `ForcedRewardStore` wins;
3. otherwise it uses the final working batch default.

Room Controls own their concrete counted bindings and tagged rewards. The
Biome Plan's door-batch validation owns this shared/default-store resolution.
A Ship wheel is different: all peer offers live inside one structural
component, so the wheel owns its shared store directly.

## Consumer Mapping

`--` means no positive or negative reward-type filter. Structural requirements
are recorded separately even when they make one reward type permanently
impossible in the supported context.

### F: Erebus

| Consumer | Kind | Stores/profile or fixed reward | Eligible | Ineligible |
| --- | --- | --- | --- | --- |
| `F_Opening01..03` | counted choice | RunProgress | -- | Devotion, RoomMoneyDrop, MaxHealthDrop, MaxManaDrop |
| `F_Combat01` | counted choice | RunProgress | -- | Devotion |
| `F_Combat02..22` | counted choice | RunProgress, MetaProgress | -- | -- |
| `F_MiniBoss01..03` | counted choice | RunProgress | Boon | -- |
| `F_Reprieve01` | counted choice | RunProgress, MetaProgress | -- | Devotion |
| `F_Story01` | fixed | Story | -- | -- |
| `F_Shop01` | shop | WorldShop | -- | -- |
| free offers of `F_PreBoss01` | counted choice | RunProgress | -- | Devotion, RoomMoneyDrop |
| shop realization of `F_PreBoss01` | shop | WorldShop | -- | -- |

`F_Combat01` unconditionally fixes RunProgress and excludes Devotion. Its
save-progression-dependent forced Boon source remains outside the supported
planner model, but those unconditional facts remain declaration data.

### G: Oceanus

| Consumer | Kind | Stores/profile or fixed reward | Eligible | Ineligible |
| --- | --- | --- | --- | --- |
| `G_Intro` | none | -- | -- | -- |
| `G_Combat04/05/07/08` | counted choice | RunProgress, MetaProgress | -- | Devotion |
| other `G_Combat01..20` | counted choice | RunProgress, MetaProgress | -- | -- |
| `G_MiniBoss01..03` | counted choice | RunProgress | Boon | -- |
| `G_Reprieve01` | counted choice | RunProgress, MetaProgress | -- | Devotion |
| `G_Story01` | fixed | Story | -- | -- |
| `G_Shop01` | shop | WorldShop | -- | -- |
| free offers of `G_PreBoss01` | counted choice | RunProgress | -- | Devotion, RoomMoneyDrop |
| shop realization of `G_PreBoss01` | shop | WorldShop | -- | -- |

The four listed combat rooms and the fountain do not fix RunProgress, so
MetaProgress remains a valid selected store despite their Devotion exclusion.

### H: Mourning Fields

| Consumer | Kind | Stores/profile or fixed reward | Eligible | Ineligible |
| --- | --- | --- | --- | --- |
| `H_Intro` | none | -- | -- | -- |
| each cage value in `H_Combat01..15` | counted local slot | RunProgress | -- | Devotion |
| `H_MiniBoss01..02` | counted choice | RunProgress | Boon | -- |
| `H_Bridge01` | fixed | Story | -- | -- |
| free offers of `H_PreBoss01` | counted choice | RunProgress | -- | Devotion, RoomMoneyDrop |
| shop realization of `H_PreBoss01` | shop | WorldShop | -- | -- |

BaseH fixes `IndividualRewardStore = "RunProgress"` and excludes Devotion.
The initial room reward and additional cage rewards are selected with the same
room copy, store, filters, and `rewardsChosen` batch. `FieldsOptionalRewards`
is the separate random bonus-spawn bag and is not one of the authored door
cage values modeled by the control.

### I: Tartarus

| Consumer | Kind | Stores/profile or fixed reward | Eligible | Ineligible |
| --- | --- | --- | --- | --- |
| `I_Intro` | none | -- | -- | -- |
| Goal branch of `I_Combat01..24` | fixed branch | ClockworkGoal | -- | -- |
| NonGoal branch of `I_Combat01..24` | counted branch | TartarusRewards | -- | Boon |
| `I_MiniBoss01..02` | counted choice | TartarusRewards | Boon | -- |
| `I_Reprieve01` | counted choice | TartarusRewards | -- | Devotion |
| `I_Story01` | fixed | Story | -- | -- |
| canonical `I_PreBoss02` | shop | I_WorldShop | -- | -- |

BaseI fixes TartarusRewards. `I_BaseCombat` excludes Boon, whereas the two
supported miniboss rooms inherit the Tartarus store and allow only Boon. The
store provenance must remain exact even though a Boon payload has the same
shape in RunProgress and TartarusRewards.

### N: Ephyra

| Consumer | Kind | Stores/profile or fixed reward | Eligible | Ineligible |
| --- | --- | --- | --- | --- |
| `N_Opening01`, `N_PreHub01` | counted choice | RunProgress | -- | Devotion, RoomMoneyDrop, MaxHealthDrop, MaxManaDrop |
| ordinary `N_CombatXX` incoming reward | counted choice | HubRewards | -- | -- |
| `N_Combat12`, `N_Combat17` incoming reward | counted choice | HubRewards | -- | WeaponUpgrade, HermesUpgrade |
| ordinary side-room value | counted local slot | SubRoomRewards | -- | -- |
| heavy side-room value | counted local slot | SubRoomRewardsHard | -- | -- |
| `N_MiniBoss01..02` | counted choice | RunProgress | Boon | -- |
| `N_Story01` | fixed | Story | -- | -- |
| `N_PreBoss01` | shop | WorldShop | -- | -- |

`HubCombatRoomEasyBans` also lists Devotion and `HephaestusUpgrade`. Devotion
is not present in HubRewards. `HephaestusUpgrade` is a Boon source name, not a
Hub bag reward name, and the game does not pass this room list into
`ChooseLoot` when it later chooses the Boon source. Neither adds an effective
reward-type filter to the supported planner declaration.

### O: Thessaly

| Consumer | Kind | Stores/profile or fixed reward | Eligible | Ineligible | Structural requirement |
| --- | --- | --- | --- | --- | --- |
| `O_Intro` | none | -- | -- | -- | -- |
| each active Ship wheel | counted offer point | RunProgress, MetaProgress | -- | -- | Devotion entry requires two exits; O has one |
| `O_Devotion01` | fixed | Devotion | -- | -- | forced reward bypasses bag entry requirements |
| `O_MiniBoss01..02` | counted choice | RunProgress | Boon | -- | -- |
| `O_Reprieve01` | counted choice | RunProgress, MetaProgress | -- | Devotion | -- |
| `O_Story01` | fixed | Story | -- | -- | -- |
| `O_Shop01`, `O_PreBoss01` | shop | WorldShop | -- | -- | -- |

The Ship wheel calls `ChooseNextRewardStore` once before iterating its reward
obstacles. Every offer on that wheel shares one selected RunProgress or
MetaProgress bag; peer offers cannot use different stores.

The wheel has no room-declared Devotion exclusion. Devotion is impossible
because the RunProgress bag entry requires at least two currently offered
exits and every supported O room has one physical `ShipsExitDoor`. Assembly
may use that fixed structural proof to omit impossible Devotion payload
capacity, but it must not rewrite the fact as `ineligibleRewardTypes`.

`O_Devotion01` instead declares `ForcedReward = "Devotion"`, which returns
before bag-entry requirements. Its fixed Devotion binding must not validate
`DevotionLootRequirements`.

Room start prepares the later outgoing door-batch store. Every wheel refreshes
that value. The final active wheel supplies the initial base store for the
outgoing O batch before the target forced-store prepass. `wheel1` supplies it
when Combat2 is absent; `wheel2` supplies it when Combat2 is active. A later
forced target can replace the working default. The control exports its wheel
stores, while the Biome Plan validates outgoing targets.

### P: Mount Olympus

| Consumer | Kind | Stores/profile or fixed reward | Eligible | Ineligible |
| --- | --- | --- | --- | --- |
| `P_Intro` | none | -- | -- | -- |
| `P_Combat01..19` | counted choice | RunProgress, MetaProgress | -- | Devotion |
| `P_MiniBoss01..02` | counted choice | RunProgress | Boon | -- |
| `P_Reprieve01` | counted choice | RunProgress, MetaProgress | -- | Devotion |
| `P_Story01` | fixed | Story | -- | -- |
| `P_Shop01` | shop | WorldShop | -- | -- |
| free offers of `P_PreBoss01` | counted choice | RunProgress | -- | Devotion, RoomMoneyDrop |
| shop realization of `P_PreBoss01` | shop | WorldShop | -- | -- |

Every supported P room inherits BaseP's Devotion exclusion unless it provides
a stronger compatible filter. The normalized concrete room binding carries
the resolved result.

### Q: Summit

| Consumer | Kind | Stores/profile or fixed reward | Eligible | Ineligible |
| --- | --- | --- | --- | --- |
| `Q_Intro` | counted choice | RunProgress | -- | Devotion, RoomMoneyDrop, MaxHealthDrop, MaxManaDrop |
| modeled `Q_Combat01..09`, `Q_Combat12..16` | counted choice | RunProgress, MetaProgress | -- | Devotion |
| `Q_MiniBoss02..05` | counted choice | TyphonBossRewards | -- | -- |
| `Q_PreBoss01` | shop | Q_WorldShop | -- | -- |

Every supported Q room inherits BaseQ's Devotion exclusion. TyphonBossRewards
does not contain Devotion, so the inherited exclusion does not narrow that
bag and need not be copied into the effective binding.

## Compiled Choice Views

Catalog assembly resolves each counted binding into an immutable descriptor:

```lua
{
    kind = "countedChoice",
    storeKeys = { "TartarusRewards" },
    allowedRewardTypes = { "Boon" },
    payloadCapacity = { sourceCount = 1 },
}
```

This descriptor is an implementation artifact, not a declaration identity.
Equal descriptors may share cached option tables and collaborators. Controls
receive the resolved descriptor through Systems composition and never locate
bags or reinterpret filters themselves.

Static structural proofs may narrow `allowedRewardTypes` further for a
specific producer. History-dependent requirements do not: they remain
contextual candidate and selected-value validation.

## Persistence Consequences

Assembly computes stable maximum payload capacity per concrete control
instance from the compiled domain:

| Effective domain | Payload capacity per reward |
| --- | --- |
| includes Devotion | two sources |
| excludes Devotion but includes Boon | one source |
| Boon-only | one source |
| payload-free rewards only | no source fields |

The capacity is declaration-time schema, not dynamic allocation. Ordinary
target rewards whose legal parent context can vary retain capacity for every
potentially legal reward. The Ship wheel may omit Devotion capacity because
its one-exit structural impossibility is fixed for every supported instance.

## Declaration Reconciliation Status

The declaration authority switch is complete:

- named filtered surface references and the global surface registry are gone;
- every room embeds its complete `incomingReward`; local side rooms,
  incoming-kind branches, offer points, and forked preboss free offers embed
  their complete locally named bindings;
- catalog validation recursively checks every embedded producer kind, store,
  filter, shop profile, constraint, and nested binding;
- the biome-O exception is removed from `DevotionLootRequirements`.

The remaining hierarchy implementation must:

1. compile each counted binding once during control assembly;
2. apply bag-entry requirements only to bag-backed provenance;
3. preserve generated-door store resolution and O's final-wheel outgoing-store
   dependency during batch validation and materialization;
4. derive per-instance persistence capacity from the compiled domain instead
   of selecting a named filtered component.

## Lock Conditions

The reward model is ready to implement when:

- every supported producer has the stores and filters recorded by this audit;
- surfaces identify behavior, not filtered option sets;
- normalized declarations expose complete resolved filters;
- reward-type filters and payload-domain filters remain distinct;
- bag entry requirements are not applied to fixed/forced rewards;
- each Ship wheel and generated-door batch enforces its shared-store contract;
- Room Controls consume compiled descriptors and do no filter interpretation
  during draw.
