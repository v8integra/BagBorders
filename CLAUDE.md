# BagBorders (working title — rename before publishing)

A World of Warcraft: Forever addon that visually distinguishes individual bags when the player has "Combined Bags" (single-bag) mode enabled.

## Problem Statement

Forever's bag UI has a toggle between showing each equipped bag as a separate frame, or merging them into a single combined view. In combined mode, item slots from different physical bags are laid out contiguously with no visual boundary — making it hard to tell where one bag ends and another begins. This is a minor inconvenience normally, but becomes a real usability issue when the player is carrying a specialty bag (e.g., a hunter's quiver or ammo pouch) mixed in with general bags, since there's no way to tell at a glance which slots belong to the specialty bag.

## Target Environment

- **Game**: World of Warcraft: Forever
- **Beta build tested against**: 1.60.1.69893
- **API family**: Retail/Midnight-era API (`C_Container`, `C_Item`, namespaced calls) — confirmed via the same source verification used for the TrailBeacon project.
- **Source reference**: `https://github.com/Gethe/wow-ui-source/tree/forever`. The relevant bag/container UI source in this branch lives at `Interface/AddOns/Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua`, with a small Forever-specific override file at `Interface/AddOns/Blizzard_UIPanels_Game/Camelot/ContainerFrame.lua`. ("Camelot" appears to be Forever's internal codename in the client's folder structure — not a public Blizzard term, just useful for navigating the source tree.) Consult this source directly for exact function signatures rather than assuming from general WoW addon knowledge, since Forever's bag code has Forever-specific overrides layered on top of the shared Mainline implementation.

### Confirmed relevant API / hook points (verified against the branch above)

- **Combined bags mode detection**: `ContainerFrameSettingsManager:IsUsingCombinedBags()` — this is the actual name of the "single bag" mode referenced in the problem statement.
- **The combined view frame**: `ContainerFrameCombinedBags` (mixin: `ContainerFrameCombinedBagsMixin`).
- **Per-slot bag origin (critical hook point)**: `ContainerFrameMixin:UpdateItemSlots()` builds every item button in the combined view by looping each equipped bag and calling `itemButton:Initialize(bag, slotID)`. This means **every item button already knows its originating bag** via `itemButton:GetBagID()` — no need to reconstruct slot-to-bag mapping manually; just read it off each button.
- **Update lifecycle hook**: `ContainerFrameCombinedBagsMixin:Update()` — hook this via `hooksecurefunc` (non-invasive, runs after Blizzard's own update logic) to re-apply our border coloring whenever the combined bag view refreshes (on open, on item move, on bag change, etc.).
- **Slot counts**: `C_Container.GetContainerNumSlots(containerIndex)` → total slots for a given bag index.
- **Free slot counts + bag family**: `C_Container.GetContainerNumFreeSlots(bagIndex)` → returns both `numFreeSlots` and `bagFamily` in one call. This is likely the primary source for both the slot-count tracker AND the special-bag-type detection (see below) — check whether a second lookup via `C_Item.GetItemFamily` is even necessary, or if the `bagFamily` returned here is sufficient on its own.
- **Item family lookup (fallback/cross-check)**: `C_Item.GetItemFamily(itemInfo)` — can be used against the bag item itself if `bagFamily` from `GetContainerNumFreeSlots` needs cross-verification.

### Confirmed special bag types (quiver/ammo pouch) in this build

- `Enum.ItemClass.Quiver` = 11
- `Enum.ItemQuiverSubclass.Quiver` = 2
- `Enum.ItemQuiverSubclass.Ammopouch` = 3
- These are actively used in Forever's own Auction House UI (Forever-specific override references both as real filterable categories), confirming quivers/ammo pouches are live, functioning bag types in this game version — not a dead Classic-era leftover.
- Relevant `BagFlag` enum values that reference quivers: `RecurseQuivers` (256), `PreferQuivers` (2048) — these are search/loot-priority flags, not bag identification flags; do not use these for detection. Use `bagFamily` (from `GetContainerNumFreeSlots`) or `GetItemFamily` for actual type detection.

## Feature Spec

### 1. Per-Bag Border Coloring
- Active only when `ContainerFrameSettingsManager:IsUsingCombinedBags()` is true. When the player is in individual-bag-frame mode, this addon should do nothing — the bag boundaries are already visually obvious via separate frames.
- On combined-view update, iterate all item buttons in the combined frame, group them by `itemButton:GetBagID()`.
- Apply a border/highlight color to each item button based on which bag group it belongs to. Reuse the item button's existing border/quality-color texture element via `SetVertexColor` rather than adding a new overlay texture, if feasible — check how item quality borders are currently rendered in `ContainerFrame.lua` before deciding whether to add a new texture layer or repurpose an existing one.
- **Color assignment logic**:
  - General (non-special) bags: assigned colors from a small neutral/distinct cycling palette, one color per physical bag, purely to visually separate slot ranges from each other. Exact palette TBD — should be visually distinct enough to tell adjacent bags apart at a glance but not so saturated that it fights with item quality border colors (which use their own color coding for item rarity — do not visually conflict with that existing system).
  - Special bag types (quiver, ammo pouch, and structured to be extensible to other bag families later if desired): assigned a **fixed, dedicated color** regardless of which physical bag slot they're equipped in — e.g., quivers/ammo pouches are always the same color, so the player learns to recognize "that color = ranged ammo" rather than having to re-map colors every time bags are rearranged.
  - Detection: read `bagFamily` from `C_Container.GetContainerNumFreeSlots(bagIndex)` per bag, compare against known quiver/ammo pouch family values, and apply the fixed special color when matched; otherwise assign from the general cycling palette.

### 2. Per-Bag Slot Tracker — **Dropped (2026-09-22)**
- Originally spec'd to track and display total/free slot counts per bag. Dropped because Blizzard added this natively to Forever's own bag UI (quiver shows ammo count, general bags show empty-slot count) — no longer a gap this addon needs to fill.

## Explicit Non-Goals

- No changes to individual (non-combined) bag frame mode — this addon is scoped specifically to the combined-bags visual clarity problem.
- No combat-math or item-value calculations — stays well clear of Blizzard's "computational addon" restrictions, same consideration as the TrailBeacon project.
- No modification of actual bag/sort behavior (e.g., don't touch `PreferQuivers`/`RecurseQuivers` sort flags) — this is a purely visual/informational addon, not a bag-management/auto-sort tool.

## Open Items Before/During Implementation

- Final addon name (currently a placeholder — check for CurseForge naming collisions before publishing, same process used for TrailBeacon).
- Final color palette for general bags and the fixed special-bag-type color(s).
- ~~Exact placement/format of the slot-count display (inline label vs. summary panel vs. tooltip).~~ Moot — Feature 2 was dropped since Blizzard now shows this natively.
- ~~Confirm at implementation time whether item buttons' existing border texture can be repurposed via `SetVertexColor`, or whether a new texture overlay is needed to avoid visual conflict with item-quality coloring — inspect `ContainerFrame.lua`'s item button template/border logic directly before deciding.~~ **Resolved (2026-09-22):** `IconBorder` is exclusively driven by `SetItemButtonQuality` for item rarity, sized to match the icon, and hidden entirely for common-quality items — confirmed via `Blizzard_ItemButton/Mainline/ItemButtonTemplate.lua`. It cannot be repurposed. Feature 1 instead creates a new texture (`Interface\Common\WhiteIconFrame`, tinted via `SetVertexColor`) anchored flush to each item button's own bounds, forming a distinct outer ring outside Blizzard's own inner quality border without bleeding into adjacent slots.
- **Resolved (2026-09-22):** In-game testing confirmed the border-coloring hook must target the `ContainerFrameCombinedBags` frame *instance* directly (`hooksecurefunc(ContainerFrameCombinedBags, "Update"/"UpdateItemSlots", ...)`), not the `ContainerFrameCombinedBagsMixin`/`ContainerFrameMixin` tables — the frame's `mixin=` XML attribute copies those functions onto the instance at load time, so hooking the mixin table afterward never affects the already-shown frame. Feature 1 is confirmed working end-to-end in-game as of this date.
