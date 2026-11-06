# BagBorders: All-in-one bag window plan

Goal: replace Blizzard's bag windows with BagBorders' own window, in the spirit of
Bagnon on retail (one window for every bag, a matching bank window, search, offline
alts), built for WoW: Forever. Our own design and code; nothing copied from Bagnon.

Written 2026-11-05 against Forever UI source build 1.60.1 (70790). Nothing here is
built yet.

## Why a new window

The reagent bag can't go back inside Blizzard's combined window: the only way in is
to change Blizzard's `ENDING_BAG_INDEX`, and that taint blanked the bank at launch.
A window we own can lay out every bag however we want, with no Blizzard values
touched.

## What the source says is possible

Checked in the 70790 source before planning:

- **Item use from our own buttons works on paper.** `C_Container.UseContainerItem`
  and `PickupContainerItem` have no restrictions (only `SecretArguments =
  AllowedWhenUntainted`, which is about secret-value arguments). Blizzard's
  `ContainerFrameItemButtonTemplate` only needs a bag ID (`button.bagID` or the
  parent's `GetID()`) and a container frame passed to
  `Initialize(containerFrame, bag, slot)` that answers `IsCombinedBagContainer()`.
  Right-click use, vendor sell, drag, split and bank deposit all go through those
  calls.
- **Item info isn't secret.** `GetContainerItemInfo`, `GetContainerItemLink` and
  `GetContainerNumFreeSlots` don't return secret values, so the window can read and
  show everything, including in combat.
- **Bank items too.** Blizzard's bank item buttons only call `PickupContainerItem`
  / `UseContainerItem` on the bank tab's bag ID. Buying a bank tab
  (`C_Bank.PurchaseBankTab`, restricted) must stay on Blizzard's UI.
- **Search and sort:** `C_Container.SetItemSearch` (results come back as
  `isFiltered` in the item info) and `C_Container.SortBags` have no restrictions.
- **Tooltips and options:** `TooltipDataProcessor.AddTooltipPostCall` and
  `Settings.RegisterCanvasLayoutCategory` / `RegisterVerticalLayoutCategory` exist.

The one thing the source couldn't answer, **using items from our buttons in combat**,
was confirmed working in game in Phase 0.

## How the window takes over (taint-safe)

The bank broke because addon code changed Blizzard state that the bank reads. So
Blizzard keeps owning *when* bags are open, and we only change *what you see*:

1. **Blizzard still opens and closes bags.** Keybinds, the bag bar, bank, vendors
   and mail all keep calling Blizzard's own functions, which stay untainted.
2. **Blizzard's bag windows are hidden, not closed.** We reparent
   `ContainerFrameCombinedBags` and the individual bag frames to a hidden frame of
   ours (a frame method call, not a Lua write). Blizzard still thinks they're open,
   so its toggle logic stays correct.
3. **Our window follows theirs.** `HookScript("OnShow"/"OnHide")` on Blizzard's
   bag frames shows/hides our window. Ours shows whenever any held bag is open, so
   the reagent bag is always included. That retires the reagent dock and the
   Toggle Backpack key override while the window is on.
4. **Closing goes through Blizzard.** Our close button is a secure button that
   clicks Blizzard's own close button(s) (`SecureActionButtonTemplate`, `type =
   "click"`, or a secure `/click` macro if both bag windows must close). ESC
   already closes Blizzard's frames, and ours follows.
5. **Rules that carry over:** never write Blizzard globals or fields; only
   `hooksecurefunc`/`HookScript`; never call Blizzard open/close functions
   (`OpenBag`, `CloseAllBags`, ...) from addon code.
6. **Off switch:** `/bagborders window` turns the takeover off and puts Blizzard's
   windows back, with today's borders + dock behavior.

## Code layout (proposed)

- `Data/Inventory.lua`: reads bags into plain tables (link, count, quality, locked,
  filtered); fires our own callbacks on `BAG_UPDATE_DELAYED`, `ITEM_LOCK_CHANGED`,
  `BAG_UPDATE_COOLDOWN`, `INVENTORY_SEARCH_UPDATE`, `BAG_CONTAINER_UPDATE`,
  `PLAYER_MONEY`. Kept separate from the UI so offline alts reuse the same window.
- `UI/ItemButton.lua`: pooled buttons from `ContainerFrameItemButtonTemplate`, one
  holder frame per bag (`SetID(bagID)`); an offline variant (plain textures +
  `GameTooltip:SetHyperlink`) for cached data.
- `UI/BagWindow.lua`: the frame, grid layout, sections, header/footer.
- `UI/Takeover.lua`: the hide/mirror/close logic above.
- Existing `ContainerColors.lua`/`BagBar.lua` logic moves onto our buttons.

## Phases

Each phase ends with you testing in game; I mock-test logic offline with lupa first.

### Phase 0: Spike (go/no-go) - PASSED in game 2026-11-05

Built: `UI/BagWindow.lua` (window, sections: bags / reagents / keyring, colored
borders + per-bag free counts, total free, money, drag to move, `/bagborders
columns <n>`) and `UI/Takeover.lua` (parks Blizzard's bag windows offscreen,
mirrors them, secure close button). On by default; `/bagborders window` + `/reload`
turns it off. 29 lupa mock tests pass. Confirmed in game: window, bank, vendor and
in-combat item use all work, no errors.

In-game checklist (combined bags mode first, then individual bags mode):
- [x] Bag key, backpack icon, Open All Bags: our window opens and closes; no
  Blizzard bag window is visible anywhere; reagent section is there.
- [x] Our X closes it; ESC closes it; opening again works.
- [x] Right-click use out of combat (food), **and in combat** (potion/bandage).
- [x] Drag an item between two slots; drag onto the action bar; shift-click split;
  shift-click link into chat.
- [x] Vendor: window opens with the merchant, right-click sells, buyback works.
- [x] Bank: opens normally (not blank), window opens beside it, right-click
  deposits into the bank, bank items come back to the bags.
- [x] Open bags in combat, close them in combat (X may stay faded until combat
  ends; that's expected).
- [x] `/reload` with the window on and off; swap a bag for a bigger/smaller one.
- [x] Any red Lua errors (`/console scriptErrors 1`) or "action blocked" messages.

### Phase 1: Inventory window - PASSED in game 2026-11-05

Most of this landed in Phase 0 (one window, reagent section, colored borders and
free counts, title/close, money and total free, drag to move, remembered position,
`/bagborders columns <n>`). Added in Phase 1:

- `/bagborders lock`: toggle dragging off/on (dragging is also off in combat).
- `/bagborders scale <0.5-2>`: window size; the secure X scales with it (catches up
  after combat if changed mid-fight).
- `/bagborders reset`: back to default position and scale 1.

38 lupa mock tests pass. In-game checklist:
- [x] `/bagborders scale 0.8` and `1.3`: slots and X resize, X stays on the corner.
- [x] `/bagborders lock`: can't drag; again to unlock.
- [x] `/bagborders reset`: window returns bottom-right at normal size.
- [x] `/reload` keeps scale, lock and position.

### Phase 2: Bank window - PASSED in game 2026-11-05

Built: `UI/BankWindow.lua` and `UI/BankTakeover.lua`.

- **Takeover:** Blizzard's `BankFrame` stays open; a post-hook on its `SetPoint`
  moves it offscreen right after the UI panel manager places it (and remembers
  where Blizzard put it). Our window shows while `BankFrame` is shown. The X is a
  secure click on `BankFrameCloseButton`.
- **Contents:** every purchased tab of the character bank as its own section
  (name + free count, colored border per tab), then the bank-bag slots (pick up /
  drop bags; unbought slots greyed). Uses Blizzard's `CamelotBankItemButtonTemplate`.
- **Account bank:** if viewable, a Bank / Account switch. Forever's own switch is
  side tabs that react to mouse-up, which a secure button can't press, so ours only
  changes what our window shows. Right-click from the bags still deposits to the
  character bank; drag onto account slots to deposit there. Refundable items are
  refused on account slots (Blizzard's warning only runs on its own panel).
- **Sort** (`C_Container.SortBank`, with our own "Sure?" second click when the
  bank-cleanup confirm setting is on) and **Deposit all** (account bank; refused if
  refundable items are in the bags).
- **"Blizzard bank"** puts Blizzard's panel back on screen for buying tabs/bag
  slots, money and tab settings; "BagBorders view" under it (or closing the bank)
  switches back.

38 lupa mock tests pass. In-game checklist:
- [x] Open the bank: our bank window shows (no blank or stray Blizzard panel), bag
  window opens too. Close with our X, ESC, and by walking away.
- [x] Right-click a bank item -> goes to bags. Right-click a bag item -> goes to
  the bank. Drag both ways. Shift-click split and link.
- [x] Bank bags: drag a bag into an empty bank-bag slot and back out; the new
  slots appear as a section.
- [x] Sort works (and asks "Sure?" if the confirm setting is on).
- [x] "Blizzard bank" shows Blizzard's panel in its normal spot; buying a bag slot
  works there; "BagBorders view" switches back.
- [x] If you have an account bank: Account switch shows it; drag in/out works;
  Deposit all works.
- [x] Scale (`/bagborders scale`) resizes the bank window too; lock stops dragging.
- [x] `/reload` at the bank; open the bank right after combat.
- [x] Any Lua errors or "action blocked" messages.

### Phase 3: Finding things - PASSED in game 2026-11-05

Built: `UI/BagStrip.lua`, `Modules/ItemLevel.lua`, toolbar in `UI/BagWindow.lua`.

- Search box (our own `SearchBoxTemplate` edit box -> `C_Container.SetItemSearch`,
  unrestricted). Matches come back as `isFiltered` on every container, so the open
  bank dims too. Cleared when the bag window closes.
- Sort button: `C_Container.SortBags` (unrestricted), Blizzard's sort atlas and sound.
- Bag strip (bag icon next to Sort toggles it, setting `bagStrip`): backpack, bags,
  reagent bag in their border colors with free counts. Hover lights that bag's
  slots; click hides/shows them (`hiddenBags`, only applied while the strip is
  open); drag off = `PickupBagFromSlot`, drop/click with an item = `PutItemInBag` /
  `PutItemInBackpack` (old unrestricted globals Blizzard's own bag code uses).
  Hidden bags still take their palette turn, so other bags keep their colors, and
  still count in the free total. The strip wraps at the column count.
- Item level on weapons/armor (not shirts/tabards), quality-tinted, bag and bank
  windows (`C_Item.GetCurrentItemLevel`); `/bagborders ilvl` toggles it. Quality
  borders, new-item glow and junk coin were already there from Blizzard's template.
- Mock tests: 70 window (32 new), 38 bank, 18 dock.

In-game checklist:
- [x] Type in search: non-matches dim (bags and open bank); clear button works;
  closing bags clears it; typing doesn't trigger keybinds.
- [x] Sort tidies the bags.
- [x] Bag strip: icons, colors and free counts right; hover lights that bag's slots.
- [x] Click a bag in the strip: its slots disappear, the rest close up, colors stay;
  click again brings them back; closing the strip brings them back; survives /reload.
- [x] Drag a bag from the strip into your bags/onto another slot; drop a bag onto an
  empty strip slot; click a strip slot while holding an item puts it in that bag.
- [x] Item level numbers on gear (bags and bank), not on other items; `/bagborders ilvl`.
- [x] All of the above in combat; no Lua errors or "action blocked".

- Fix after test: bank footer buttons size to their text ("Clean Up Bank" overlapped); window widens to fit the footer. Confirmed in game.

### Phase 4: Options panel - PASSED in game 2026-11-05

Built: `Options/Options.lua`. A page in Options > AddOns > BagBorders made with
Blizzard's Settings API (registers through Blizzard's secure delegate). Every control
is a proxy over `BB.db.settings`, so it always agrees with the slash commands.
`/bagborders` with no arguments (or `options`) opens it; refuses in combat.

- Bag and bank windows: use the windows (needs a reload; "Reload UI" button),
  bag columns 4-30, bank columns 6-30, scale 50-200%, background opacity
  (new `bgAlpha`, default 92%), lock, reset position.
- Finding things: bag strip, item level on gear.
- Blizzard bag windows: Toggle Backpack key opens the reagent bag.
- Left out from the original list: slot spacing (would change every layout for
  little gain) and a reagent-section switch (the bag strip already hides any bag,
  the reagent bag included). Easy to add later if wanted.
- Mock tests: 24 options; window 70, bank 41, dock 18 still pass.

In-game checklist:
- [x] `/bagborders` opens the BagBorders page; it's also under Options > AddOns.
- [x] Each slider/checkbox changes the open bag/bank window right away.
- [x] Values match after using the slash commands (e.g. `/bagborders columns 12`,
  then reopen the page).
- [x] Turning the windows off, then Reload UI, gives Blizzard's bags; back on works.
- [x] Reset puts the windows back; settings survive /reload.
- [x] No Lua errors or "action blocked" (also open/close Options after combat, and
  try opening the bank right after changing settings).

### Phase 5: Alts and offline viewing - built 2026-11-05, multi-character test deferred

The user has one character so far (launch was 2026-11-04). The multi-character
checks wait until there's an alt; the single-character ones can be done now.

Built: `Data/Characters.lua`, `UI/AltViewer.lua`, `Modules/TooltipCounts.lua`.

- Cache: `BagBordersDB.characters["Name-Realm"]` (class, money, bags, bank,
  times) and `BagBordersDB.accountBank`. Bags are read at login, 0.5s after bag
  changes settle, and at logout. The bank is read only between `BANKFRAME_OPENED`
  and `BANKFRAME_CLOSED`, because that's the only time the game sends its contents.
  Items are stored as {itemID, link, count, quality, icon}.
- Viewer: its own read-only window (plain buttons, not the live windows), opened
  with the "Alts" button on the bag window, `/bagborders alts` or the options page.
  - Left side: characters, class colored, current one first. Hover shows money and
    when each was saved. Shift+right-click forgets one (`/bagborders forget <name>`
    works too); the current character can't be forgotten.
  - Bags / Bank / Account bank views, with sections, free counts, colored borders,
    a scroll area, a name search, and the total gold across characters.
  - Hovering an item shows its saved tooltip; shift-click links it.
  - It refreshes while open. No ESC-to-close: that would mean adding to Blizzard's
    UISpecialFrames table, so the window uses its own X instead.
- Tooltip counts via `TooltipDataProcessor.AddTooltipPostCall` (Blizzard runs addon
  callbacks insecurely by design): one line per character (bags and bank), the
  account bank and a total. Only GameTooltip and ItemRefTooltip get them, secret
  item IDs are skipped, and counts are cached per item until the saved data changes.
  Option "Item counts in tooltips" (`tooltipCounts`).
- Known limits: a character appears once you log in on it with this version, and
  its bank once you've opened it. Equipped gear and mail aren't counted. The
  sidebar fits about 20 characters.
- Mock tests: 56 Phase 5; window 71, bank 41, options 26, dock 18.

In-game checklist:
- [ ] Log in on two or three characters and open the bank on each; then `/reload`.
- [ ] "Alts" opens the viewer; each character's bags and bank look right; the
  account bank view works; search dims; the total gold adds up.
- [ ] Hovering a saved item shows its tooltip; shift-click puts the link in chat.
- [ ] Item tooltips (bags, bank, chat links, vendor) show the per-character counts;
  the option turns them off.
- [ ] Moving items while the viewer is open updates it.
- [ ] Forget an alt (shift+right-click); it disappears from the list and tooltips.
- [ ] No Lua errors or "action blocked", including tooltips in combat.

### Phase 6: Release - prepared 2026-11-05, not yet published

- Name check: no "BagBorders" addon turned up on CurseForge (web search,
  2026-11-05); the closest names are unrelated ("Borders", "BagBuddy").
- Localization: all on-screen text goes through `BB.L` (`Locales/enUS.lua`),
  looked up by its English wording, and falls back to English. Text the game
  already translates (BANK, KEYRING, BAG_CLEANUP_BANK...) still comes from
  Blizzard's globals. Debug and error prints stay English.
- README rewritten for players; the old feature log moved to `docs/DEV_NOTES.md`.
- `CHANGELOG.md`, `docs/CURSEFORGE.md` (page text), `.pkgmeta` (the packager leaves
  out `docs/`).
- Version 0.9.0. Suggest 1.0.0 once the alts checks pass with a second character.
- Still to do (the user's call): make the CurseForge project, add its
  `## X-Curse-Project-ID` to the TOC, commit, tag, upload.

In-game checklist:
- [ ] Quick pass with the 0.9.0 folder: bags, bank, search, options and alts viewer
  all show English text (no raw keys or blanks), no Lua errors.

## Risks

- **In-combat item use** from addon buttons (Phase 0 decides).
- **Taint leaks:** any slip (calling a Blizzard open/close function, writing a
  Blizzard field) can bring back the blank-bank bug. Every phase re-tests the bank.
- **Blizzard patches:** Forever is changing fast (70707 -> 70790 in two days).
  Diff the UI source each build before testing.
- **Gamepad mode:** out of scope; the takeover stays off there.

## Decisions (2026-11-05)

1. **Name:** stays BagBorders.
2. **Individual bags mode:** the window replaces Blizzard's windows in both combined
   and individual modes.
3. **Bank:** must work correctly. The bank window moves up to Phase 2 (right after
   the inventory window) and every phase re-tests the bank, window on and off.
   Search/sort becomes Phase 3 and options Phase 4.
