# BagBorders

An all-in-one bag and bank addon for **World of Warcraft: Forever**. Every bag
gets its own border color and free-slot count, so you always know which bag an
item is in.

## Features

- **One bag window:** backpack, bags, reagent bag and keyring together. Each bag
  has its own border color and a free-slot count. It works in combined and
  individual bag modes.
- **One bank window:** every bank tab as a colored section with free counts, plus
  bank-bag slots, Clean Up Bank and Deposit all. If you have an account bank, a
  Bank/Account switch shows it. A "Blizzard bank" button brings back Blizzard's
  panel for buying slots and tabs.
- **Search:** dims everything that doesn't match, in your bags and the open bank.
- **Sort:** Blizzard's bag cleanup, one click.
- **Bag strip:** your equipped bags along the top of the window.
  - Hover a bag to light up its slots.
  - Click a bag to hide or show its slots.
  - Drag bags on and off to swap them.
- **Item level** on gear, colored by quality.
- **Alts:** remembers every character's bags, bank and gold.
  - A read-only viewer shows any character's bags or bank, and the account bank,
    from anywhere.
  - Item tooltips list how many of that item each character has.
- **Options page:** columns, scale, opacity, lock, and every feature on/off.

It also works in combat. Items can be used from the window, and it opens and closes
normally.

## Commands

| Command | What it does |
| --- | --- |
| `/bagborders` | Open the options page (also under Options > AddOns) |
| `/bagborders alts` | Open the alts viewer |
| `/bagborders forget <name>` | Forget a saved character |
| `/bagborders columns <4-30>` | Bag window width |
| `/bagborders scale <0.5-2>` | Window size |
| `/bagborders lock` | Lock or unlock window dragging |
| `/bagborders reset` | Put the windows back at their default spot and size |
| `/bagborders ilvl` | Item level on gear on or off |
| `/bagborders window` | Use the BagBorders windows or Blizzard's (needs `/reload`) |

## Good to know

- **Characters:** each one shows up in the alts viewer and tooltips after you log
  in on it once. Its bank appears after you open the bank there once.
- **Account bank:** right-clicking an item in your bags always deposits it to the
  character bank. To put something in the account bank, drag it onto an account
  slot.
- **Refundable items:** these can't go into the account bank from the BagBorders
  window, so it can't skip Blizzard's refund warning. Use the "Blizzard bank"
  view for those.
- **Buying:** bank slots, tabs and tab settings are on Blizzard's bank panel. The
  "Blizzard bank" button opens it.
- **Blizzard's bags instead:** turn the windows off on the options page, then
  reload. With Blizzard's combined bags you still get per-bag colored borders and
  free counts, and the reagent bag docks next to the combined window.
- **Gamepad mode:** the windows stay off.

## Install

Copy the `BagBorders` folder into your WoW: Forever `Interface\AddOns` folder,
then enable it at character select.

## For developers

- `docs/BAG_WINDOW_PLAN.md` has the design: how the windows take over without
  tainting Blizzard's code, the phases, and the in-game checklists.
- `docs/DEV_NOTES.md` has notes on each feature.
- **Translations:** all on-screen text goes through `Locales/enUS.lua`. Add a
  `Locales/<locale>.lua` to translate it.
