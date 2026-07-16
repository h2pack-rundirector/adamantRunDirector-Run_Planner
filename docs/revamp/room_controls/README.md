# Room Control Specifications

## Purpose

This directory specifies the concrete authored-state contract for every
registered Room Control template before the templates are implemented.

The authority documents in the parent directory still own domain, game-data,
persistence, biome, materialization, and implementation rules. These files
apply those rules to individual templates. If a specification conflicts with
an authority document, the authority document wins and this specification
must be corrected before implementation.

## Common Boundary

Every supported top-level room has one static Lib control instance. Its
registered template owns only room-local authored state:

- the concrete reward offered for entering the room;
- reward payload values;
- bounded shop, cage, side-room, and encounter-offer state;
- semantic reads and UI-only mutations for that state;
- later completeness, materialization, candidate, and feedback translation.

Room Controls never own outgoing topology, generated peers, physical exit
selection, picked continuation, eligibility, force pressure, or route/biome
counters. A Room Control may read immutable declaration facts needed to
describe its own fragment, but it does not persist them.

The room-control key is the Lib instance name and semantic owner:

```text
biomeStepKey + concrete game room suffix

Underworld_F + Combat04 -> Underworld_F_Combat04
```

One instance is created for every concrete room declaration. Instances are
catalog-generated; they are not duplicated in handwritten registration code.
Template behavior is handwritten and explicit.

## Common Instance Descriptor

Control assembly resolves the validated catalog into an immutable descriptor
before Lib prepares the instance:

```lua
{
    template = "StandardCombat",
    routeKey = "Underworld",
    biomeStepKey = "Underworld_F",
    gameRoomKey = "F_Combat04",
    roomKind = "Combat",
    rewardSurface = <validated resolved descriptor>,
    encounterProfile = <validated resolved descriptor>,
    localSlots = <validated bounded descriptors>,
    metadata = <template-relevant immutable facts>,
}
```

The control subsystem assembly performs catalog lookup and dependency
injection. Template modules and reusable components do not leaf-import the
catalog.

## Common Ref Contract

The runtime and UI refs expose a typed authored read:

```lua
control:read() -> template-specific authored state
```

This is a room-local authored value, not the canonical biome record. At
Checkpoint 4 the template materializer separates `generatedReward` from the
typed `roomState`, adds semantic source addresses, and returns both to the
Biome Plan materializer. Control identity, game-room identity, topology, and
canonical provenance are not duplicated into private persistence.

The UI ref extends that contract with game-language mutation operations. It
does not expose the current generic API:

```lua
control:read("reward")
control:write("offer.wheel1.1", value)
```

Private Lib fields may remain flattened, but neither coordinators nor views
address them by generated alias. A template's own view may request its typed
field adapters from its UI ref.

Expected semantic mutation families are:

| Owned state | UI operation family |
| --- | --- |
| incoming reward | `setGeneratedReward(reward)` |
| fixed reward payload | `setGeneratedRewardPayload(payload)` |
| shop slot | `setShopReward(slotKey, reward)`, `setShopPurchased(slotKey, purchased)` |
| branch surface | `setRewardMode(mode)` |
| cage | `setCageReward(slotKey, reward)` |
| Clockwork offer | `setIncomingReward(kind, reward)` |
| Ephyra side room | `setSideGeneration`, `setSideEnteredOrder`, `setSideReward` |
| Ship phase/wheel | `setEncounterCount`, `setWheelOfferCount`, `setWheelOffer`, `setWheelPick` |
| forked preboss entry | `setEntryMode`, `setFreeReward` |

Exact method names may be normalized during implementation, but these are
semantic operations. No caller writes an internal field or dropdown index.

Checkpoint 2 implements storage and typed UI/runtime reads and writes.
Checkpoint 4 adds completeness, canonical materialization, candidate export,
and candidate application. Checkpoint 6 adds production views. Storage must be
complete now for every later operation; later checkpoints must not require a
schema migration.

## Reward Components

[`REWARD_COMPONENTS.md`](REWARD_COMPONENTS.md) defines the reusable authored
reward shapes used by the templates. Components are ordinary injected Lua
collaborators, not nested Lib controls. A room template explicitly selects and
configures its components.

## Template Specifications

| Template | Controls | Specification | Primary local shape |
| --- | ---: | --- | --- |
| `FixedOpening` | 4 | [`FixedOpening.md`](FixedOpening.md) | incoming opening reward |
| `FixedIntro` | 6 | [`FixedIntro.md`](FixedIntro.md) | none or incoming opening reward |
| `FixedPreHub` | 1 | [`FixedPreHub.md`](FixedPreHub.md) | incoming opening reward |
| `EphyraHub` | 1 | [`EphyraHub.md`](EphyraHub.md) | no room-local authored state |
| `StandardCombat` | 56 | [`StandardCombat.md`](StandardCombat.md) | incoming store choice |
| `FieldsCombat` | 15 | [`FieldsCombat.md`](FieldsCombat.md) | three bounded cage rewards |
| `ClockworkCombat` | 24 | [`ClockworkCombat.md`](ClockworkCombat.md) | goal/non-goal incoming reward |
| `EphyraCombat` | 23 | [`EphyraCombat.md`](EphyraCombat.md) | hub reward and side rooms |
| `ShipCombat` | 15 | [`ShipCombat.md`](ShipCombat.md) | optional phase and two wheels |
| `OlympusCombat` | 19 | [`OlympusCombat.md`](OlympusCombat.md) | incoming store choice |
| `Story` | 7 | [`Story.md`](Story.md) | fixed story reward |
| `Fountain` | 5 | [`Fountain.md`](Fountain.md) | incoming store choice |
| `Shop` | 4 | [`Shop.md`](Shop.md) | World Shop slots |
| `Miniboss` | 20 | [`Miniboss.md`](Miniboss.md) | incoming store choice |
| `Devotion` | 1 | [`Devotion.md`](Devotion.md) | fixed Trial with source pair |
| `DirectPreboss` | 4 | [`DirectPreboss.md`](DirectPreboss.md) | profile-selected shop |
| `ForkedPreboss` | 4 | [`ForkedPreboss.md`](ForkedPreboss.md) | contextual shop plus free offers |
| **Total** | **209** | | |

## Cross-Template Acceptance

Before implementation is accepted:

- every concrete catalog room is covered by exactly one specification;
- every observed template/surface/profile/local-slot combination is listed;
- assembly rejects combinations not listed by the owning template;
- every persisted field contributes to an active authored branch or is
  explicitly documented as dormant;
- every active choice has an explicit incomplete representation;
- runtime and UI refs return the same typed authored value;
- runtime refs expose no write operation;
- no template owns topology or reads a private alias from another control;
- fixed facts consume no persistence merely to make the control non-empty.

## Review Order

1. reward components;
2. F/G templates;
3. H/I templates;
4. N/O templates;
5. P/Q variants;
6. exact catalog coverage and storage-manifest comparison;
7. implementation.
