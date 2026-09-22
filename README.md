# BagBorders

*(working title — rename before publishing; see CLAUDE.md)*

A World of Warcraft: Forever addon that visually distinguishes individual bags when "Combined Bags" mode is enabled, and tracks per-bag slot usage.

## Status

Bare scaffold — no features yet. Currently implemented:

- TOC manifest and SavedVariables-backed core namespace (`Core/Core.lua`), with a `db`-ready callback system for modules to hook into once SavedVariables are loaded. No default settings committed yet — the color palette and slot-count display format are both still open questions in [CLAUDE.md](CLAUDE.md), so nothing's been guessed ahead of those decisions.

Not yet built: per-bag border coloring (Feature 1), per-bag slot tracker (Feature 2). See [CLAUDE.md](CLAUDE.md) for the full feature spec.

## Installation (development)

Clone or symlink this folder into your WoW `Interface/AddOns` directory as `BagBorders`, then enable it at the character select screen.

## Distribution

Targeting CurseForge once a first usable build exists. Final addon name still TBD — check for a CurseForge naming collision before publishing.
