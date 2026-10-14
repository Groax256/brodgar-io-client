# 175 — Tasks

- [x] **175.1 — The Macros page does not exist for addons.**
      - **Code.** Add `AddonHidden` (`is`, `typing`), worn by `MacroPanel` and by the new
        `MacroPanel.Confirm`. Apply it at every door in `plan.md` §1: `LuaWidget.of`, `kids` and
        `hitTest`; `tipAt`; `UiApi.collect`, `enqueueEntered` and `collectSubtree`;
        `Sheet.consentSurface`; `AddonManager.onGlobKey`; `LuaBinding`'s `down`. Remove the editor's
        `text`/`value`/`drive` arms and its mention in `Controls.noValue`.
      - **Docs.** Rewrite *What an addon sees* in `macros.md`: the page and its question are outside
        every selector, walk, hit and event, unstyled, and keys typed there reach no addon. Remove the
        editor rows from `edit.md` and `widget.md`. Add the selector row to `selectors.md`, the
        focus rule to `keybindings.md`, and the key-order row to `docs/client/widget-input.md`. Covers
        criteria 1–6.
      *Its suite* declares one hotkey, F9, and one binding on `J`. It arms a selector watch on
      `@MacroPanel` and polls every frame during a hand step that asks the maintainer to open
      **Macros**, click into the editor, hold J, press F9, and then press Done. While the Options
      window stands it asserts:
      - `matchAll("@MacroPanel")`, `"@MacroRow"` and `"@CodeArea"` are empty;
      - the Options window's `:walk()` holds no `Label` reading a macro's name, and no more than
        before the page opened;
      - `hafen.ui():hit` at the window's centre is the window;
      - the watch never fired;
      - F9 fired zero times;
      - `binding:down()` never read `true`.

      A second step, with the menu closed, presses F9 once and expects one fire: the control that
      proves the hotkey works.
      `[manual]`: none.

- [x] **175.2 — A macro's identity is a token, and its name is no addon's.**
      - **Code.** `ClientDb` gets the `token` column and its fill. `Macro.token`, `Macros.create`,
        `Macros.res` and `Macros.idOfRes` are new. Translate at `CharApi.actionbarRes`,
        `actionbarName` (`null`), `AddonWidget.dropDescriptor`, `LuaGOut`'s `resource` and
        `LuaSlot`'s `hold`, with `BeltHold.hold` taking the id. `AddonManager.runMacro` loads under
        `=macro`.
      - **Docs.** In `actionbar.md`, *A macro on a slot* and *Placing one from a `Drop`*: the token,
        no `name`, and the one refusal. The `slot:res()` row, the `hold` rows and the refusal table
        too, and the example rewritten without `slot:name()`. Also `custom.md`'s `Drop` paragraph,
        `drawing.md`'s `g:resource` row, `types/ui.md` `ActionbarSlot`, and `macros.md`'s error row
        (`macro:<line>: <message>`). Covers criteria 7–9 and 14.
      *Its suite* shows a 34×34 drop square. Its hand step asks the maintainer to make a macro whose
      body is `error("t175")`, drag its icon onto the square, press **Run** on the page, and then
      press Done. It asserts:
      - the `Drop` `res` matches `^macro/%x+$`, is 38 characters long and has no uppercase letter;
      - `slot:hold(res)` on the first empty slot makes `slot:res() == res`, `slot:name() == nil` and
        `slot:info().name == nil`, and fires `ActionbarChanged` for that slot;
      - `slot:hold("macro/1")` and `slot:hold("macro/" .. string.rep("0", 32))` both raise "no
        macro", each naming its own string;
      - the System log holds a line matching `^macro:%d+: .*t175` (read through `chat.system`).

      `slot:hold(nil)` restores the slot.
      `[manual]`: the drop square shows the macro's wrench icon. Expect: the wrench, drawn whole.

- [ ] **175.3 — Running a macro needs the player's press on your addon.**
      - **Code.** Add `Press` (`open`, `close`, `take`). Open it at `WidgetSubs.fireInput`
        (`MouseDown`, own widget), `Controls.fire` (`Pressed`), `HookApi.dispatchKey`,
        `HookApi.dispatchConsole` and `AddonPagina.fire`, and only while `AddonManager.current()` is
        `null`. `LuaSlot`'s `use` on a `MacroPagina` slot takes it or raises (`plan.md` §3), with
        `consoleOwner` exempt.
      - **Docs.** `actionbar.md`: the `slot:use` row, *A macro on a slot*'s `use` row and *Placing one
        from a `Drop`*'s *Pressing* row state the press rule, the doors that count, one macro per
        press, and both refusals. Covers criteria 10–13.
      *Its suite* has a drop square and a **Press** button. Its hand step asks for a macro whose body
      is `print("t175 ran")`, dragged onto the square, and then Done. The suite holds the first empty
      slot with it, then asserts:
      - `slot:use()` from `timer():after(0, fn)` raises "only inside the player's press";
      - a `MouseDown` subscription on `@MapView`, armed for a step that asks for one map click,
        raises the same message from its handler;
      - in the **Press** button's handler, the first `slot:use()` succeeds and the second raises "one
        press runs one";
      - within 3 s the System log holds exactly one `t175 ran`;
      - `slot:use()` from a timer on a second empty slot held for the suite's own menu entry is not
        refused, and fires that entry's `Pressed`, so only a macro's slot carries the rule;
      - after a last hand step that asks for that slot's own action-bar key to be pressed, a second
        `t175 ran` appears.

      `slot:hold(nil)` restores both slots, and `menugrid():remove` takes the entry back.
      `[manual]`: none.
