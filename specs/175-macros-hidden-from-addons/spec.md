# 175 — Macros hidden from addons

## What & why

A macro runs in the console's Lua, unsandboxed (`io` and `luajava` included), so every way an addon
touches a macro is a way out of its sandbox. Today `widget.value` rewrites a body through the
Macros page's editor; `actionbar.use` runs any macro at any moment, through `slot:hold("macro/<id>")`
(unprotected, sequential ids) and `slot:use()`; any addon reads every body and name, and follows
typing through `binding:down()`. Together that is `console.run` without its consent line.

The macro system becomes invisible to addons. Every player-facing part stays: the page, Run, the
drag onto the client's bar, the slot's key and click, the per-character memory, and the bar an addon
draws in place of the client's. **An addon is left with** an opaque token, received when the player
drags a macro onto its bar: it holds the slot, draws the icon, releases it, and runs the macro on the
player's press of its own button. It never learns which macros exist, their names or their bodies,
and never runs one on its own initiative.

## Acceptance criteria

**The page does not exist (one rule for every Lua owner, the console included).** It covers the
Macros page and every widget in it, plus its Delete confirmation window.

1. No selector matches it: `@MacroPanel`, `@MacroRow` and `@CodeArea` answer no widget while the page
   is open, and a count of matches never includes them.
2. `:children()` and `:walk()` on the Options window omit it.
3. `hafen.ui():hit(x, y)` over it answers the Options window, the nearest widget outside the page.
   `tipAt(x, y)` over it answers `nil`.
4. The page opening and closing fires nothing an addon can subscribe to, whether a selector watch or a
   widget's events.
5. No addon stylesheet reaches it. The page is drawn in the stock look, as the AddOns page is.
6. While the keyboard focus is inside the page, no addon hotkey fires and every `binding:down()` reads
   `false`.

**A macro's identity is a token.**

7. On a slot holding a macro, `slot:res()` is `macro/` followed by 32 lowercase hex characters. The
   token is random, stable for the macro's life, and unrelated to its order. The `Drop` of a macro
   hands the same string.
8. `slot:name()` answers `nil` and `slot:info()` carries no `name` on a macro's slot.
   `ActionbarChanged` still fires on both edges.
9. `slot:hold(token)` holds the slot, `g:resource(token, ...)` draws the icon and `slot:hold(nil)`
   releases it, exactly as today. `slot:hold("macro/1")`, or any string that is not a live token, is
   refused with the same message as a deleted macro's token, so nothing can be probed.

**Running needs the player's press.**

10. `slot:use()` on a macro's slot runs the macro only during the synchronous handling of a player's
    press on that same addon. A press is a `MouseDown` on a widget it built, a `Pressed` of a control
    it built, its own hotkey going down, its console command typed by the player, or its menu entry
    pressed by the player (grid or bar). Not a press: a subscription on a client widget, a mouse
    grab, a timer, an `Update`, a bus event, or `hafen.console():run`/`pag:use()`/`slot:use()` from code.
11. One press runs at most one macro. A second `slot:use()` on a macro's slot in the same press is
    refused.
12. Outside a press the call raises before anything runs, naming the rule ("only inside the player's
    press on your addon") and the doors that count. Any other slot's `slot:use()` is unchanged.
13. The player's own key or click on the client's bar runs the macro exactly as today.
14. A macro's error notice, and its System log line, read `macro:<line>: <message>`: no name.
    The terminal keeps the name, on the `[console] macro <name>` line.

## Out of scope

- **A macro's own output**: its windows, overlays and `print` lines are console output the player
  produced, System log included.
- **`console.run`**: `:lua` has `luajava` and reaches everything, as its consent line says.
- **Pixels**: a `mirror` of the Options window draws the page; no verb reads pixels back.
- **Denial without reading**: hiding, moving, covering the Options window or blocking its clicks
  reads and runs nothing.

## Docs impact

The pages written:
- `docs/addons/macros.md`: *What an addon sees* is rewritten.
- `docs/addons/api/actionbar.md`: *A macro on a slot*, *Placing one from a `Drop`*, the `slot:res()`
  row, the `slot:hold` rows and the refusal rows.
- `docs/addons/api/ui/custom.md`: the `Drop` paragraph.
- `docs/addons/api/ui/drawing.md`: the `g:resource` row.
- `docs/addons/api/ui/edit.md`: the editor's read and drive rows are removed.
- `docs/addons/api/ui/widget.md`: the `:text()` row.
- `docs/addons/api/types/ui.md`: `ActionbarSlot`.
- `docs/addons/api/client/keybindings.md`: the `down()` focus rule.
- `docs/addons/api/ui/selectors.md`: one row stating the page is outside every selector.
- `docs/client/widget-input.md`: the upstream focused-key → `GlobKeyEvent` order this feature reads.

Derived: `grep -rniE "macro|CodeArea" docs --include=*.md | grep -v docs/changelog` → the pages
above, plus `docs/addons/README.md`, `panel.md`, `runtime.md` (name the page and runtime only: no
change) and `docs/client/render-gl.md`, `render-targets.md`, `world-3d.md` (shader macros: unrelated).

## Context files

- `src/io/brodgar/addon/ui/MacroPanel.java` — 1, 2
- `src/io/brodgar/addon/LuaWidget.java`, `UiApi.java` (members named in `plan.md`) — 1
- `src/io/brodgar/addon/Sheet.java` (`consentSurface`) — 1
- `src/io/brodgar/addon/Controls.java` (`drive`, `noValue`; `fire`) — 1, 3
- `src/io/brodgar/addon/LuaBinding.java`, `src/io/brodgar/addon/HookApi.java` (`dispatchKey`, `dispatchConsole`), `src/io/brodgar/addon/AddonManager.java` (`onGlobKey`, `runMacro`, `run`, `current`) — 1, 2, 3
- `src/io/brodgar/addon/Macros.java`, `Macro.java`, `MacroPagina.java`, `ClientDb.java` (macros table) — 2
- `src/io/brodgar/addon/CharApi.java` (`actionbarRes`, `actionbarName`, `actionbarSnapshot`), `LuaSlot.java` (`res`, `hold`, `use`), `AddonWidget.java` (`dropDescriptor`), `LuaGOut.java` (`resource`), `BeltHold.java` (`hold(String,int,String)`) — 2, 3
- `src/io/brodgar/addon/Press.java`, `WidgetSubs.java` (`fireInput`), `AddonPagina.java` (`fire`), `LuaPagina.java` (`use`), `LuaMouseGrab.java` — 3
- `docs/client/widget-input.md` — 1
