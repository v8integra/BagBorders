# BagBorders

*(working title — rename before publishing; see CLAUDE.md)*

A World of Warcraft: Forever addon that visually distinguishes individual bags when "Combined Bags" mode is enabled.

## Status

All three features implemented and confirmed working in-game. Currently implemented:

- TOC manifest and SavedVariables-backed core namespace (`Core/Core.lua`), with a `db`-ready callback system for modules to hook into once SavedVariables are loaded.
- **Feature 1: Per-Bag Border Coloring** (`Modules/ContainerColors.lua`) — while Combined Bags mode is active, every item slot gets a colored outer border keyed to its originating bag. General bags cycle through a saturated 4-color palette (ADD-blended for visibility against the dark slot background) in bag-setup order; special bags (quiver/ammo pouch, detected via `bagFamily`) always get a fixed gold border regardless of position. The border is a new texture layered outside Blizzard's own item-quality border, so it never visually conflicts with rarity coloring. Hooks the `ContainerFrameCombinedBags` frame instance directly (`Update`/`UpdateItemSlots`) so coloring stays in sync automatically on open, close, and item changes — no manual refresh needed. `/bagborders debug` and `/bagborders refresh` are available for troubleshooting.
- **Feature 2 (minimal): Per-Bag Free Slot Count** — a small `(N)` label, color-matched to its bag's border color, on the first slot of each bag group in the combined view, showing free slots for that bag. Added because Blizzard's own native empty-slot display turned out to be buggy in this beta build (only correct on hover; otherwise shows an unrelated item's stack count). Computed directly via `C_Container.GetContainerNumFreeSlots`, not scraped from Blizzard's UI.
- **Feature 2b: Bag Bar Free Slot Count** (`Modules/BagBar.lua`) — same idea, applied to the equipped-bag icons on the main bag bar (`MainMenuBarBackpackButton`, `CharacterBag0-3Slot`, `CharacterReagentBag0Slot`). The backpack icon shows the *combined* free-slot total across all general bags; each special (quiver/ammo pouch) bag shows its own count on its own icon; the reagent bag always shows its own count (teal) on its own icon, since it's never part of that general total. Labels sit top-right, clear of Blizzard's own bottom-right item count. Refreshes on `BAG_UPDATE_DELAYED` (the same event Blizzard's own bag-slot buttons use), not by hooking any Blizzard function.
- **Feature 3: Reagent Bag Panel** (`Modules/ReagentPanel.lua`) — the reagent bag normally opens as its own separate window, never part of the combined view. This attaches a second, chrome-less item grid directly below `ContainerFrameCombinedBags` showing the reagent bag's own slots (teal-bordered, matching its bag bar color), so crafting materials read as visually separated from general bags without needing a second window. Built by mixing in `ContainerFrameMixin` on a plain frame — reuses Blizzard's own real item-grid/click/drag logic rather than reimplementing it, only skipping the title-bar/portrait/search-box parts a full bag window has that this panel doesn't need. Bordered with a bronze-tinted `SetBackdrop` edge (nine-slice corner art turned out to always render at a fixed pixel size, too large for a panel this short — see CLAUDE.md for the full story) and hooks the global `UpdateContainerFrameAnchors` to lift the main window up by the panel's height whenever the reagent bag is equipped, so the panel clears the bag bar instead of overlapping it. Only tested so far against a small (one-row) reagent bag — worth a follow-up look with a larger one.

The color palette and special-bag color are still first-pass placeholders — see [CLAUDE.md](CLAUDE.md) for the open items list.

## Installation (development)

Clone or symlink this folder into your WoW `Interface/AddOns` directory as `BagBorders`, then enable it at the character select screen.

## Distribution

Targeting CurseForge once a first usable build exists. Final addon name still TBD — check for a CurseForge naming collision before publishing.
