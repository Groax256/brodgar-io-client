# 175 — Plan

## Approach

### 1. One predicate hides the page (175.1)

- **The marker.** A new empty marker interface, `io.brodgar.addon.AddonHidden`, with
  `static boolean is(Widget w)`, which is true when `w` or any ancestor implements it.
- **Who wears it.** `MacroPanel`, and the Delete question, which becomes
  `MacroPanel.Confirm extends Window implements AddonHidden`. `ask()` puts the question on
  `ui.root`, outside the panel, so it needs the marker itself.
- **Every Lua owner, the console included.** It is one rule, and `:lua` reaches everything through
  `luajava` anyway.

| Door | Change |
|---|---|
| `LuaWidget.of` | A hidden widget answers `nil`. This is the backstop, and it covers `LuaEvent`'s `ev:widget()` and `LuaMouse`'s `m:over()` |
| `UiApi.collect` | Prunes the subtree, so it neither matches nor recurses. It is the one walk behind `matchOne`, `matchEvery`, `scopedMatch`, `scopedMatchAll` and `scanForWatch`, so `UiApi.one`'s "matches N widgets" never counts the page |
| `LuaWidget.kids` | Filters hidden children out. It feeds `children()` and `walk` |
| `LuaWidget.hitTest` | A hidden deepest widget climbs to its nearest ancestor that is not hidden: the Options window for the page, `ui.root` (an empty screen's answer) for `Confirm`. This covers `widget:hit`, `UiApi.deepest` and `m:over()` |
| `LuaWidget.tipAt` | A hidden `q.from` answers `nil` |
| Entered/removed | `UiApi.enqueueEntered` drops hidden widgets and `collectSubtree` prunes, so `offerEntered`, `offer` and `dispatchSelectorRemoved` never see them |
| `Sheet.consentSurface` | Adds `AddonHidden` beside `AddonPanel`, so the page keeps the stock look |
| The editor arms | Removed: the `CodeArea` arms of `LuaWidget.text`, `LuaWidget.value` and `Controls.drive`. `Controls.noValue` stops naming the editor |

**Keys.** `AddonHidden.typing(UI u)` follows `focused` from `u.root` through `focusctl` widgets and
answers whether the end of the chain is hidden. `hasfocus` is not maintained
(`docs/client/widget-input.md`), and `Widget.setfocus` forwards to the nearest controller, so the
Options window records the `CodeArea` or the name entry directly.

Applied in two places:
- `AddonManager.onGlobKey` returns unconsumed before `HookApi.dispatchKey` when `typing(screen())`.
- `LuaBinding`'s `down`, both the verb and the `info` field, reads `false`. `KeyHeld` keeps tracking.

### 2. The token (175.2)

- **The column.** `macros` gains `token TEXT`. `ClientDb` adds the column when
  `PRAGMA table_info(macros)` lacks it, and fills the `NULL` rows on read.
- **The value.** A `SecureRandom` 16 bytes as 32 lowercase hex, held in `Macro.token` and minted by
  `Macros.create`. Tokens are minted in `Macros`, never in SQL, so the in-memory fallback mints them
  too.
- **No migration.** The internal identity stays `macro/<id>`, in `MacroPagina.id` and
  `holds.entry`, and never reaches Lua.
- **The boundary** is two helpers on `Macros`. `res(int id)` answers `"macro/" + token`, or `null`
  once deleted. `idOfRes(String)` answers the id of a live token, or `-1`.

| Site | Change |
|---|---|
| `CharApi.actionbarRes` | `Macros.res(id)` |
| `CharApi.actionbarName` | `null` for a `MacroPagina`, so `slot:name()`, `slot:info()` and the `ActionbarChanged` snapshot carry no name. `LuaSlot`'s collection needle already reads `actionbarRes` |
| `AddonWidget.dropDescriptor` | `res` is `Macros.res(id)` |
| `LuaGOut`'s `resource` | Resolves through `idOfRes` |
| `LuaSlot`'s `hold` | Resolves through `idOfRes`, then calls `BeltHold.hold`, which now takes the id. One refusal for every miss, `"macro/1"` included: no such macro, naming the string |

**The error notice.** `AddonManager.runMacro` loads the body under the chunk name `=macro`, not
`=macro:<name>`. The notice reads `macro:<line>: <message>`, and the terminal keeps the name on its
`[console] macro <name>` line.

### 3. The press (175.3)

- **The class.** A new package-private `Press` holds a `ThreadLocal` press: an owner `Addon` and a
  `spent` flag. `open(Addon)` returns the previous state, `close(prev)` restores it, and `take(Addon)`
  is true once per press, for its owner only.
- **Opened only from the engine.** A press opens only while `AddonManager.current()` is `null`, with
  no Lua on the stack. That one test excludes every press made by code: `pag:use()`, `slot:use()` on
  a held entry, `hafen.console():run` and `ev:resend`.

Each site wraps its existing fire in `try`/`finally`:

| Site | Condition |
|---|---|
| `WidgetSubs.fireInput` | `MouseDown`, and `Owned.of(wdg)` belongs to `owner`. A borrowed widget never opens one, and `LuaMouseGrab` is another path |
| `Controls.fire` | `Pressed` (an owned control by construction) |
| `HookApi.dispatchKey` | `kb.owner` |
| `HookApi.dispatchConsole` | The live handler's owner |
| `AddonPagina.fire` | The entry's owner: a grid click or the bar's key |

**In `LuaSlot`'s `use`.** The order is: the `actionbar.use` permission, `mods`, the slot lookup, and,
when `g.belt[n]` holds a `MacroPagina` (`CharApi.actionbarMacro`), `Press.take`. A failed take
raises before `Wire.send`:
- with no press, or another addon's: *slot:use() runs a macro only inside the player's press on your
  addon (a MouseDown on a widget you built, a Pressed of your control, your hotkey, your console
  command, your menu entry): call it in that handler*;
- with a spent press: *one press runs one macro*.

`AddonManager.consoleOwner` is exempt.

## Files to create/modify

- **New:** `src/io/brodgar/addon/AddonHidden.java`, `Press.java`.
- **Java:** `ui/MacroPanel.java`, `LuaWidget.java`, `UiApi.java`, `Sheet.java`, `Controls.java`,
  `AddonManager.java`, `LuaBinding.java`, `Macro.java`, `Macros.java`, `ClientDb.java`,
  `CharApi.java`, `AddonWidget.java`, `LuaGOut.java`, `LuaSlot.java`, `BeltHold.java`,
  `WidgetSubs.java`, `HookApi.java`, `AddonPagina.java`.
- **Docs:** `docs/addons/macros.md`, `api/actionbar.md`, `api/ui/custom.md`, `api/ui/drawing.md`,
  `api/ui/edit.md`, `api/ui/widget.md`, `api/ui/selectors.md`, `api/types/ui.md`,
  `api/client/keybindings.md`.
- **`docs/client/widget-input.md`**, one row: `UI.keydown` sends `GlobKeyEvent` only when the focused
  `KeyDownEvent` went unconsumed, and `Client` feeds `KeyHeld` before both. The page is at 147 of its
  150 lines.
- **Suites:** `addons/175-macros-hidden-from-addons.{1,2,3}/`.

## Risks & gotchas

- **`Confirm` sits on `ui.root`.** An ancestor walk alone misses it.
- **Prune inside `collect`.** Filtering after the walk leaks `UiApi.one`'s count.
- **A fresh panel on every press of the Macros button** (`OptWnd`'s `PButton` lambda). The marker is
  per class, never per instance.
- **`binding:down()` stays true in any other text field**, as `keybindings.md` documents.
- **`current()` is per thread.** Input arrives on the UI thread, which is the only one a press opens
  on.
- **`BeltHold.hold`'s signature moves.** `rm -rf build/classes` before the compile check.
- **No suite opens the page or presses a button.** Each waits for a Done button while the maintainer
  acts.

## Discarded alternatives

- **Remove 174.4.** The maintainer needs the addon-drawn bar, and a token plus the press rule serves
  it without handing the addon a macro.
- **Put `console.run` on a macro's `slot:use()`.** A bar would need the widest key to press its own
  button, and names would still leak.
- **Exempt the console from hiding.** A second rule that buys nothing, since `luajava` reaches the
  page anyway.
- **`nil` from `hitTest` over the page.** The Options window would turn hollow under the pointer.
- **Filtering selector results after the walk.** The count would still say the page is open.
- **A per-addon token.** One shared bar would need a translation per addon, and the press rule, not
  the token, is what stops an unprompted run.
- **A press lasting N seconds,** the browser's transient window. A timer set inside it would run a
  macro later. The synchronous handler is exact.
- **A subscription on a client widget as a press.** `MouseDown` on `@MapView` would license a run on
  every map click.
- **Keeping the name in the error notice.** The System log is readable through `chat.system`, so
  every failing macro would announce its name to any addon. The terminal keeps it.
- **Keeping the editor's read and drive arms.** Unreachable code saying the body is readable is the
  copy that goes stale.
