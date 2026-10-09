# BagBorders

A World of Warcraft: Forever addon that visually distinguishes individual bags when "Combined Bags" mode is enabled.

## Status

Features 1-2b are confirmed working in-game; Feature 3 was rebuilt and still needs an in-game test. Currently implemented:

- TOC manifest and SavedVariables-backed core namespace (`Core/Core.lua`), with a `db`-ready callback system for modules to hook into once SavedVariables are loaded.
- **Feature 1: Per-Bag Border Coloring** (`Modules/ContainerColors.lua`) — while Combined Bags mode is active, every item slot gets a colored outer border keyed to its originating bag. General bags cycle through a saturated 4-color palette (ADD-blended for visibility against the dark slot background) in bag-setup order; special bags (quiver/ammo pouch, detected via `bagFamily`) always get a fixed gold border regardless of position. The border is a new texture layered outside Blizzard's own item-quality border, so it never visually conflicts with rarity coloring. Hooks the `ContainerFrameCombinedBags` frame instance directly (`Update`/`UpdateItemSlots`) so coloring stays in sync automatically on open, close, and item changes — no manual refresh needed. `/bagborders debug` and `/bagborders refresh` are available for troubleshooting.
- **Feature 2 (minimal): Per-Bag Free Slot Count** — a small `(N)` label, color-matched to its bag's border color, on the first slot of each bag group in the combined view, showing free slots for that bag. Added because Blizzard's own native empty-slot display turned out to be buggy in this beta build (only correct on hover; otherwise shows an unrelated item's stack count). Computed directly via `C_Container.GetContainerNumFreeSlots`, not scraped from Blizzard's UI.
- **Feature 2b: Bag Bar Free Slot Count** (`Modules/BagBar.lua`) — same idea, applied to the equipped-bag icons on the main bag bar (`MainMenuBarBackpackButton`, `CharacterBag0-3Slot`, `CharacterReagentBag0Slot`). The backpack icon shows the *combined* free-slot total across all general bags; each special (quiver/ammo pouch) bag shows its own count on its own icon; the reagent bag always shows its own count (teal) on its own icon, since it's never part of that general total. Labels sit top-right, clear of Blizzard's own bottom-right item count. Refreshes on `BAG_UPDATE_DELAYED` (the same event Blizzard's own bag-slot buttons use), not by hooking any Blizzard function.
- **Feature 3: Combined Window Layout + Reagent Bag** (`Modules/CombinedLayout.lua`, replaces the earlier separate `ReagentPanel.lua`) — two things, both implemented but not yet tested in-game:
  - **Slot order fix.** A build after 70170 changed the combined view's item sort to ascending while the grid still fills from the bottom-right corner, so the backpack ended up at the bottom and bags/slots ran backwards. A post-hook on the frame's `UpdateItemLayout` re-sorts descending and re-lays the grid out, restoring the original look (backpack first at the top, then the other bags in order). It's a no-op if Blizzard fixes the sort themselves.
  - **Reagent bag inside the combined window.** The reagent bag is laid out as its own block below the general bags with a small gap, teal-bordered. This works by setting Blizzard's `ENDING_BAG_INDEX` global to include bag 5 (the same thing gamepad mode already does), so Blizzard's own code builds, refreshes, searches and highlights the reagent slots. As a side effect `OpenBag(5)` routes to the combined window, so vendors (and any other `OpenAllBags` caller) no longer pop open a separate reagent frame. The window grows to fit via a post-hook on `UpdateFrameSize`. `/bagborders reagent` toggles it (needs `/reload`); the setting is `reagentInCombined`. Not applied in gamepad mode, which has its own layout.
  - Caveat: writing a Blizzard global from an addon marks it tainted, so bag-open code that reads it runs tainted. Bag frames aren't protected, so it should only matter if something odd shows up in combat.

## Installation (development)

Clone or symlink this folder into your WoW `Interface/AddOns` directory as `BagBorders`, then enable it at the character select screen.

## Distribution

Targeting CurseForge once a first usable build exists.
