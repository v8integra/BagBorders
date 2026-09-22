# BagBorders

*(working title — rename before publishing; see CLAUDE.md)*

A World of Warcraft: Forever addon that visually distinguishes individual bags when "Combined Bags" mode is enabled.

## Status

Feature 1 implemented and confirmed working in-game. Currently implemented:

- TOC manifest and SavedVariables-backed core namespace (`Core/Core.lua`), with a `db`-ready callback system for modules to hook into once SavedVariables are loaded.
- **Feature 1: Per-Bag Border Coloring** (`Modules/ContainerColors.lua`) — while Combined Bags mode is active, every item slot gets a colored outer border keyed to its originating bag. General bags cycle through a saturated 4-color palette (ADD-blended for visibility against the dark slot background) in bag-setup order; special bags (quiver/ammo pouch, detected via `bagFamily`) always get a fixed gold border regardless of position. The border is a new texture layered outside Blizzard's own item-quality border, so it never visually conflicts with rarity coloring. Hooks the `ContainerFrameCombinedBags` frame instance directly (`Update`/`UpdateItemSlots`) so coloring stays in sync automatically on open, close, and item changes — no manual refresh needed. `/bagborders debug` and `/bagborders refresh` are available for troubleshooting.
- **Feature 2 (minimal): Per-Bag Free Slot Count** — a small `(N)` label, color-matched to its bag's border color, on the first slot of each bag group showing free slots for that bag. Added because Blizzard's own native empty-slot display turned out to be buggy in this beta build (only correct on hover; otherwise shows an unrelated item's stack count). Computed directly via `C_Container.GetContainerNumFreeSlots`, not scraped from Blizzard's UI.

The color palette and special-bag color are still first-pass placeholders — see [CLAUDE.md](CLAUDE.md) for the open items list.

## Installation (development)

Clone or symlink this folder into your WoW `Interface/AddOns` directory as `BagBorders`, then enable it at the character select screen.

## Distribution

Targeting CurseForge once a first usable build exists. Final addon name still TBD — check for a CurseForge naming collision before publishing.
