# 174 — Macros

## What & why

The player writes, names, keeps and runs their own Lua snippets without writing an addon, the way
World of Warcraft's macros work. **Macros** is a page of the game menu (`Ctrl+O`), directly below
**AddOns**. A macro is a name, an icon and a body of Lua. Its body runs exactly as a `:lua` line does —
the console's own runtime: not sandboxed, every protected verb answering, the instruction watchdog
armed. Dragging a macro's icon onto
the action bar puts it in that slot; pressing the slot (its key or a click) runs it.

The macros are the client's own record, one list for every account and character, in
`savedata/client.sqlite`. The icon is a fixed placeholder for now, recorded by resource name.

## Acceptance criteria

1. **The page.** The game menu shows **Macros** directly below **AddOns**; it opens a page with a list
   of every macro (icon and name) on the left and, for the selected one, its name field, its icon, a
   multi-line code editor and the buttons **New**, **Save**, **Delete**, **Run**, plus **Back**.
2. **Keeping.** **New** adds a macro named `New macro` with the placeholder icon and an empty body, and
   selects it. **Save** stores the name and body; an empty name is refused on the page, saying why.
   Switching to another macro or leaving the page saves the one being edited. **Delete** asks first, then
   removes it. Names may repeat. Every macro survives a client restart, unchanged.
3. **The editor.** Typing, Enter for a new line, Tab (two spaces), Backspace/Delete, arrows, Home/End,
   PgUp/PgDn, a click places the caret, Shift+keys and a mouse drag select, Ctrl+A/C/X/V use the system
   clipboard, the wheel and a scrollbar scroll. A body is at most 65 536 characters. `widget:text()`
   reads the editor's text.
4. **Running.** **Run** runs the body in the `:lua` console's runtime: its globals, its permissions, its
   `print`, its error path. A body is a chunk of statements, not an expression; its value is not
   printed. An error reads `macro:<name>:<line>: …`. A `:reload` takes back what a macro put up, as it does
   for `:lua`.
5. **On the bar.** Dragging a macro's icon from the page onto an action-bar slot holds that slot for the
   macro: it draws the macro's icon, nothing is sent to the server, and the server's content comes back
   untouched when the hold ends. Pressing the slot runs the macro. A right-click releases it.
6. **Remembered on the bar.** Per character, like an addon entry's hold: the macro is back in its slot
   at the next world entry and after a `:reload`. Renaming a macro or editing its body keeps every slot it
   stands in; deleting it releases each one and forgets the record for every character.
7. **What an addon sees.** On a slot held for a macro, `slot:res()` is `macro/<id>`, `slot:name()` the
   macro's name, `slot:empty()` false, `slot:hold()` `nil`; `slot:hold(nil)` releases it;
   `ActionbarChanged` fires on both edges. `slot:res("macro/<id>")` is refused, naming the drag from the
   Macros page. A widget's `Drop` reports a macro as `{ kind = "pagina", res = "macro/<id>" }`.
8. **Compatible.** A file written by this build opens in an older one with no error: the macros table is
   additive and the file's schema number does not move; an older build keeps a macro's slot row dormant
   and writes it back unchanged.

## Out of scope

- **An icon picker.** The boundary is the icon's *value*: every macro records a resource name, and this
  feature writes the placeholder. Choosing among a curated list of resources is its own feature, over a
  list the maintainer compiles.
- **A Lua surface for macros** (`hafen.macros()`, reading, writing or running one from an addon). An
  addon sees a macro only as the content of a slot (criterion 7). `slot:use()` on a macro slot runs it,
  as the player's key does — the player's own code, which no addon can write.
- **Per-character macros**, and macros in the action menu: one list, on its page and on the bar.

## Docs impact

Pages written: `docs/addons/macros.md` (new: the page, the runtime, the bar);
`docs/addons/README.md` (its row); `docs/addons/runtime.md` (*The console commands*: macros share
`:lua`'s runtime); `docs/addons/api/actionbar.md` (a macro on a slot: the reads, the refusal, the
endings); `docs/addons/api/ui/custom.md` (`Drop` carries `macro/<id>`); `docs/addons/api/ui/widget.md`
(`:text()` on the code editor); `docs/addons/panel.md` (where the game menu's pages are named).

Derived impact set — `grep -rln "addon/<addon id>\|addon/…\|slot:hold" docs/addons`:
`api/actionbar.md`, `api/conventions.md`, `api/types/ui.md`, `api/ui/custom.md`,
`guides/permissions.md`. `api/types/ui.md` and `actionbar.md`'s *While held* row state `addon/…` as
the only held identity, and change; the other three stay true. `grep -n "nil for every slot the server
owns" docs/addons` → `api/actionbar.md:112`, which changes. `grep -rln "game menu\|Ctrl+O" docs/addons`
→ `guides/debugging.md`, `panel.md`. `docs/client/`: `ui-panels.md` (the menu's `PButton`s),
`widget-input.md` (*Drop dispatch* gains a second source).

## Context files

- `src/haven/OptWnd.java` — 1
- `src/io/brodgar/addon/ui/AddonPanel.java` — 1
- `src/io/brodgar/addon/ClientDb.java` — 1, 3
- `src/haven/TextEntry.java`, `src/haven/ReadLine.java` — 1
- `src/haven/Scrollbar.java`, `src/haven/SListBox.java`, `src/haven/SListWidget.java` — 1
- `src/io/brodgar/addon/LuaWidget.java` (`text(Widget)`, what `:text()` reads) — 1
- `src/io/brodgar/addon/Macros.java`, `src/io/brodgar/addon/Macro.java` — 2, 3
- `src/io/brodgar/addon/ui/MacroPanel.java` (Run, `MacroIcon`) — 2, 3
- `src/io/brodgar/addon/AddonManager.java` (`eval`, `console`, `consoleStdout`, the world-entry restore) — 2, 3
- `src/io/brodgar/addon/Sandbox.java` — 2
- `src/io/brodgar/addon/BeltHold.java` — 3
- `src/io/brodgar/addon/AddonPagina.java`, `src/io/brodgar/addon/LuaSlot.java`, `src/io/brodgar/addon/CharApi.java` — 3
- `src/haven/GameUI.java` (`BeltSlot`, `PagBeltSlot`, `Belt.dropthing`), `src/haven/MenuGrid.java` (`Pagina`, `PagButton`, `dragging`), `src/haven/DropTarget.java` — 3
- `src/io/brodgar/addon/AddonWidget.java` (`dropDescriptor`) — 3
- `docs/addons/api/actionbar.md`, `docs/addons/api/ui/custom.md`, `docs/addons/api/types/ui.md` — 3
- `docs/addons/runtime.md` — 2
- `docs/addons/panel.md`, `docs/addons/README.md`, `docs/addons/api/ui/widget.md` — 1
- `docs/client/ui-panels.md` — 1; `docs/client/widget-input.md` — 3
- `DOCUMENTATION.md` — 1, 2, 3
