# CurseForge page text

Paste the part below the line into the project description (Markdown mode).

- **Summary (one line):** All your bags and bank in one window each, with a color
  for every bag, search, sort, and alt tracking. Built for WoW: Forever.
- **Logo:** `Media/Icon/BagBordersIcon.png`
- **Game version:** WoW Forever (Interface 16001)
- **Category:** Bags & Inventory

---

# BagBorders

**Every bag in its own color. All your bags in one window.**

BagBorders replaces Blizzard's bag and bank windows with one clean window each.
Every bag gets its own colored border and a free-slot count, so you can see at a
glance where an item lives and which bag is about to fill up.

It's built for **WoW: Forever** and works in combat.

---

## 🎒 Your bags, in one place

- Backpack, bags, reagent bag and keyring together in **one window**
- A **colored border** and a **free-slot count** for every bag
- **Search** that dims everything that doesn't match, in your bags *and* the open bank
- **One-click Sort**
- **Bag strip** across the top:
  - hover a bag to light up its slots
  - click it to hide or show those slots
  - drag bags on and off to swap them
- **Item level** on gear, colored by quality
- Works with Blizzard's **combined** and **individual** bag settings

## 🏦 A bank that makes sense

- Every bank tab as its own **colored section**, with free counts
- **Bank-bag slots**, **Clean Up Bank** and **Deposit all**
- An **account bank** view
- A **"Blizzard bank"** button for buying slots and tabs, then one click back

## 👥 Keep track of your alts

- Remembers every character's **bags, bank and gold**
- Check any character's bags or bank, or the account bank, **from anywhere**
  (read only)
- Item tooltips show **how many each character has**:

  > Altname — Bags 12, Bank 40
  > Account bank — 5

- See the **total gold** across all your characters

## ⚙️ Make it yours

Type **`/bagborders`** or go to **Options → AddOns → BagBorders** to change:

- columns (bags and bank)
- window size and background opacity
- lock and reset position
- every feature on or off

---

## 🛡️ Safe by design

BagBorders lets the game decide when bags and the bank open and close, and it
never changes Blizzard's own code. That means:

- You can **use items from the window in combat**.
- The bank keeps working.
- Item clicks (using, selling, banking) are handled by Blizzard's own item buttons.

## Commands

| Command | What it does |
| --- | --- |
| `/bagborders` | Open the options page |
| `/bagborders alts` | Open the alts viewer |
| `/bagborders forget <name>` | Forget a saved character |
| `/bagborders columns <4-30>` | Bag window width |
| `/bagborders scale <0.5-2>` | Window size |
| `/bagborders lock` | Lock or unlock the windows |
| `/bagborders reset` | Put the windows back where they started |
| `/bagborders ilvl` | Item level on gear on or off |

## Good to know

- **Alts:** each character shows up after you log in on it once, and its bank
  after you open the bank there once.
- **Account bank:** drag items onto an account slot to store them there.
  Right-clicking an item in your bags sends it to your character bank.
- **Refundable items:** use the "Blizzard bank" view to put them in the account
  bank, so you still get Blizzard's refund warning.
- **Prefer Blizzard's bags?** Turn the windows off on the options page. With
  Blizzard's combined bags you still get the colored borders and free counts.

## Feedback

Found a bug or have an idea? Leave a comment with what you were doing and any
error text. Turning on `/console scriptErrors 1` shows Lua errors on screen.
