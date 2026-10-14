# Macros

**Macros**, on the game menu `Ctrl+O` opens, directly below **AddOns**, keeps your own snippets of Lua and runs them, without writing an addon. A macro is a name, an icon and a body. The client keeps them for itself: one list for every account and character, in `savedata/client.sqlite`, and every macro survives a restart unchanged.

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
| The icon | The placeholder, a wrench, on every macro. |

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
| An error | Stops the run. The notice and its System log line read `macro:<name>:<line>: <message>`, the line counted in the body. |
| `:reload` | Takes back what a macro put up (windows, overlays, hotkeys, timers, subscriptions), as it does for `:lua`: they are the console's. |
| When it runs | A press of **Run** holds the character's widget tree, so the body runs at the client's next step, where none is held: a body may build a window or reach any character's widgets with no [`hafen.timer():after(0, fn)`](api/timer.md). |
| The terminal | Each run writes `[console] macro <name>` before the body runs. |

## What an addon sees

The page stands in the client's tree, and a [selector](api/ui/selectors.md) reaches it as any other widget: `@MacroPanel` is the page, `@MacroRow` one row of the list, whose `label` reads the macro's name, and `@CodeArea` the editor. [`widget:text()`](api/ui/widget.md) and [`widget:value()`](api/ui/edit.md#reading-what-a-borrowed-control-holds) on the editor read the body, its lines joined by `\n`. [`widget:value(body)`](api/ui/edit.md#driving-one-protected), under `widget.value`, replaces it; the page stores it as it stores typing.

There is no `hafen.macros()`: a macro is yours, written on this page and nowhere else.

---

## See Also

- [The AddOns manager](panel.md) — the page above it on the game menu.
- [The console commands](runtime.md#the-console-commands) — `:lua`, the runtime a macro runs in.
- [Selectors](api/ui/selectors.md) — reaching a widget of the client's tree.
- [Widget](api/ui/widget.md) — `widget:text()` and the other reads.
