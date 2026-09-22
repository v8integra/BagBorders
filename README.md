# BagBorders

*(working title — rename before publishing; see CLAUDE.md)*

A World of Warcraft: Forever addon that visually distinguishes individual bags when "Combined Bags" mode is enabled.

## Status

Feature 1 implemented and confirmed working in-game. Currently implemented:

- TOC manifest and SavedVariables-backed core namespace (`Core/Core.lua`), with a `db`-ready callback system for modules to hook into once SavedVariables are loaded.
- **Feature 1: Per-Bag Border Coloring** (`Modules/ContainerColors.lua`) — while Combined Bags mode is active, every item slot gets a colored outer border keyed to its originating bag. General bags cycle through a 4-color neutral palette in bag-setup order; special bags (quiver/ammo pouch, detected via `bagFamily`) always get a fixed amber border regardless of position. The border is a new texture layered outside Blizzard's own item-quality border, so it never visually conflicts with rarity coloring. Hooks the `ContainerFrameCombinedBags` frame instance directly (`Update`/`UpdateItemSlots`) so coloring stays in sync automatically on open, close, and item changes — no manual refresh needed. `/bagborders debug` and `/bagborders refresh` are available for troubleshooting.

Feature 2 (per-bag slot tracker) was dropped — Blizzard added native empty/used-slot counts to the bag UI, so it's no longer a gap this addon needs to fill. The color palette and special-bag color are still first-pass placeholders — see [CLAUDE.md](CLAUDE.md) for the open items list.

## Installation (development)

Clone or symlink this folder into your WoW `Interface/AddOns` directory as `BagBorders`, then enable it at the character select screen.

## Distribution

Targeting CurseForge once a first usable build exists. Final addon name still TBD — check for a CurseForge naming collision before publishing.
