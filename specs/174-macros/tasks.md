# 174 — Macros: tasks

- [x] **174.1 — The Macros page keeps the player's macros.** `ClientDb`'s `macros` table (SCHEMA stays
      1) and its four calls; `Macro`, `Macros`; `io.brodgar.ui.CodeArea`; `MacroPanel` (list, name, the
      placeholder icon, editor, status line, New · Save · Delete with its Yes/No window · Run disabled
      until 174.2, Back), autosave on another row and in `hide()`; the `OptWnd` line below AddOns;
      `widget:text()` on a `CodeArea`. Docs: `macros.md` (the page), `README.md`, `panel.md`,
      `api/ui/widget.md`; `docs/client/ui-panels.md`. Criteria 1, 2, 3, 8.
      *Its suite* `addons/174-macros.1/`, `:t174`, a window of steps each waiting for **Done**: New, name
      `t174 one`, paste a three-line body it shows, Save → `@MacroPanel` exists, a row reads `t174 one`,
      the `@CodeArea` reads the three lines exactly; clear the name and Save → the status line names the
      name, the row still reads `t174 one`; select another row and back after an edit → the edit is kept;
      Delete, Yes → no row reads `t174 one`.
      `[manual]`: Shift+Down twice, Ctrl+X, Ctrl+V on a later line — expect the two lines moved.
      `[manual]`: restart the client and open Macros — expect a macro made before the restart, unchanged.

- [ ] **174.2 — A macro runs like `:lua`.** `AddonManager.run`, `eval` over it, `runMacro(id)`; Run
      saves then runs. Docs: `macros.md` (running), `runtime.md` (*The console commands*: a macro is that
      runtime). Criterion 4.
      *Its suite* `addons/174-macros.2/`, watching the System log through `session:chat()`: the
      maintainer types `:lua t174_seed = 7`, then makes macro `t174 two` with
      `print("t174 seed " .. t174_seed)` and presses Run → the line `t174 seed 7` arrives (same globals,
      same `print`); body `return 5`, Run → no `lua=` line within 2 s; body
      `hafen.session():current():actionbar():get(1):empty()` with `print` around it → it prints (a verb
      an addon would call is reached). Delete the macro at the end.
      `[manual]`: body `local x = 1` then `error("boom")` on line 2, Run — expect the error notice
      `macro:t174 two:2: boom`.

- [ ] **174.3 — Macros stand on the action bar.** `MacroPagina` and its button; `MacroIcon`'s drag;
      `BeltHold` widened (`Hold.pag`, `entry`, `slotsOf`, `held`, `dropped`), `restoreMacros` at the
      world entry and the reload, `macroDeleted` with `ClientDb.macroDelete`; `CharApi`'s two reads,
      `LuaSlot`'s `macro/` refusal, `AddonWidget.dropDescriptor`. Docs: `macros.md` (the bar),
      `api/actionbar.md` (reads, refusal, endings, *A hold is remembered*), `api/types/ui.md`,
      `api/ui/custom.md`; `docs/client/widget-input.md`. Criteria 5, 6, 7.
      *Its suite* `addons/174-macros.3/` subscribes `ActionbarChanged` first. Make `t174 bar` printing
      `t174 pressed`, drag it to a visible slot, Done → exactly one slot reads `res()` `^macro/%d+$`,
      `name()` `t174 bar`, `empty()` false, `hold()` nil, and `ActionbarChanged` named it; its key over
      the map → `t174 pressed` in the System log; rename to `t174 bar2`, Save → `name()` follows;
      `pcall(slot.res, slot, that id)` fails naming the Macros page; drag onto the suite's own `Drop`
      widget → `thing().res` equals the id; `slot:hold(nil)` → `res()` no longer the id; drag back,
      Delete the macro → no slot reads a `macro/` id.
      `[manual]`: drag a macro to a slot, log out and back in — expect it in that slot.
      `[manual]`: with a macro on a slot, `:reload` — expect it still there.
