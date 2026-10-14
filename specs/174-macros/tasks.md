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

- [x] **174.2 — A macro runs like `:lua`.** `AddonManager.run`, `eval` over it, `runMacro(id)`; Run
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

- [x] **174.3 — Macros stand on the action bar.** `MacroPagina` and its button; `MacroIcon`'s drag;
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

- [ ] **174.4 — An addon's own bar takes a macro.** A bar an addon draws in place of the client's receives
      the drag as its `Drop`, and must place, draw and release the macro. `LuaSlot.hold`: a string
      `macro/<id>` naming an existing macro holds the slot for it (`BeltHold`, a `MacroPagina` on that
      character's bar), unprotected like the drag; a deleted or unknown id is refused naming it; every other
      string is refused as today. `g:resource("macro/<id>")` draws the macro's icon (`LuaGOut`'s resource
      read). The sibling repository's `actionbars`: its drop holds a `macro/` res with `slot:hold(res)`, its
      right-click ends a `macro/` slot with `slot:hold(nil)`, never `slot:clear()`. Docs: `api/actionbar.md`
      (*A macro on a slot*: placing one from a `Drop`; the refusal rows), `api/ui/custom.md` (`Drop` → `hold`),
      `api/ui/drawing.md` (`g:resource`), `macros.md` (a bar an addon draws takes the drag too).
      *Its suite* `addons/174-macros.4/`: its own one-slot `Drop` square standing for a bar slot of the
      session. Make `t174 four`, drag it onto the square, Done → the handler's `slot:hold(res)` leaves the slot
      reading `res()` the id, `name()` `t174 four`, `hold()` nil; `slot:hold("macro/999999")` refused naming
      that id; `slot:hold("dig")` still refused; `slot:hold(nil)` → `res()` no longer the id; Delete the macro.
      `[manual]`: the square draws the macro's icon (`g:resource` of the slot's `res()`) — expect the wrench.
      `[manual]`: with `actionbars` enabled, drag a macro onto its bar, press its key, right-click it —
      expect the wrench drawn, the macro run, then the server's action back in that button.
