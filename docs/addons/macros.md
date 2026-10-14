# Macros

**Macros**, on the game menu `Ctrl+O` opens, directly below **AddOns**, keeps your own snippets of Lua, runs them and puts them on the action bar, without writing an addon. A macro is a name, an icon and a body. The client keeps them for itself: one list for every account and character, in `savedata/client.sqlite`, and every macro survives a restart unchanged.

---

## The page

The list on the left holds every macro, its icon and its name, in the order they were made. The right-hand side edits the one selected: its icon, its name, the body in a code editor, a status line, and the buttons under them. **Back** returns to the game menu.

| Control | Effect |
|---|---|
| **New** | Adds a macro named `New macro` with the placeholder icon and an empty body, and selects it with its name highlighted, so typing replaces it. |
| **Save** | Stores the name and the body. An empty name is refused: the status line says the macro needs a name, and nothing is stored. |
| **Run** | Stores the name and the body as **Save** does, then [runs the body](#running-a-macro). An empty name is refused the same way, and nothing runs. |
| **Delete** | Asks `Delete macro "<name>"?` in a window of its own. **Yes** removes it, and the page moves to its neighbour in the list. **No** keeps it. |
| A row | Selects that macro. A click on empty space keeps the one selected. |
| The name | Any text. Two macros may share a name. Spaces at either end are dropped when it is stored. |
| The icon | The placeholder, a wrench, on every macro. Drag it to put the macro [on the action bar](#on-the-action-bar). |

### What is stored without Save

Picking another row, **New**, and the page leaving the screen (**Back**, the window closed, the menu opened again) store what the page holds first. There an empty name keeps the name already stored, the field reads it again, and the body is stored under it.

## The editor

| Key | Effect |
|---|---|
| Typing | Inserts at the caret, over the selection. A character your keyboard layout puts behind AltGr types too. |
| Enter | A new line. |
| Tab | Two spaces. |
| Backspace, Delete | The character before or after the caret, or the selection. At either end of a line, joins it to its neighbour. |
| Arrows | Move the caret. Ctrl+Left and Ctrl+Right move by word. |
| Home, End | The line's start or end. Ctrl+Home and Ctrl+End, the body's. |
| PgUp, PgDn | A screen of lines. |
| Shift with any move | Extends the selection. |
| Ctrl+A | Selects the whole body. |
| Ctrl+C, Ctrl+X, Ctrl+V | Copy, cut and paste through the system clipboard. A pasted tab becomes two spaces and a Windows line ending one newline. |
| Escape | Closes the window, as anywhere in the menu. |

| Mouse | Effect |
|---|---|
| A click | Places the caret. |
| A drag, or Shift and a click | Selects. |
| The wheel, the bar on the right | Scrolls. |

A body is at most 65,536 characters, newlines counted. Typing or pasting past that stops at the limit.

## Running a macro

**Run** runs the body exactly as a [`:lua`](runtime.md#the-console-commands) line runs: in the console's own Lua, with nothing between the two.

```lua
local session = hafen.session():current()
if session then
  print(session:user() .. " has " .. session:chat():count() .. " chat channels")
end
```

| Rule | Detail |
|---|---|
| The console's runtime | One Lua for `:lua` and every macro: a global one sets, the other reads. Not sandboxed: every protected verb answers. The instruction watchdog applies, a fresh budget for each run. |
| Statements, not an expression | The body is a chunk of statements. Its value is not shown: a body of `return 5` prints nothing, where `:lua 5` answers `lua= 5`. |
| `print` | Answers in the System channel, one line per `print`, and in full on the terminal, as in `:lua`. |
| An error | Stops the run. The notice and its System log line read `macro:<line>: <message>`, the line counted in the body. The macro's name stays out of both, since an addon reads the System log. The terminal's line names it. |
| `:reload` | Takes back what a macro put up (windows, overlays, hotkeys, timers, subscriptions), as it does for `:lua`: they are the console's. |
| When it runs | A press of **Run** holds the character's widget tree, so the body runs at the client's next step, where none is held: a body may build a window or reach any character's widgets with no [`hafen.timer():after(0, fn)`](api/timer.md). |
| The terminal | Each run writes `[console] macro <name>` before the body runs. |

## On the action bar

Drag a macro's icon off the page onto a slot of the action bar. The slot holds the macro: it draws the macro's icon, the server is told nothing, and what the server has in that slot comes back untouched when the macro leaves it.

| Rule | Detail |
|---|---|
| Dragging | Press the icon, move, and release over a slot. At the login screen there is no bar, and nothing drags. |
| A bar an addon draws | An addon that draws the action bar in place of the client's takes the drag too: dropped on one of its buttons, the macro holds that slot by these same rules, and the addon draws it and takes it off. |
| Pressing | The slot's key with the pointer over the map, or a click on the slot, runs the body as last stored, as **Run** does. |
| A right-click | Takes the macro off the slot. The server's content comes back, and the slot is the server's again. |
| Remembered | Per character, as a slot of the bar is: the macro is back in its slot at the next world entry and after a `:reload`. |
| Renaming, editing | Every slot the macro stands in keeps it, and shows the new name. |
| **Delete** | Takes the macro off every slot it stands in, on every character. |
| The server writes the slot | Putting one of the game's actions there ends the macro's hold: what the server wrote stands. |

## What an addon sees

The page does not exist for addons. A macro runs unsandboxed, so what the page shows and what you type into it reach no addon, and no `:lua` line either. The rule covers the page, every widget in it, and its **Delete** question.

| Door | Over the page |
|---|---|
| [Selectors](api/ui/selectors.md) | Match nothing in it. `@MacroPanel`, `@MacroRow` and `@CodeArea` answer no widget while it is open, and a count of matches never includes it. |
| [`widget:children()`, `widget:walk(fn)`](api/ui/widget.md#read-methods) | The Options window's leave it out. |
| [`hafen.ui():hit(x, y)`](api/ui/selectors.md#hit-testing), [`hafen.ui():mouse():over()`](api/ui/mouse.md) | Answer the Options window over the page, and the root widget over the **Delete** question: the nearest widget outside it. |
| [`hafen.ui():tipAt(x, y)`](api/ui/widget.md#tooltips-and-focus) | `nil`. |
| Events | Its opening and closing fire nothing: no selector's `Added` or `Removed`, no widget's event. |
| [Stylesheets](api/ui/style/README.md) | Reach none of it. The page is drawn in the stock look, as [the AddOns page](panel.md) is. |
| [Hotkeys](api/client/keybindings.md) | While the keyboard focus is in the page or its question, no addon hotkey fires and every `binding:down()` reads `false`. A key the page does not take still reaches the client's own bindings. |

On the bar, a slot holding a macro reads the macro's token, `macro/` and 32 hex characters, and no name ([a macro on a slot](api/actionbar.md#a-macro-on-a-slot)). `slot:use()` runs it, and a widget's [`Drop`](api/ui/custom.md#drop-makes-a-widget-a-drop-target) reads a macro dragged onto it as that same token. The token is random and stable for the macro's life. It names that one macro, and tells an addon neither its name, its body, nor which other macros exist. A bar the addon draws puts that macro on its slot with [`slot:hold(res)`](api/actionbar.md#placing-one-from-a-drop) and draws its icon with [`g:resource(res, ...)`](api/ui/drawing.md#images).

There is no `hafen.macros()`: a macro is yours, written on this page and nowhere else.

---

## See Also

- [The AddOns manager](panel.md) — the page above it on the game menu.
- [The console commands](runtime.md#the-console-commands) — `:lua`, the runtime a macro runs in.
- [Selectors](api/ui/selectors.md) — reaching a widget of the client's tree, the page excepted.
- [Keybindings](api/client/keybindings.md) — the hotkeys the page holds back.
- [`session:actionbar`](api/actionbar.md#a-macro-on-a-slot) — a macro's slot, as an addon reads it.
