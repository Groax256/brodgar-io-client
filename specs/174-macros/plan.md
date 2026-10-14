# 174 — Macros: plan

## Approach

**The record.** `ClientDb.Conn`'s constructor gains `CREATE TABLE IF NOT EXISTS macros (id INTEGER
PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, icon TEXT NOT NULL, body TEXT NOT NULL)` beside `prefs`,
`placements` and `holds`, and **`SCHEMA` stays 1**. `ClientDb` gets `macros()` (every row, by id),
`macroAdd(name, icon, body)` → the new id, `macroSave(id, name, body)`, and `macroDelete(id)`, which
deletes the row **and** `DELETE FROM holds WHERE entry = 'macro/<id>'` in one transaction. An unavailable
file answers no rows and writes nothing, the path every other `ClientDb` read takes.

**The model**, in `io.brodgar.addon` (beside `ClientDb`, `BeltHold`, `AddonPagina`, whose
package-private members it needs): `Macro`, an immutable value (`id`, `name`, `icon`, `body`); `Macros`,
the client's list — read once from `ClientDb` on first use, held as a `volatile` immutable snapshot so the
draw thread reads it without a lock, with `all()`, `get(id)`, `create()`, `save(id, name, body)`,
`delete(id)` and `gen()`, a counter the panel polls. `ICON` is the placeholder, `gfx/hud/rbtn-opt`
(local, in `hafen-res.jar`); 174.1 confirms its image fits a cell, else picks another local one and says
which. `MAX_BODY = 65536`. `ENTRY = "macro/"` is the identity prefix.

**The editor**, `io.brodgar.ui.CodeArea extends Widget`: lines, caret and anchor as (line, column), a
monospaced `Text.Foundry`, one `Scrollbar`; keys as `ReadLine` reads them, its system clipboard, the caret
blinking as `TextEntry.draw`'s, text drawn inside `Fonts.enterTyped` (typed text is never restyled).
`text()` / `text(String)` read and replace the body; `UiApi`'s best-effort `:text()` answers it.

**The page**, `io.brodgar.addon.ui.MacroPanel extends OptWnd.Panel`, caption `Macros`, built by one
`// addon:` line in `OptWnd`'s constructor directly after the AddOns `PButton`: `new PButton(UI.scale(200),
"Macros", 'm', () -> new MacroPanel(OptWnd.this, main))`. Left, an `SListBox<Macro, Widget>` of
`SListWidget.IconText` rows; right, a `TextEntry` for the name, a `MacroIcon` (the icon, which is the drag
handle), the `CodeArea`, a status `Label`, and **New · Save · Delete · Run**, then **Back**. The panel
re-reads `Macros.gen()` every tick. Saving happens on Save, on selecting another row, on Run (before it
runs), and in `hide()` — `OptWnd.chpanel` hides the current panel on Back and on every `OptWnd.show()`.
Delete opens a small `Window`, `Delete macro "<name>"?` **Yes / No**.

**Running.** `AddonManager.eval` is split: a private core `run(String src, String chunk, boolean
exprFirst, String errPrefix, boolean showValue)` holds the `console()` load, `Sandbox.arm`, `enterLua`/
`leaveLua`, `disarm` and the error path; `eval` is `run(src, "=lua", true, "lua: ", true)`, unchanged in
behaviour. `public static void runMacro(int id)` resolves `Macros.get(id)` (a deleted one does nothing),
echoes `[console] macro <name>` to the terminal and calls `run(body, "=macro:" + name, false, "", false)`.
The `=` chunk name makes LuaJ prefix errors `macro:<name>:<line>:`.

**The bar.** `io.brodgar.addon.MacroPagina extends MenuGrid.Pagina`, built over `AddonPagina.standin()`
with `scm` = that session's `GameUI.menu`, fields `user` and `macro` (the id), `id` = `macro/<id>`. It is
**never added to `menu.paginae`**. Its `MacroPagButton` overrides as `AddonPagButton` does: `name()` the
macro's current name through `RichText.Parser.quote`, `sortkey()`, `binding()` and `hotkey()` (never the
stock ones, which read a resource layer from inside the `PagButton` constructor), `spr()` the macro's
icon fitted to `AddonPagina.CELL` (Loading-guarded, rebuilt when the icon name changes), `info()` the name
alone, `use(iact)` → `AddonManager.runMacro(macro)`. `GameUI.PagBeltSlot.draw`/`use` already go through
`pag.button()`, so the slot draws and fires it with no change in `GameUI`.

`BeltHold.Hold.pag` widens to `MenuGrid.Pagina`, with a private `entry(Pagina)` (either kind's `id`)
wherever `pag.id` was read. `slotsOf` tests the owner on an `AddonPagina` only, so `teardownHolds` — the
console's at `:reload` included — never touches a macro; `held()` answers an `AddonPagina` only (a macro
slot's `slot:hold()` is `nil`); `dropped()` takes a `MacroPagina`. New: `restoreMacros(st, g)` holds every
placed `macro/<id>` whose macro exists, right after `BeltHold.restore(st)` at the world entry (before
`SessionEnteredWorld`) and after `AddonRegistry.reload`'s restore; `macroDeleted(id)` releases each live
hold in every session (`release(st, n, true)`) and drops it from each `beltPlaced`.

**The drag.** `MacroIcon` grabs the mouse on a left press; past a few pixels it builds a `MacroPagina` for
the panel's own session (none at the login screen: nothing drags), draws the icon at `ui.mc` through
`ui.drawafter` as `MenuGrid.draw` draws `dragging`, and on release calls `DropTarget.dropthing(ui.root,
ui.mc, pag)`, which `GameUI.Belt.dropthing` and `AddonWidget.dropthing` already take.

**The reads.** `CharApi.actionbarRes` answers the `id`, `actionbarName` the raw name; `LuaSlot.res(name)`
refuses `macro/` before the gate, as `addon/`; `AddonWidget.dropDescriptor` reports the `id`.

## Files to create/modify

- Create: `src/io/brodgar/addon/Macro.java`, `Macros.java`, `MacroPagina.java`,
  `src/io/brodgar/addon/ui/MacroPanel.java`, `src/io/brodgar/ui/CodeArea.java`,
  `docs/addons/macros.md`.
- Modify: `src/haven/OptWnd.java` (one line), `src/io/brodgar/addon/ClientDb.java`, `UiApi.java`,
  `AddonManager.java`, `BeltHold.java`, `CharApi.java`, `LuaSlot.java`, `AddonWidget.java`,
  `AddonRegistry.java` (the reload's restore).
- Docs: `docs/addons/README.md`, `runtime.md`, `panel.md`, `api/actionbar.md`, `api/types/ui.md`,
  `api/ui/custom.md`, `api/ui/widget.md`; `docs/client/ui-panels.md` and `widget-input.md` for the
  upstream facts this reads (`chpanel` hiding the current panel, `ui.drawafter` as a drag's ghost, a
  `Pagina` from any source reaching `Belt.dropthing`) — nothing about `io.brodgar`.

## Risks & gotchas

- **`user_version`.** `ClientDb.Conn` refuses a file whose `user_version` is above its `SCHEMA`: raising
  it would make an older build lose every pref. The table is additive and the number stays.
- **`AUTOINCREMENT`, not a bare `INTEGER PRIMARY KEY`**, which reuses the highest deleted id: an older
  build's dormant `macro/<id>` row would then put a deleted macro's slot back under a new one.
- **`PagButton(Pagina)` calls `binding()` from inside its constructor**: an override that reads a field
  of `MacroPagButton` reads it unset (`AddonPagina`'s comment). Read `KeyBinding.get` first: a macro must
  not add a row to the keybind panel, so if `get` registers, the binding is built unregistered.
- **Names are `RichText` markup** in a tooltip: quote `$`, `{`, `}` (`AddonPagButton.name`).
- **Threads.** The bar draws on the draw thread, so `Macros` is a snapshot swapped whole; runs are on
  the UI thread, as `:lua`'s.
- **`consoleOwner` is lazy**: `run` calls `console()` before it reads the field, as `eval` does.
- **`GameUI.Belt.keyact` acts only with the pointer over the map**, for a macro's key as for any slot's.
- **An addon's `slot:use()` on a macro slot** nests `enterLua(consoleOwner)` over the addon's entry;
  `current()` comes back after.
- **A suite's `:t174` handler holds the tree's monitor**: windows are built from `timer():after(0, fn)`.

## Discarded alternatives

- **Per-character macros, or a second per-character list**: the maintainer chose one list for the whole
  client; macros are the player's tools, not a character's.
- **A runtime of their own with its own consent**: a macro is a kept `:lua` line; a second owner would
  be a second console whose globals `:lua` never sees.
- **Raising `ClientDb.SCHEMA`**: an older build refuses the whole file, prefs and holds included.
- **A macro as an `AddonPagina` of the `(console)` owner**: it would stand in the action menu's AddOns
  category and read as `addon/(console)/…`, an identity a published addon takes for an addon's entry.
- **The console's `hafen.store()`**: addon data; the client's own goes in `client.sqlite`.
- **`hafen.macros()`**: macros stay the player's; an addon sees a slot.
- **An icon picker now**: the list of resources comes first.
- **Holding a slot by the macro's name**: a rename would orphan every slot; a stable id follows it.
- **Expression-first evaluation, as `:lua` does**: a macro is statements, and a `lua=` line on every
  key press is noise.
- **Refusing `slot:use()` on a macro slot**: the key, the click and `slot:use()` are one press on every
  other slot; the body is the player's own and no addon can write one.
- **A wrapping `TextEntry`**: `ReadLine` is one line and Enter submits.
