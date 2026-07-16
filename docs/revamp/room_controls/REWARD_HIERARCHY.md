# Reward Hierarchy

Status: review draft. Do not replace the current reward-control prototype until
this contract and the consumer audit are reviewed and locked.

## Purpose

Reward-control implementation follows the validated reward catalog from the
bottom up. It does not begin with a generic shop-like "store choice," and it
does not create a public component type for every bag/filter combination.

```text
payload domains
  -> reward primitives
       -> counted reward bags
            -> concrete producer bindings
                 -> compiled immutable choice views
                      -> structural reward components
                           -> Room Control templates

reward primitives
  -> shop option sets
       -> shop profiles
            -> shop components
                 -> Shop and Preboss Room Controls
```

Counted bags and Charon shops share concrete reward primitives but remain
different domain branches.

All layers below a Room Control are ordinary injected Lua collaborators. They
are not nested Lib controls and own no independent profile identity. The Room
Control flattens their bounded persistence into its own private storage.

## Declaration Vocabulary

`RunProgress`, `MetaProgress`, `HubRewards`, and the other declarations in
`rewards.bags` are counted reward bags. A concrete reward value retains its
game-language `storeKey` because offer history and bag simulation require the
exact bag identity.

A reward surface is a behavioral shape:

- `none`;
- `fixed`;
- `countedChoice`;
- `shop`;
- `localSlots`;
- `incomingKind`;
- `offerPoint`.

Stores and filters configure those shapes. They do not create new surface
identities. There is therefore no public `RunProgressNoDevotionChoice`,
`TartarusBoonOnly`, `TartarusNoBoonChoice`, or similar component taxonomy.

The exact binding for every supported producer is recorded in
[`REWARD_CONSUMER_AUDIT.md`](REWARD_CONSUMER_AUDIT.md).

## Layer 1: Payload Domains

A payload domain defines only its authored payload shape and local rules. The
current catalog has two domains:

| Domain | Shape | Completeness |
| --- | --- | --- |
| `BoonSource` | `{ source = "ApolloUpgrade" }` | one declared source |
| `DevotionPair` | `{ sources = { "ApolloUpgrade", "ZeusUpgrade" } }` | two declared, distinct sources |

A payload collaborator owns:

- its maximum private field shape;
- typed read and semantic write;
- membership and distinctness checks;
- payload completeness;
- later payload candidate translation.

It does not know bags, filters, room identity, topology, history, or widgets.
Empty private strings normalize to absent typed members.

## Layer 2: Reward Primitives

A reward primitive combines a concrete `rewardType` with its payload domain
and acquisition normalization:

```text
Boon
  -> BoonSource payload

Devotion
  -> DevotionPair payload

MaxHealthDrop
  -> no payload

RandomLoot
  -> BoonSource payload
  -> acquiredAs Boon
```

The primitive collaborator owns the concrete typed fragment:

```lua
{ rewardType = "MaxHealthDrop" }

{
    rewardType = "Boon",
    payload = { source = "ApolloUpgrade" },
}
```

Fixed facts consume no persistence. Payload-bearing primitives delegate their
fields and behavior to the declared payload collaborator. `acquiredAs` affects
normalized acquisition history, not authored identity or storage.

System composition may construct immutable payload-free primitive
collaborators from declarations. Unknown payload domains fail during
composition.

## Layer 3: Counted Reward Bags

A bag collaborator is constructed from one validated bag declaration and the
primitive registry. Current bags are:

- `RunProgress`;
- `MetaProgress`;
- `HubRewards`;
- `SubRoomRewards`;
- `SubRoomRewardsHard`;
- `TartarusRewards`;
- `TyphonBossRewards`.

The bag collaborator owns:

- exact primitive membership and entry multiplicity;
- ordered, deduplicated authored option enumeration;
- dispatch from selected `rewardType` to its primitive collaborator;
- entry requirement metadata;
- refill and counted-history behavior used later by validation.

Repeated bag entries and entry requirements do not duplicate UI options or
private authored fields. A bag collaborator does not know which room filters
it or which structural producer consumes it.

## Layer 4: Concrete Producer Bindings

Every counted producer declares its complete store and filter facts:

```lua
reward = {
    kind = "countedChoice",
    storeKeys = { "RunProgress", "MetaProgress" },
    eligibleRewardTypes = nil,
    ineligibleRewardTypes = { "Devotion" },
}
```

The same descriptor nests inside structural producers:

```lua
reward = {
    kind = "localSlots",
    maxSlots = 3,
    choice = {
        kind = "countedChoice",
        storeKeys = { "RunProgress" },
        ineligibleRewardTypes = { "Devotion" },
    },
    constraints = { "UniqueNonBoonRewardTypes", "UniqueBoonSources" },
}
```

The declaration parser validates:

- known bags and primitive filter members;
- dense, duplicate-free store and filter lists;
- no overlap between positive and negative filters;
- every eligible primitive belongs to at least one referenced bag;
- the complete explicit shape required by the producer kind.

The normalized binding contains resolved filters. Room Controls do not follow
biome inheritance, read game data, or merge filters.

## Layer 5: Compiled Immutable Choice Views

Assembly compiles each counted binding once:

```text
allowed primitives
  = union(store bag membership)
  intersect eligibleRewardTypes, when present
  subtract ineligibleRewardTypes
  subtract declaration-time structural impossibilities, when proven
```

The result is an anonymous immutable descriptor:

```lua
{
    kind = "countedChoice",
    storeKeys = { "TartarusRewards" },
    allowedRewardTypes = { "Boon" },
    payloadCapacity = { sourceCount = 1 },
}
```

This descriptor owns:

- static store and option lookup tables;
- dispatch to the selected bag and primitive collaborators;
- the union private field capacity required by allowed primitives;
- typed read, semantic write, and local completeness;
- later declaration-derived candidate enumeration.

Equal descriptors may share cached option tables or the complete collaborator.
Such sharing is an internal optimization, not declaration identity. Controls
depend only on their injected compiled descriptor.

Filters are not recalculated during draw. History-dependent entry
requirements do not narrow the compiled option domain; they remain contextual
validation. A structural requirement may narrow the domain only when assembly
can prove it invariant for every supported occurrence of that producer.

## Counted Choice Value

A counted choice returns one concrete tagged value:

```lua
{
    storeKey = "RunProgress",
    rewardType = "Boon",
    payload = { source = "ApolloUpgrade" },
}
```

Logical persistence is minimized from the compiled descriptor:

```lua
{
    storeKey = "",   -- omitted when exactly one store is possible
    rewardType = "",
    source1 = "",    -- omitted when no allowed primitive needs it
    source2 = "",    -- omitted when Devotion is impossible
}
```

This is one tagged reward value, not dormant child selections per store.
Changing the selected store replaces the active reward atomically. Payload
capacity required by another allowed primitive remains persisted but dormant.

The typed value always includes the resolved concrete `storeKey`, even when
the store is declaration-fixed and consumes no field.

## Layer 6: Structural Reward Components

Structural components compose fixed or compiled counted bindings without
redefining primitive semantics.

### Fixed and absent rewards

- `none` contributes no reward and no persistence.
- `fixed` embeds one primitive and persists only its payload, if any.
- Story and Clockwork Goal are payload-free fixed primitives.
- forced O Devotion embeds the Devotion primitive and persists its pair.

A fixed reward does not borrow requirements from a same-named counted bag
entry.

### Fields cages

`localSlots` owns bounded cage keys and delegates every cage to the same
compiled RunProgress binding with the BaseH Devotion exclusion. The wrapper
owns active slots and semantic addresses. The Fields batch validator owns
cross-cage uniqueness.

### Ephyra side rooms

Each declared side slot contains its exact SubRoomRewards or
SubRoomRewardsHard counted binding. The Ephyra parent owns generation state
and entered order; the child binding owns only its reward value.

### Clockwork branch

`incomingKind` owns the Goal/NonGoal branch:

```text
Goal    -> fixed ClockworkGoal
NonGoal -> counted TartarusRewards with ineligible Boon
```

The wrapper persists the branch key and bounded NonGoal storage. Only the
active branch participates in completeness and materialization.

### Ship wheels

Each `offerPoint` owns one shared store selection, bounded offer count,
concrete offers from that selected store, and picked index. Its counted
binding references RunProgress and MetaProgress without a room-declared
Devotion filter.

The O one-exit context proves the Devotion entry requirement unsatisfiable for
every supported wheel. Assembly may therefore remove Devotion from the wheel's
compiled domain and omit its second source capacity while retaining structural
requirement provenance.

All offers on one wheel share the selected store. Separate wheels may select
different stores. The final active wheel's store supplies the initial default
for the room's outgoing door batch.

### Forked preboss offers

Each free slot contains a RunProgress counted binding with Devotion and gold
excluded. The preboss wrapper owns active free-slot count and entry mode from
committed predecessor context. It does not alter the child reward domain.

## Separate Shop Branch

Shops begin from the primitive registry but do not use counted bags:

```text
reward primitives
  -> shop option set
       -> semantic shop slot
            -> shop profile
                 -> shop component
```

Each shop slot persists one concrete primitive plus `purchased`:

```lua
{
    reward = {
        rewardType = "RandomLoot",
        payload = { source = "ApolloUpgrade" },
    },
    purchased = true,
}
```

No shop value contains a counted-bag `storeKey`. Purchase affects acquisition;
it is not bag consumption. `WorldShop`, `I_WorldShop`, and `Q_WorldShop` remain
profile-parameterized compositions over declared option sets.

## Persistence Composition

The parent Room Control assigns stable private prefixes and flattens component
fields into one Lib storage declaration.

Examples after binding compilation:

| Use | Persisted choice fields |
| --- | --- |
| unfiltered RunProgress/MetaProgress target | store key, reward type, source 1, source 2 |
| P/Q combat target | store key, reward type, source 1 |
| F combat 01 | reward type, source 1 |
| opening reward | reward type, source 1 |
| Boon-only miniboss | source 1 |
| preboss free reward | reward type, source 1 |
| Fields cage | reward type, source 1 |
| fixed Devotion | source 1, source 2 |

Storage minimization is static schema, not dynamic allocation. Every concrete
control instance receives its complete bounded layout during assembly and
retains it across profiles and reset.

Private field names do not appear in typed values, materialization, candidate
payloads, feedback addresses, or views.

## Completeness Composition

```text
payload complete
  -> primitive complete
       -> selected counted choice complete
            -> every active structural child complete
                 -> Room Control locally complete
```

Local completeness checks authored shape and compiled declaration membership.
History-dependent bag availability, requirements, peer constraints, and route
legality remain validator work after the biome is otherwise complete.

An incomplete typed value preserves every authored member. No layer replaces
it with `nil`, invents a default, or clears dormant siblings.

## Candidate Composition

Checkpoint 4 builds candidates bottom-up:

- payload collaborators expose valid payload values;
- primitive collaborators produce concrete primitive candidates;
- compiled counted views expose their allowed primitives and store tags;
- structural components attach slot, branch, shared-store, or picked identity;
- the Room Control attaches its semantic owner address.

Candidate application sends the concrete semantic value back through the same
component chain. No candidate handler writes storage fields, dropdown indexes,
or generic address strings.

History-aware candidate validation is prepared during the committed derived
pipeline. Draw consumes the prepared candidate set.

## Constraint Ownership

| Rule | Owner |
| --- | --- |
| source belongs to payload domain | payload collaborator |
| Devotion sources are distinct | DevotionPair payload collaborator |
| primitive belongs to referenced bag | bag collaborator |
| positive/negative filter is well formed | declaration parser |
| compiled domain applies declared filters | counted-binding compiler |
| selected child is locally complete | counted or structural component |
| one shared store across one Ship wheel | Ship wheel component |
| generated-door default and target store resolution | biome door-batch validator |
| repeated non-Boon rewards across Fields cages | route validator |
| unique Boon sources across Fields cages | route validator |
| Hub reward peer uniqueness | route validator |
| Summit primary-slot uniqueness | route validator |
| bag entry requirement and refill history | history/materialization validator |
| offer acquisition and bag consumption | canonical materialization/history |

Lower components do not pull peer or history state into typed read/write to
make a selection appear valid.

## System Composition

Systems owns the hierarchy:

```text
Systems
  -> payload-domain registry
  -> primitive registry
  -> counted-bag registry
  -> counted-binding compiler and immutable view cache
  -> shop option sets and profiles
  -> structural reward components
  -> Room Control templates
  -> explicit template registry
  -> control assembly
```

```text
validated catalog
  -> compileRewardBindings(catalog.rewards, catalog.rooms)
  -> createControlTemplates(rewardServices)
  -> createControlsAssembly(controlTemplates)
```

Leaf modules do not import the catalog or locate sibling services. Control
assembly binds each normalized reward descriptor to its compiled collaborator
and injects it into the owning template.

The system graph is created once. Draw performs no component construction,
filtering, option enumeration, or descriptor allocation.

## Implementation Sequence

After this document is reviewed and locked:

1. replace named surface references with explicit producer bindings from the
   consumer audit;
2. update catalog validation and compile immutable per-binding descriptors;
3. remove the generic `store_choice.lua` prototype;
4. implement payload-domain and primitive collaborators;
5. implement counted bags and the binding compiler;
6. reimplement StandardCombat against its injected compiled binding;
7. verify per-instance storage manifests and typed APIs;
8. implement structural and shop components only as their first consuming
   Room Control slice requires them.

Candidates, feedback, canonical materialization, draw views, and history
simulation remain in their existing later checkpoints.

## Acceptance Questions

This hierarchy is ready to implement when review agrees that:

- surfaces represent behavior rather than filtered option sets;
- concrete producers own their stores and positive/negative filters;
- compiled choice views are anonymous immutable artifacts;
- payload ownership and per-instance storage capacity are complete;
- counted bags remain distinct from shops;
- structural wrappers own only their local coordination;
- local components do not validate history or peers;
- the consumer audit covers every supported producer;
- Systems is the only composition root for the hierarchy.
